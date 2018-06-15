use ::rustler::{Env, Term, Encoder};
use ::html5ever::rcdom::{Handle, NodeData};
use ::html5ever::QualName;
use ::tendril::StrTendril;

use ::common::{ QNW, STW };

/// Takes a Handle from a RcDom, encodes it into a Term.
/// This follows the mochiweb encoding scheme with two exceptions:
/// * A `{:doctype, name, pubid, sysid}` node.
/// * Always returns a list as it's root node.
pub fn handle_to_term<'a>(env: Env<'a>, handle: &Handle) -> Option<Term<'a>> {
    let node = handle;

    // Closure so that we don't encode this when we don't need to return
    // it to the user.
    let children = || {
        // Encodes a Vec<Handle> to a Vec<Term>
        let res: Vec<Term<'a>> = node.children.borrow().iter().filter_map(|h| handle_to_term(env, h)).collect();
        // Encodes to erlang list term.
        res.encode(env)
    };

    match node.data {
        // Root document node. As far as I know, this is only located in the
        // root of the DOM.
        NodeData::Document => Some(children()),

        NodeData::Doctype { ref name, ref public_id, ref system_id } => {
            Some((::atoms::doctype(), STW(name), STW(public_id), STW(system_id)).encode(env))
        }

        NodeData::Text { ref contents } => Some(STW(&*contents.borrow()).encode(env)),

        NodeData::Comment { ref contents } => Some((::atoms::comment(), STW(contents)).encode(env)),

        NodeData::Element { ref name, ref attrs, .. } => {
            let attribute_terms: Vec<Term<'a>> = attrs.borrow().iter()
                .map(|a| (QNW(&a.name), STW(&a.value)).encode(env))
                .collect();

            Some((QNW(name), attribute_terms, children()).encode(env))
        }

        _ => None,
    }
}
