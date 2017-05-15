#[macro_use]
extern crate rustler;
#[macro_use]
extern crate rustler_codegen;
#[macro_use]
extern crate lazy_static;
extern crate tendril;
extern crate scoped_pool;

extern crate html5ever;
extern crate markup5ever;

use std::panic;

use rustler::{NifEnv, NifTerm, NifResult, NifError, NifEncoder, NifDecoder};
use rustler::types::binary::NifBinary;
use rustler::env::OwnedEnv;

use html5ever::rcdom::RcDom;
use html5ever::driver::ParseOpts;
use html5ever::tokenizer::TokenizerOpts;
use html5ever::tree_builder::TreeBuilderOpts;
use html5ever::tree_builder::QuirksMode;
use tendril::TendrilSink;

use ::common::{ QNW, STW };

mod common;
mod rc_dom;
mod flat_dom;

mod atoms {
    rustler_atoms! {
        atom html5ever_nif_result;

        atom ok;
        atom error;
        atom nil;
        atom nif_panic;

        atom doctype;
        atom comment;

        atom discard_bom;
        atom scripting_enabled;
        atom iframe_srcdoc;
        atom drop_doctype;
        atom error_level;

        atom none;
        atom some;
        atom all;
    }
}

#[derive(PartialEq, Eq)]
enum ErrorLevel {
    None,
    Some,
    All,
}
impl<'a> NifDecoder<'a> for ErrorLevel {
    fn decode(term: NifTerm<'a>) -> NifResult<ErrorLevel> {
        if atoms::none() == term {
            Ok(ErrorLevel::None)
        } else if atoms::some() == term {
            Ok(ErrorLevel::Some)
        } else if atoms::all() == term {
            Ok(ErrorLevel::All)
        } else {
            Err(NifError::BadArg)
        }
    }
}

fn term_to_configs(term: NifTerm) -> NifResult<ParseOpts> {
    if atoms::nil() == term {
        Ok(ParseOpts::default())
    } else {
        let env = term.get_env();

        let errors: ErrorLevel = term.map_get(atoms::error_level().to_term(env))?.decode()?;

        let discard_bom: bool = term.map_get(atoms::discard_bom().to_term(env))?.decode()?;
        let scripting_enabled: bool = term.map_get(atoms::scripting_enabled().to_term(env))?
            .decode()?;
        let iframe_srcdoc: bool = term.map_get(atoms::iframe_srcdoc().to_term(env))?.decode()?;
        let drop_doctype: bool = term.map_get(atoms::drop_doctype().to_term(env))?.decode()?;

        Ok(ParseOpts {
            tokenizer: TokenizerOpts {
                exact_errors: errors == ErrorLevel::All,
                discard_bom: discard_bom,
                profile: false,
                initial_state: None,
                last_start_tag_name: None,
            },
            tree_builder: TreeBuilderOpts {
                exact_errors: errors == ErrorLevel::All,
                scripting_enabled: scripting_enabled,
                iframe_srcdoc: iframe_srcdoc,
                drop_doctype: drop_doctype,
                ignore_missing_rules: false,
                quirks_mode: QuirksMode::NoQuirks,
            },
        })
    }
}

// Thread pool for `parse_async`.
// TODO: How do we decide on pool size?
lazy_static! {
    static ref POOL: scoped_pool::Pool = scoped_pool::Pool::new(4);
}

fn parse_async<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let mut owned_env = OwnedEnv::new();

    // Copies the term into the inner env. Since this term is normally a large
    // binary term, copying it over should be cheap, since the binary will be
    // refcounted within the BEAM.
    let input_term = owned_env.save(args[0]);

    let return_pid = env.pid();

    // let config = term_to_configs(args[1]);

    POOL.spawn(move || {
        owned_env.send_and_clear(&return_pid, |inner_env| {
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
                let result = parser.one(std::str::from_utf8(binary.as_slice()).unwrap());

                let result_term = rc_dom::handle_to_term(inner_env, &result.document);
                (atoms::html5ever_nif_result(), atoms::ok(), result_term.unwrap()).encode(inner_env)
            }) {
                Ok(term) => term,
                Err(err) => {
                    // Try to extract a panic reason and return that. If this
                    // fails, fail generically.
                    let reason = if let Some(s) = err.downcast_ref::<String>() {
                        s.encode(inner_env)
                    } else if let Some(&s) = err.downcast_ref::<&'static str>() {
                        s.encode(inner_env)
                    } else {
                        atoms::nif_panic().encode(inner_env)
                    };
                    (atoms::html5ever_nif_result(), atoms::error(), reason).encode(inner_env)
                }
            }
        });
    });

    Ok(atoms::ok().encode(env))
}

fn parse_sync<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let binary: NifBinary = args[0].decode()?;
    let sink = RcDom::default();

    // TODO: Use Parser.from_bytes instead?
    let parser = html5ever::parse_document(sink, Default::default());
    let result = parser.one(std::str::from_utf8(binary.as_slice()).unwrap());

    // std::thread::sleep(std::time::Duration::from_millis(10));

    let result_term = rc_dom::handle_to_term(env, &result.document);

    Ok((atoms::html5ever_nif_result(), atoms::ok(), result_term.unwrap()).encode(env))
}

fn flat_parse_sync<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let binary: NifBinary = args[0].decode()?;
    let sink = flat_dom::FlatSink::new();

    // TODO: Use Parser.from_bytes instead?
    let parser = html5ever::parse_document(sink, Default::default());
    let result = parser.one(std::str::from_utf8(binary.as_slice()).unwrap());

    // std::thread::sleep(std::time::Duration::from_millis(10));

    let result_term = flat_dom::flat_sink_to_term(env, &result);

    Ok((atoms::html5ever_nif_result(), atoms::ok(), result_term).encode(env))
}

rustler_export_nifs!("Elixir.Html5ever.Native",
                     [
                         ("parse_async", 1, parse_async),
                         ("parse_sync", 1, parse_sync),
                         ("flat_parse_sync", 1, flat_parse_sync)
                     ],
                     Some(on_load));


fn on_load<'a>(_env: NifEnv<'a>, _load_info: NifTerm<'a>) -> bool {
    true
}
