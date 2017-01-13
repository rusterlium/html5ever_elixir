use ::html5ever;
use html5ever::{ QualName, Attribute };
use html5ever::tree_builder::interface::{ TreeSink, QuirksMode, NodeOrText };

use tendril::{ StrTendril, TendrilSink };

use std::borrow::Cow;

#[derive(Copy, Clone, PartialEq, Debug)]
pub struct ElementHandle(usize);

#[derive(Debug)]
struct Element {
    id: usize,
    name: Option<QualName>,
    children: Vec<ElementHandle>,
    parent: Option<ElementHandle>,
    last_string: bool,
}
impl Element {
    fn new(id: usize) -> Self {
        Element {
            id: id,
            name: None,
            children: Vec::with_capacity(10),
            parent: None,
            last_string: false,
        }
    }

    fn handle(&self) -> ElementHandle {
        ElementHandle(self.id)
    }
}

#[derive(Debug)]
enum ElementType {
    Element(Element),
    Text(StrTendril),
}
impl ElementType {
    fn elem(&self) -> &Element {
        match self {
            &ElementType::Element(ref elem) => elem,
            &ElementType::Text(_) => unreachable!(),
        }
    }
    fn elem_mut(&mut self) -> &mut Element {
        match self {
            &mut ElementType::Element(ref mut elem) => elem,
            &mut ElementType::Text(_) => unreachable!(),
        }
    }
    fn text_mut(&mut self) -> &mut StrTendril {
        match self {
            &mut ElementType::Element(_) => unreachable!(),
            &mut ElementType::Text(ref mut st) => st,
        }
    }
}

#[derive(Debug)]
pub struct FlatSink {
    elements: Vec<ElementType>,
}

impl FlatSink {

    pub fn new() -> FlatSink {
        let mut sink = FlatSink {
            elements: Vec::with_capacity(200),
        };

        // Element 0 is always root
        sink.elements.push(ElementType::Element(Element::new(0)));

        sink
    }

    fn elem(&self, elem: ElementHandle) -> &ElementType {
        &self.elements[elem.0]
    }
    fn elem_mut(&mut self, elem: ElementHandle) -> &mut ElementType {
        &mut self.elements[elem.0]
    }

    fn new_elem(&mut self) -> &mut Element {
        let idx = self.elements.len();
        self.elements.push(ElementType::Element(Element::new(idx)));
        self.elements[idx].elem_mut()
    }
    fn new_text(&mut self, text: StrTendril) -> ElementHandle {
        let idx = self.elements.len();
        self.elements.push(ElementType::Text(text));
        ElementHandle(idx)
    }

    fn append_node(&mut self, parent: ElementHandle, child: ElementHandle) {
        self.elem_mut(child).elem_mut().parent = Some(parent);
        let elem = self.elem_mut(parent).elem_mut();
        elem.children.push(child);
        elem.last_string = false;
    }

    fn append_text(&mut self, parent: ElementHandle, child: StrTendril) {
        if self.elem(parent).elem().last_string {
            match self.elem(parent).elem().children.last() {
                Some(&handle) => self.elem_mut(handle).text_mut().push_tendril(&child),
                _ => unreachable!(),
            }
        } else {
            let st = self.new_text(child);
            let elem = self.elem_mut(parent).elem_mut();
            elem.children.push(st);
            elem.last_string = true;
        }
    }

}

impl TreeSink for FlatSink {
    type Output = u32;
    type Handle = ElementHandle;

    fn finish(self) -> Self::Output {
        println!("{:?}", self);
        0
    }

    // TODO: Log this or something
    fn parse_error(&mut self, msg: Cow<'static, str>) {}
    fn set_quirks_mode(&mut self, mode: QuirksMode) {}

    fn get_document(&mut self) -> Self::Handle { ElementHandle(0) }
    fn get_template_contents(&mut self, target: Self::Handle) -> Self::Handle {
        panic!("Templates not supported");
    }

    fn same_node(&self, x: Self::Handle, y: Self::Handle) -> bool { x == y }
    fn elem_name(&self, target: Self::Handle) -> QualName {
        self.elem(target).elem().name.as_ref().map(|i| i.clone()).unwrap()
    }

    fn create_element(&mut self, name: QualName, attrs: Vec<Attribute>) -> Self::Handle {
        let elem = self.new_elem();
        elem.name = Some(name);
        elem.handle()
    }

    fn create_comment(&mut self, _text: StrTendril) -> Self::Handle {
        let elem = self.new_elem();
        elem.handle()
    }

    fn append(&mut self, parent: Self::Handle, child: NodeOrText<Self::Handle>) {
        match child {
            NodeOrText::AppendNode(node) => self.append_node(parent, node),
            NodeOrText::AppendText(text) => self.append_text(parent, text),
        };
    }

    fn append_before_sibling(&mut self, sibling: Self::Handle, new_node: NodeOrText<Self::Handle>) -> Result<(), NodeOrText<Self::Handle>> {
        panic!("unsupported");
    }

    fn append_doctype_to_document(&mut self, name: StrTendril, public_id: StrTendril, system_id: StrTendril) {
        println!("append_doctype_to_document");
    }

    fn add_attrs_if_missing(&mut self, target: Self::Handle, attrs: Vec<Attribute>) {
        panic!("unsupported");
    }

    fn remove_from_parent(&mut self, target: Self::Handle) {
        panic!("unsupported");
    }

    fn reparent_children(&mut self, node: Self::Handle, new_parent: Self::Handle) {
        panic!("unsupported");
    }

    fn mark_script_already_started(&mut self, elem: Self::Handle) {
        panic!("unsupported");
    }

}
