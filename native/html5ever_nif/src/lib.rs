#[macro_use]
extern crate rustler;
#[macro_use]
extern crate lazy_static;
extern crate html5ever;
extern crate tendril;
extern crate scoped_pool;

use std::panic;

use rustler::{
    NifEnv,
    NifTerm,
    NifResult,
    NifEncoder,
};
use rustler::types::binary::NifBinary;
use rustler::env::OwnedEnv;

use html5ever::{ QualName };
use html5ever::rcdom::{ RcDom, Handle, NodeEnum };
use tendril::{ TendrilSink, StrTendril };

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

// Zero-cost wrapper types which makes it possible to implement
// NifEncoder for these externally defined types.
// Unsure if this is a great way of doing it, but it's the way
// that produced the cleanest and least noisy code.
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

/// Takes a Handle from a RcDom, encodes it into a NifTerm.
/// This follows the mochiweb encoding scheme with two exceptions:
/// * A `{:doctype, name, pubid, sysid}` node.
/// * Always returns a list as it's root node.
fn handle_to_term<'a>(env: NifEnv<'a>, handle: &Handle) -> NifTerm<'a> {
    let node = handle.borrow();

    // Closure so that we don't encode this when we don't need to return
    // it to the user.
    let children = || {
        // Encodes a Vec<Handle> to a Vec<NifTerm>
        let res: Vec<NifTerm<'a>> =
            node.children.iter().map(|h| handle_to_term(env, h)).collect();
        // Encodes to erlang list term.
        res.encode(env)
    };

    match node.node {
        // Root document node. As far as I know, this is only located in the
        // root of the DOM.
        NodeEnum::Document =>
            children(),

        NodeEnum::Doctype(ref name, ref pubid, ref sysid) =>
            (atoms::doctype(), STW(name), STW(pubid), STW(sysid)).encode(env),

        NodeEnum::Text(ref text) =>
            STW(text).encode(env),

        NodeEnum::Comment(ref text) =>
            (atoms::comment(), STW(text)).encode(env),

        NodeEnum::Element(ref name, ref _elem_type, ref attributes) => {
            let attribute_terms: Vec<NifTerm<'a>> =
                attributes.iter()
                .map(|a| (QNW(&a.name), STW(&a.value)).encode(env))
                .collect();

            (QNW(name), attribute_terms, children()).encode(env)
        },
    }
}

// Thread pool for `parse_async`.
// TODO: How do we decide on pool size?
lazy_static! {
    static ref POOL: scoped_pool::Pool = scoped_pool::Pool::new(4);
}

fn parse_async<'a>(env: NifEnv<'a>, args: &Vec<NifTerm<'a>>) -> NifResult<NifTerm<'a>> {
    let mut owned_env = OwnedEnv::new();

    // Copies the term into the inner env. Since this term is normally a large
    // binary term, copying it over should be cheap, since the binary will be
    // refcounted within the BEAM.
    let input_term = owned_env.save(args[0]);

    let return_pid = env.pid();

    POOL.spawn(move || {
        owned_env.send(return_pid, |inner_env| {
            // This should not really be done in user code. We (Rustler project)
            // need to find a better abstraction that eliminates this.
            match panic::catch_unwind(|| {
                let binary: NifBinary = match input_term.load(inner_env).decode() {
                    Ok(inner) => inner,
                    Err(_) => panic!("argument is not a binary"),
                };

                let sink = RcDom::default();

                // TODO: Use Parser.from_bytes instead?
                let parser = html5ever::parse_document(sink, Default::default());
                let result = parser.one(
                    std::str::from_utf8(binary.as_slice()).unwrap());

                let result_term = handle_to_term(inner_env, &result.document);
                (atoms::html5ever_nif_result(), atoms::ok(), result_term)
                    .encode(inner_env)
            }) {
                Ok(term) => term,
                Err(err) => {
                    // Try to extract a panic reason and return that. If this
                    // fails, fail generically.
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

fn parse_sync<'a>(env: NifEnv<'a>, args: &Vec<NifTerm<'a>>) -> NifResult<NifTerm<'a>> {
    let binary: NifBinary = args[0].decode()?;
    let sink = RcDom::default();

    // TODO: Use Parser.from_bytes instead?
    let parser = html5ever::parse_document(sink, Default::default());
    let result = parser.one(
        std::str::from_utf8(binary.as_slice()).unwrap());

    //std::thread::sleep(std::time::Duration::from_millis(10));

    let result_term = handle_to_term(env, &result.document);

    Ok((atoms::html5ever_nif_result(), atoms::ok(), result_term)
        .encode(env))

}

rustler_export_nifs!(
    "Elixir.ExHtml5ever.Native",
    [("parse_async", 1, parse_async),
     ("parse_sync", 1, parse_sync)],
    Some(on_load)
);


fn on_load<'a>(_env: NifEnv<'a>, _load_info: NifTerm<'a>) -> bool {
    true
}
