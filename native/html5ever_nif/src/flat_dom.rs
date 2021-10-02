use html5ever::{ QualName, Attribute };
use html5ever::tree_builder::{ TreeSink, QuirksMode, NodeOrText, ElementFlags };
use markup5ever::ExpandedName;

use tendril::StrTendril;

use std::borrow::Cow;

use rustler::{ Env, Encoder, Term };

use crate::common::{ STW, QNW };

#[derive(Copy, Clone, PartialEq, Debug)]
pub struct NodeHandle(pub usize);

#[derive(Debug)]
pub struct Node {
    id: NodeHandle,
    children: Vec<NodeHandle>,
    parent: Option<NodeHandle>,
    data: NodeData,
}
impl Node {
    fn new(id: usize, data: NodeData) -> Self {
        Node {
            id: NodeHandle(id),
            parent: None,
            children: Vec::with_capacity(10),
            data: data,
        }
    }
}

#[derive(Debug, PartialEq)]
pub enum NodeData{
    Document,
    DocType {
        name: StrTendril,
        public_id: StrTendril,
        system_id: StrTendril,
    },
    Text {
        contents: StrTendril,
    },
    Comment {
        contents: StrTendril,
    },
    Element {
        name: QualName,
        attrs: Vec<Attribute>,
        template_contents: Option<NodeHandle>,
        mathml_annotation_xml_integration_point: bool,
    },
    ProcessingInstruction {
        target: StrTendril,
        contents: StrTendril,
    },
}

#[derive(Debug)]
pub struct FlatSink {
    pub root: NodeHandle,
    pub nodes: Vec<Node>,
}

impl FlatSink {

    pub fn new() -> FlatSink {
        let mut sink = FlatSink {
            root: NodeHandle(0),
            nodes: Vec::with_capacity(200),
        };

        // Element 0 is always root
        sink.nodes.push(Node::new(0, NodeData::Document));

        sink
    }

    pub fn root(&self) -> NodeHandle {
        self.root
    }

    pub fn node_mut<'a>(&'a mut self, handle: NodeHandle) -> &'a mut Node {
        &mut self.nodes[handle.0]
    }
    pub fn node<'a>(&'a self, handle: NodeHandle) -> &'a Node {
        &self.nodes[handle.0]
    }

    pub fn make_node(&mut self, data: NodeData) -> NodeHandle {
        let node = Node::new(self.nodes.len(), data);
        let id = node.id;
        self.nodes.push(node);
        id
    }

}

fn node_or_text_to_node(sink: &mut FlatSink, not: NodeOrText<NodeHandle>) -> NodeHandle {
    match not {
        NodeOrText::AppendNode(handle) => handle,
        NodeOrText::AppendText(text) => {
            sink.make_node(NodeData::Text {
                contents: text,
            })
        },
    }
}

impl TreeSink for FlatSink {
    type Output = Self;
    type Handle = NodeHandle;

    fn finish(self) -> Self::Output {
        self
    }

    // TODO: Log this or something
    fn parse_error(&mut self, _msg: Cow<'static, str>) {}
    fn set_quirks_mode(&mut self, _mode: QuirksMode) {}

    fn get_document(&mut self) -> Self::Handle { NodeHandle(0) }
    fn get_template_contents(&mut self, _target: &Self::Handle) -> Self::Handle {
        panic!("Templates not supported");
    }

    fn same_node(&self, x: &Self::Handle, y: &Self::Handle) -> bool { x == y }
    fn elem_name(&self, target: &Self::Handle) -> ExpandedName {
        let node = self.node(*target);
        match node.data {
            NodeData::Element { ref name, .. } => name.expanded(),
            _ => unreachable!(),
        }
    }

    fn create_element(&mut self, name: QualName, attrs: Vec<Attribute>, flags: ElementFlags) -> Self::Handle {
        let template_contents = if flags.template {
            Some(self.make_node(NodeData::Document))
        } else {
            None
        };

        self.make_node(NodeData::Element {
            name: name,
            attrs: attrs,
            mathml_annotation_xml_integration_point: flags.mathml_annotation_xml_integration_point,
            template_contents: template_contents,
        })
    }

    fn create_comment(&mut self, text: StrTendril) -> Self::Handle {
        self.make_node(NodeData::Comment {
            contents: text,
        })
    }

    fn append(&mut self, parent_id: &Self::Handle, child: NodeOrText<Self::Handle>) {
        let handle = node_or_text_to_node(self, child);

        self.node_mut(*parent_id).children.push(handle);
        self.node_mut(handle).parent = Some(*parent_id);
    }

    fn append_based_on_parent_node(&mut self,
                                   element: &Self::Handle,
                                   prev_element: &Self::Handle,
                                   child: NodeOrText<Self::Handle>) {
        let has_parent = self.node(*element).parent.is_some();
        if has_parent {
            self.append_before_sibling(element, child);
        } else {
            self.append(prev_element, child);
        }
    }

    fn append_before_sibling(&mut self, sibling: &Self::Handle, new_node: NodeOrText<Self::Handle>) {
        let new_node_handle = node_or_text_to_node(self, new_node);

        let parent = self.node(*sibling).parent.unwrap();
        let parent_node = self.node_mut(parent);
        let sibling_index = parent_node.children.iter().enumerate()
            .find(|&(_, node)| node == sibling).unwrap().0;
        parent_node.children.insert(sibling_index, new_node_handle);
    }

    fn append_doctype_to_document(&mut self, name: StrTendril, public_id: StrTendril, system_id: StrTendril) {
        let doctype = self.make_node(NodeData::DocType {
            name: name,
            public_id: public_id,
            system_id: system_id,
        });
        let root = self.root;
        self.node_mut(root).children.push(doctype);
        self.node_mut(doctype).parent = Some(self.root);
    }

    fn add_attrs_if_missing(&mut self, target_handle: &Self::Handle, mut add_attrs: Vec<Attribute>) {
        let target = self.node_mut(*target_handle);
        match target.data {
            NodeData::Element { ref mut attrs, .. } => {
                for attr in add_attrs.drain(..) {
                    if attrs.iter().find(|a| attr.name == a.name) == None {
                        attrs.push(attr);
                    }
                }
            }
            _ => unreachable!(),
        }
    }

    fn remove_from_parent(&mut self, target: &Self::Handle) {
        let parent = self.node(*target).parent.unwrap();
        let parent_node = self.node_mut(parent);
        let sibling_index = parent_node.children.iter().enumerate()
            .find(|&(_, node)| node == target).unwrap().0;
        parent_node.children.remove(sibling_index);
    }

    fn reparent_children(&mut self, node: &Self::Handle, new_parent: &Self::Handle) {
        let mut old_children = self.node(*node).children.clone();
        for child in &old_children {
            self.node_mut(*child).parent = Some(*new_parent);
        }
        let new_node = self.node_mut(*new_parent);
        new_node.children.append(&mut old_children);
    }

    fn mark_script_already_started(&mut self, _elem: &Self::Handle) {
        panic!("unsupported");
    }

    //fn has_parent_node(&self, handle: &Self::Handle) -> bool {
    //    self.node(*handle).parent.is_some()
    //}

    fn create_pi(&mut self, target: StrTendril, data: StrTendril) -> Self::Handle {
        self.make_node(NodeData::ProcessingInstruction {
            target: target,
            contents: data,
        })
    }

}

impl Encoder for NodeHandle {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        self.0.encode(env)
    }
}

impl Encoder for Node {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let map = ::rustler::types::map::map_new(env)
            .map_put(self::atoms::id().encode(env), self.id.encode(env)).ok().unwrap()
            .map_put(self::atoms::parent().encode(env), match self.parent {
                Some(handle) => handle.encode(env),
                None => self::atoms::nil().encode(env),
            }).ok().unwrap();

        match self.data {
            NodeData::Document => {
                map
                    .map_put(self::atoms::type_().encode(env), self::atoms::document().encode(env)).ok().unwrap()
            }
            NodeData::Element { ref attrs, ref name, .. } => {
                map
                    .map_put(self::atoms::type_().encode(env), self::atoms::element().encode(env)).ok().unwrap()
                    .map_put(self::atoms::children().encode(env), self.children.encode(env)).ok().unwrap()
                    .map_put(self::atoms::name().encode(env), QNW(name).encode(env)).ok().unwrap()
                    .map_put(self::atoms::attrs().encode(env), attrs.iter().map(|attr| {
                        (QNW(&attr.name), STW(&attr.value))
                    }).collect::<Vec<_>>().encode(env)).ok().unwrap()
            }
            NodeData::Text { ref contents } => {
                map
                    .map_put(self::atoms::type_().encode(env), self::atoms::text().encode(env)).ok().unwrap()
                    .map_put(self::atoms::contents().encode(env), STW(contents).encode(env)).ok().unwrap()
            }
            NodeData::DocType { .. } => {
                map
                    .map_put(self::atoms::type_().encode(env), self::atoms::doctype().encode(env)).ok().unwrap()
            }
            NodeData::Comment { ref contents } => {
                map
                    .map_put(self::atoms::type_().encode(env), self::atoms::comment().encode(env)).ok().unwrap()
                    .map_put(self::atoms::contents().encode(env), STW(contents).encode(env)).ok().unwrap()
            }
            _ => unimplemented!(),
        }
    }
}

mod atoms {
    rustler::atoms! {
        nil,

        type_ = "type",
        document,
        element,
        text,
        doctype,
        comment,

        name,
        nodes,
        root,
        id,
        parent,
        children,
        contents,
        attrs,
    }
}

pub fn flat_sink_to_flat_term<'a>(env: Env<'a>, sink: &FlatSink) -> Term<'a> {
    let nodes = sink.nodes.iter()
        .fold(rustler::types::map::map_new(env), |acc, node| {
            acc.map_put(node.id.encode(env), node.encode(env)).ok().unwrap()
        });

    ::rustler::types::map::map_new(env)
        .map_put(self::atoms::nodes().encode(env), nodes).ok().unwrap()
        .map_put(self::atoms::root().encode(env), sink.root.encode(env)).ok().unwrap()
}

struct RecState<'a> {
    node: NodeHandle,
    child_n: usize,

    children: Vec<Term<'a>>,
}

pub fn flat_sink_to_rec_term<'a>(env: Env<'a>, sink: &FlatSink) -> Term<'a> {
    let mut stack: Vec<RecState> = vec![
        RecState {
            node: sink.root(),
            child_n: 0,
            children: Vec::new(),
        },
    ];

    loop {
        let mut top = stack.pop().unwrap();
        let top_node = &sink.nodes[top.node.0];

        if let Some(child_node) = top_node.children.get(top.child_n) {
            // If we find another child, we recurse downwards

            let child = RecState {
                node: *child_node,
                child_n: 0,
                children: Vec::new(),
            };
            debug_assert!(sink.nodes[child_node.0].data != NodeData::Document);

            top.child_n += 1;
            stack.push(top);
            stack.push(child);
            continue;
        } else {
            // If there are no more children, we add the child to the parent
            // (or we return if we are the root)

            let term;

            match &top_node.data {
                NodeData::Document => {
                    let term = top.children.encode(env);
                    assert_eq!(stack.len(), 0);
                    return term;
                },
                NodeData::DocType { name, public_id, system_id }  => {
                    assert!(stack.len() > 0);
                    assert!(top.children.len() == 0);

                    term = (
                        self::atoms::doctype(),
                        STW(name),
                        STW(public_id),
                        STW(system_id),
                    ).encode(env);
                },
                NodeData::Element { attrs, name, .. } => {
                    assert!(stack.len() > 0);

                    let attribute_terms: Vec<Term<'a>> = attrs.iter()
                        .map(|a| (QNW(&a.name), STW(&a.value)).encode(env))
                        .collect();
                    term = (QNW(name), attribute_terms, top.children).encode(env);
                },
                NodeData::Text { contents } => {
                    term = STW(contents).encode(env);
                },
                NodeData::Comment { .. } => continue,
                _ => unimplemented!("{:?}", top_node),
            }

            stack.last_mut().unwrap().children.push(term);
        }
    }
}









