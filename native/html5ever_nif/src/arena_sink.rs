// This file was originally copied from the html5ever project.
// See the original file in https://github.com/servo/html5ever/blob/ce64836c685025a5fef0860fa2e9c80b2683e8d0/html5ever/examples/arena.rs
//
// The modifications are under the same licenses, under the same
// conditions. Copyright 2026 The html5ever_elixir project developers.
//
// The following notice is from the original project.
//
// Copyright 2014-2017 The html5ever Project Developers. See the
// COPYRIGHT file at the top-level directory of this distribution.
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.

extern crate html5ever;
extern crate rustler;
extern crate typed_arena;

use html5ever::interface::tree_builder::{ElementFlags, NodeOrText, QuirksMode, TreeSink};
use html5ever::tendril::{StrTendril, TendrilSink};
use html5ever::{Attribute, QualName, parse_document};

use rustler::{Encoder, Env, Term};
use std::borrow::Cow;
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::ptr;

use crate::common::{QualNameWrapper, StrTendrilWrapper, atoms};

/// By using our ArenaSink type, the arena is filled with parsed HTML.
pub(crate) fn html5ever_parse_slice_into_arena<'a>(bytes: &[u8], arena: Arena<'a>) -> Ref<'a> {
    let root_id: usize = 0;
    let sink = ArenaSink {
        arena,
        id: Cell::new(root_id),
        document: arena.alloc(Node::new(NodeData::Document, root_id)),
        quirks_mode: Cell::new(QuirksMode::NoQuirks),
    };

    parse_document(sink, Default::default())
        .from_utf8()
        .one(bytes)
}

pub(crate) type Arena<'arena> = &'arena typed_arena::Arena<Node<'arena>>;
pub(crate) type Ref<'arena> = &'arena Node<'arena>;
pub(crate) type Link<'arena> = Cell<Option<Ref<'arena>>>;

/// ArenaSink struct is responsible for handling how the data that comes out of the HTML parsing
/// unit (TreeBuilder in our case) is handled.
pub(crate) struct ArenaSink<'arena> {
    arena: Arena<'arena>,
    document: Ref<'arena>,
    id: Cell<usize>,
    quirks_mode: Cell<QuirksMode>,
}

/// DOM node which contains links to other nodes in the tree.
pub(crate) struct Node<'arena> {
    id: usize,
    parent: Link<'arena>,
    next_sibling: Link<'arena>,
    previous_sibling: Link<'arena>,
    first_child: Link<'arena>,
    last_child: Link<'arena>,
    data: NodeData<'arena>,
}

/// HTML node data which can be an element, a comment, a string, a DOCTYPE, etc...
#[derive(Clone)]
pub enum NodeData<'arena> {
    Document,
    Doctype {
        name: StrTendril,
        public_id: StrTendril,
        system_id: StrTendril,
    },
    Text {
        contents: RefCell<StrTendril>,
    },
    Comment {
        contents: StrTendril,
    },
    Element {
        name: QualName,
        attrs: RefCell<Vec<Attribute>>,
        template_contents: Option<Ref<'arena>>,
        mathml_annotation_xml_integration_point: bool,
    },
    ProcessingInstruction {
        target: StrTendril,
        contents: StrTendril,
    },
}

impl<'arena> Node<'arena> {
    fn new(data: NodeData<'arena>, id: usize) -> Self {
        Node {
            parent: Cell::new(None),
            previous_sibling: Cell::new(None),
            next_sibling: Cell::new(None),
            first_child: Cell::new(None),
            last_child: Cell::new(None),
            id,
            data,
        }
    }

    fn detach(&self) {
        let parent = self.parent.take();
        let previous_sibling = self.previous_sibling.take();
        let next_sibling = self.next_sibling.take();

        if let Some(next_sibling) = next_sibling {
            next_sibling.previous_sibling.set(previous_sibling);
        } else if let Some(parent) = parent {
            parent.last_child.set(previous_sibling);
        }

        if let Some(previous_sibling) = previous_sibling {
            previous_sibling.next_sibling.set(next_sibling);
        } else if let Some(parent) = parent {
            parent.first_child.set(next_sibling);
        }
    }

    fn append(&'arena self, new_child: &'arena Self) {
        new_child.detach();
        new_child.parent.set(Some(self));
        if let Some(last_child) = self.last_child.take() {
            new_child.previous_sibling.set(Some(last_child));
            debug_assert!(last_child.next_sibling.get().is_none());
            last_child.next_sibling.set(Some(new_child));
        } else {
            debug_assert!(self.first_child.get().is_none());
            self.first_child.set(Some(new_child));
        }
        self.last_child.set(Some(new_child));
    }

    fn insert_before(&'arena self, new_sibling: &'arena Self) {
        new_sibling.detach();
        new_sibling.parent.set(self.parent.get());
        new_sibling.next_sibling.set(Some(self));
        if let Some(previous_sibling) = self.previous_sibling.take() {
            new_sibling.previous_sibling.set(Some(previous_sibling));
            debug_assert!(ptr::eq::<Node>(
                previous_sibling.next_sibling.get().unwrap(),
                self
            ));
            previous_sibling.next_sibling.set(Some(new_sibling));
        } else if let Some(parent) = self.parent.get() {
            debug_assert!(ptr::eq::<Node>(parent.first_child.get().unwrap(), self));
            parent.first_child.set(Some(new_sibling));
        }
        self.previous_sibling.set(Some(new_sibling));
    }
}

impl<'arena> ArenaSink<'arena> {
    fn new_node(&self, data: NodeData<'arena>) -> Ref<'arena> {
        let current_id = self.id.get();
        let next_id = current_id + 1;
        self.id.set(next_id);
        self.arena.alloc(Node::new(data, next_id))
    }

    fn append_common<P, A>(&self, child: NodeOrText<Ref<'arena>>, previous: P, append: A)
    where
        P: FnOnce() -> Option<Ref<'arena>>,
        A: FnOnce(Ref<'arena>),
    {
        let new_node = match child {
            NodeOrText::AppendText(text) => {
                // Append to an existing Text node if we have one.
                if let Some(&Node {
                    data: NodeData::Text { ref contents },
                    ..
                }) = previous()
                {
                    contents.borrow_mut().push_tendril(&text);
                    return;
                }
                self.new_node(NodeData::Text {
                    contents: RefCell::new(text),
                })
            }
            NodeOrText::AppendNode(node) => node,
        };

        append(new_node)
    }
}

/// By implementing the TreeSink trait we determine how the data from the tree building step
/// is processed. In our case, our data is allocated in the arena and added to the Node data
/// structure.
///
/// For deeper understating of each function go to the TreeSink declaration.
impl<'arena> TreeSink for ArenaSink<'arena> {
    type Handle = Ref<'arena>;
    type Output = Ref<'arena>;
    type ElemName<'a>
        = &'a QualName
    where
        Self: 'a;

    fn finish(self) -> Ref<'arena> {
        self.document
    }

    fn parse_error(&self, _: Cow<'static, str>) {}

    fn get_document(&self) -> Ref<'arena> {
        self.document
    }

    fn set_quirks_mode(&self, mode: QuirksMode) {
        self.quirks_mode.set(mode);
    }

    fn same_node(&self, x: &Ref<'arena>, y: &Ref<'arena>) -> bool {
        ptr::eq::<Node>(*x, *y)
    }

    fn elem_name(&self, target: &Ref<'arena>) -> Self::ElemName<'_> {
        match target.data {
            NodeData::Element { ref name, .. } => name,
            _ => panic!("not an element!"),
        }
    }

    fn get_template_contents(&self, target: &Ref<'arena>) -> Ref<'arena> {
        if let NodeData::Element {
            template_contents: Some(contents),
            ..
        } = target.data
        {
            contents
        } else {
            panic!("not a template element!")
        }
    }

    fn is_mathml_annotation_xml_integration_point(&self, target: &Ref<'arena>) -> bool {
        if let NodeData::Element {
            mathml_annotation_xml_integration_point,
            ..
        } = target.data
        {
            mathml_annotation_xml_integration_point
        } else {
            panic!("not an element!")
        }
    }

    fn create_element(
        &self,
        name: QualName,
        attrs: Vec<Attribute>,
        flags: ElementFlags,
    ) -> Ref<'arena> {
        self.new_node(NodeData::Element {
            name,
            attrs: RefCell::new(attrs),
            template_contents: if flags.template {
                Some(self.new_node(NodeData::Document))
            } else {
                None
            },
            mathml_annotation_xml_integration_point: flags.mathml_annotation_xml_integration_point,
        })
    }

    fn create_comment(&self, text: StrTendril) -> Ref<'arena> {
        self.new_node(NodeData::Comment { contents: text })
    }

    fn create_pi(&self, target: StrTendril, data: StrTendril) -> Ref<'arena> {
        self.new_node(NodeData::ProcessingInstruction {
            target,
            contents: data,
        })
    }

    fn append(&self, parent: &Ref<'arena>, child: NodeOrText<Ref<'arena>>) {
        self.append_common(
            child,
            || parent.last_child.get(),
            |new_node| parent.append(new_node),
        )
    }

    fn append_before_sibling(&self, sibling: &Ref<'arena>, child: NodeOrText<Ref<'arena>>) {
        self.append_common(
            child,
            || sibling.previous_sibling.get(),
            |new_node| sibling.insert_before(new_node),
        )
    }

    fn append_based_on_parent_node(
        &self,
        element: &Ref<'arena>,
        prev_element: &Ref<'arena>,
        child: NodeOrText<Ref<'arena>>,
    ) {
        if element.parent.get().is_some() {
            self.append_before_sibling(element, child)
        } else {
            self.append(prev_element, child)
        }
    }

    fn append_doctype_to_document(
        &self,
        name: StrTendril,
        public_id: StrTendril,
        system_id: StrTendril,
    ) {
        self.document.append(self.new_node(NodeData::Doctype {
            name,
            public_id,
            system_id,
        }))
    }

    fn add_attrs_if_missing(&self, target: &Ref<'arena>, attrs: Vec<Attribute>) {
        let mut existing = if let NodeData::Element { ref attrs, .. } = target.data {
            attrs.borrow_mut()
        } else {
            panic!("not an element")
        };

        let existing_names = existing
            .iter()
            .map(|e| e.name.clone())
            .collect::<HashSet<_>>();
        existing.extend(
            attrs
                .into_iter()
                .filter(|attr| !existing_names.contains(&attr.name)),
        );
    }

    fn remove_from_parent(&self, target: &Ref<'arena>) {
        target.detach()
    }

    fn reparent_children(&self, node: &Ref<'arena>, new_parent: &Ref<'arena>) {
        let mut next_child = node.first_child.get();
        while let Some(child) = next_child {
            debug_assert!(ptr::eq::<Node>(child.parent.get().unwrap(), *node));
            next_child = child.next_sibling.get();
            new_parent.append(child)
        }
    }
}

pub(crate) fn nodes_to_term<'arena, 'env>(
    env: Env<'env>,
    node: &Node<'arena>,
    attrs_as_maps: bool,
) -> Term<'env> {
    match &node.data {
        NodeData::Document => {
            let mut terms: Vec<Term> = Vec::new();
            let mut child = node.first_child.get();
            while let Some(current_child) = child {
                let encoded_child = nodes_to_term(env, current_child, attrs_as_maps);
                terms.push(encoded_child);
                child = current_child.next_sibling.get();
            }

            terms.encode(env)
        }
        NodeData::Doctype {
            name,
            public_id,
            system_id,
        } => (
            atoms::doctype(),
            StrTendrilWrapper(name),
            StrTendrilWrapper(public_id),
            StrTendrilWrapper(system_id),
        )
            .encode(env),
        NodeData::Text { contents } => {
            let text = contents.borrow();
            StrTendrilWrapper(&text).encode(env)
        }
        NodeData::Comment { contents } => {
            (atoms::comment(), StrTendrilWrapper(contents)).encode(env)
        }
        NodeData::Element { name, attrs, .. } => {
            let mut terms: Vec<Term> = Vec::new();

            let mut child = node.first_child.get();
            while let Some(current_child) = child {
                let encoded_child = nodes_to_term(env, current_child, attrs_as_maps);
                terms.push(encoded_child);
                child = current_child.next_sibling.get();
            }

            (
                &name.local.to_string(),
                attributes_to_term(env, attrs, attrs_as_maps),
                terms,
            )
                .encode(env)
        }
        NodeData::ProcessingInstruction { target, contents } => (
            atoms::process_instruction(),
            StrTendrilWrapper(target),
            StrTendrilWrapper(contents),
        )
            .encode(env),
    }
}

fn attributes_to_term<'a>(
    env: Env<'a>,
    attributes: &RefCell<Vec<Attribute>>,
    as_maps: bool,
) -> Term<'a> {
    let attrs = attributes.borrow();
    let pairs: Vec<(QualNameWrapper, StrTendrilWrapper)> = attrs
        .iter()
        .map(|a| (QualNameWrapper(&a.name), StrTendrilWrapper(&a.value)))
        .collect();

    if as_maps {
        Term::map_from_pairs(env, &pairs).unwrap()
    } else {
        pairs.encode(env)
    }
}

fn rustler_error_to_map_entry_error(_err: rustler::error::Error) -> crate::Html5everExError {
    crate::Html5everExError::MapEntry
}

fn get_children<'a>(node: &Node<'a>) -> Vec<Ref<'a>> {
    let mut children: Vec<&Node> = Vec::new();
    let mut child = node.first_child.get();
    while let Some(current_child) = child {
        children.push(current_child);
        child = current_child.next_sibling.get();
    }

    children
}

pub(crate) fn nodes_to_flat_term<'env>(
    env: Env<'env>,
    root_node: &Node,
    attrs_as_maps: bool,
) -> Result<Term<'env>, crate::Html5everExError> {
    let mut main_map = ::rustler::types::map::map_new(env);
    let mut nodes_map = ::rustler::types::map::map_new(env);

    let atom_attrs = atoms::attrs().encode(env);
    let atom_children = atoms::children().encode(env);
    let atom_contents = atoms::contents().encode(env);
    let atom_element = atoms::element().encode(env);
    let atom_id = atoms::id().encode(env);
    let atom_name = atoms::name().encode(env);
    let atom_parent = atoms::parent().encode(env);
    let atom_text = atoms::text().encode(env);
    let atom_type = atoms::type_().encode(env);

    let mut nodes: Vec<&Node> = Vec::with_capacity(1000);
    nodes.push(root_node);

    while let Some(node) = nodes.pop() {
        let node_id_encoded = node.id.encode(env);
        match &node.data {
            NodeData::Document => {
                let mut children = get_children(node);
                let children_ids: Vec<usize> = children.iter().map(|c| c.id).collect();
                let pairs: Vec<(Term, Term)> = vec![
                    (atom_children, children_ids.encode(env)),
                    (atom_id, node_id_encoded),
                    (atom_parent, node.parent.get().map(|n| n.id).encode(env)),
                    (atom_type, atoms::document().encode(env)),
                ];
                let document_map =
                    Term::map_from_pairs(env, &pairs).map_err(rustler_error_to_map_entry_error)?;

                nodes_map = nodes_map
                    .map_put(node_id_encoded, document_map)
                    .map_err(rustler_error_to_map_entry_error)?;

                main_map = main_map
                    .map_put(atoms::root(), node_id_encoded)
                    .map_err(rustler_error_to_map_entry_error)?;

                for child in children.iter_mut() {
                    nodes.push(child)
                }

                main_map
            }
            NodeData::Doctype { name, .. } => {
                let pairs: Vec<(Term, Term)> = vec![
                    (atom_id, node_id_encoded),
                    (atom_parent, node.parent.get().map(|n| n.id).encode(env)),
                    (atom_type, atoms::doctype().encode(env)),
                    (atom_name, StrTendrilWrapper(name).encode(env)),
                ];
                let doctype_map =
                    Term::map_from_pairs(env, &pairs).map_err(rustler_error_to_map_entry_error)?;

                nodes_map = nodes_map
                    .map_put(node_id_encoded, doctype_map)
                    .map_err(rustler_error_to_map_entry_error)?;

                nodes_map
            }
            NodeData::Text { contents } => {
                let text = contents.borrow();

                let pairs: Vec<(Term, Term)> = vec![
                    (atom_id, node_id_encoded),
                    (atom_parent, node.parent.get().map(|n| n.id).encode(env)),
                    (atom_type, atom_text),
                    (atom_contents, StrTendrilWrapper(&text).encode(env)),
                ];
                let text_map =
                    Term::map_from_pairs(env, &pairs).map_err(rustler_error_to_map_entry_error)?;

                nodes_map = nodes_map
                    .map_put(node_id_encoded, text_map)
                    .map_err(rustler_error_to_map_entry_error)?;

                nodes_map
            }
            NodeData::Comment { contents } => {
                let pairs: Vec<(Term, Term)> = vec![
                    (atom_id, node_id_encoded),
                    (atom_parent, node.parent.get().map(|n| n.id).encode(env)),
                    (atom_type, atoms::comment().encode(env)),
                    (atom_contents, StrTendrilWrapper(contents).encode(env)),
                ];
                let comment_map =
                    Term::map_from_pairs(env, &pairs).map_err(rustler_error_to_map_entry_error)?;

                nodes_map = nodes_map
                    .map_put(node_id_encoded, comment_map)
                    .map_err(rustler_error_to_map_entry_error)?;

                nodes_map
            }
            NodeData::Element { name, attrs, .. } => {
                let mut children = get_children(node);
                let children_ids: Vec<usize> = children.iter().map(|c| c.id).collect();
                let pairs: Vec<(Term, Term)> = vec![
                    (atom_attrs, attributes_to_term(env, attrs, attrs_as_maps)),
                    (atom_children, children_ids.encode(env)),
                    (atom_id, node_id_encoded),
                    (atom_name, name.local.encode(env)),
                    (atom_parent, node.parent.get().map(|n| n.id).encode(env)),
                    (atom_type, atom_element),
                ];
                let element_map =
                    Term::map_from_pairs(env, &pairs).map_err(rustler_error_to_map_entry_error)?;

                nodes_map = nodes_map
                    .map_put(node_id_encoded, element_map)
                    .map_err(rustler_error_to_map_entry_error)?;

                for child in children.iter_mut() {
                    nodes.push(child)
                }

                nodes_map
            }
            NodeData::ProcessingInstruction { target, contents } => {
                let pairs: Vec<(Term, Term)> = vec![
                    (atom_id, node_id_encoded),
                    (atom_parent, node.parent.get().map(|n| n.id).encode(env)),
                    (atom_type, atoms::process_instruction().encode(env)),
                    (atom_name, StrTendrilWrapper(target).encode(env)),
                    (atom_contents, StrTendrilWrapper(contents).encode(env)),
                ];
                let process_instruction_map =
                    Term::map_from_pairs(env, &pairs).map_err(rustler_error_to_map_entry_error)?;

                nodes_map = nodes_map
                    .map_put(node_id_encoded, process_instruction_map)
                    .map_err(rustler_error_to_map_entry_error)?;

                nodes_map
            }
        };
    }

    main_map = main_map
        .map_put(atoms::nodes(), nodes_map)
        .map_err(rustler_error_to_map_entry_error)?;

    Ok(main_map)
}
