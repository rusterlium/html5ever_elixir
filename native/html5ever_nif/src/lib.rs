#[macro_use]
extern crate rustler;
#[macro_use]
extern crate lazy_static;
extern crate html5ever;
extern crate tendril;
extern crate scoped_pool;

use std::borrow::Cow;
use std::fmt;

use rustler::{
    NifEnv,
    NifTerm,
    NifResult,
    NifEncoder,
};

use html5ever::{ QualName };
use html5ever::rcdom::{ RcDom, Handle, NodeEnum };
use tendril::{ TendrilSink, StrTendril };

//mod flat_dom;

use rustler::types::binary::NifBinary;
use rustler::env::OwnedEnv;

mod atoms {
    rustler_atoms! {
        atom html5ever_nif_result;

        atom ok;
        atom error;
        atom nif_panic;

        atom doctype;
        atom comment;
    }
}

struct QNW<'a>(&'a QualName);
struct STW<'a>(&'a StrTendril);

impl<'b> NifEncoder for QNW<'b> {
    fn encode<'a>(&self, env: NifEnv<'a>) -> NifTerm<'a> {
        let data: &str = &*self.0.local;
        data.encode(env)
    }
}
impl<'b> NifEncoder for STW<'b> {
    fn encode<'a>(&self, env: NifEnv<'a>) -> NifTerm<'a> {
        let data: &str = &*self.0;
        data.encode(env)
    }
}

fn handle_to_term<'a>(env: NifEnv<'a>, handle: &Handle) -> NifTerm<'a> {
    let node = handle.borrow();

    let res: Vec<NifTerm<'a>> =
        node.children.iter().map(|h| handle_to_term(env, h)).collect();
    let children = res.encode(env);

    match node.node {
        NodeEnum::Document =>
            children,
        NodeEnum::Doctype(ref name, ref pubid, ref sysid) =>
            (atoms::doctype(), STW(name), STW(pubid), STW(sysid)).encode(env),
        NodeEnum::Text(ref text) =>
            STW(text).encode(env),
        NodeEnum::Comment(ref text) =>
            (atoms::comment(), STW(text)).encode(env),
        NodeEnum::Element(ref name, ref elem_type, ref attr) => {
            let attr_terms: Vec<NifTerm<'a>> =
                attr.iter().map(|a| {
                    (QNW(&a.name), STW(&a.value)).encode(env)
                }).collect();

            (QNW(name), attr_terms, children).encode(env)
        },
    }
}

use std::thread;
use std::panic;

fn parse_async<'a>(env: NifEnv<'a>, args: &Vec<NifTerm<'a>>) -> NifResult<NifTerm<'a>> {
    let mut owned_env = OwnedEnv::new();
    let input_term_saved = owned_env.save(args[0]);

    let pid = env.pid();

    POOL.spawn(move || {
        owned_env.send(pid, |inner_env| {
            match panic::catch_unwind(|| {
                let input_term = input_term_saved.load(inner_env);

                let binary: NifBinary = match input_term.decode() {
                    Ok(inner) => inner,
                    Err(_) => panic!("argument is not a binary"),
                };

                let sink = RcDom::default();

                let parser = html5ever::parse_document(sink, Default::default());
                let result = parser.one(
                    std::str::from_utf8(binary.as_slice()).unwrap());

                let result_term = handle_to_term(inner_env, &result.document);
                (atoms::html5ever_nif_result(), atoms::ok(), result_term)
                    .encode(inner_env)
            }) {
                Ok(term) => term,
                Err(err) => {
                    let reason =
                        if let Some(s) = err.downcast_ref::<String>() {
                            s.encode(inner_env)
                        } else if let Some(&s) = err.downcast_ref::<&'static str>() {
                            s.encode(inner_env)
                        } else {
                            atoms::nif_panic().encode(inner_env)
                        };
                    (atoms::html5ever_nif_result(), atoms::error(), reason)
                        .encode(inner_env)
                },
            }
        });
    });

    Ok(atoms::ok().encode(env))
}

rustler_export_nifs!(
    "Elixir.ExHtml5ever.Native",
    [("parse_async", 1, parse_async)],
    Some(on_load)
);

lazy_static! {
    static ref POOL: scoped_pool::Pool = scoped_pool::Pool::new(4);
}

fn on_load<'a>(env: NifEnv<'a>, _load_info: NifTerm<'a>) -> bool {
    true
}
