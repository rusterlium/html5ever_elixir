use std::panic;

use lazy_static::lazy_static;

use rustler::env::OwnedEnv;
use rustler::types::binary::Binary;
use rustler::{rustler_export_nifs, Decoder, Encoder, Env, Error, NifResult, Term};

//use html5ever::rcdom::RcDom;
use tendril::TendrilSink;

mod common;
mod flat_dom;

mod atoms {
    rustler::atoms! {
        html5ever_nif_result,

        ok,
        error,
        nif_panic,

        doctype,
        comment,

        none,
        some,
        all,
    }
}

#[derive(PartialEq, Eq)]
enum ErrorLevel {
    None,
    Some,
    All,
}
impl<'a> Decoder<'a> for ErrorLevel {
    fn decode(term: Term<'a>) -> NifResult<ErrorLevel> {
        if atoms::none() == term {
            Ok(ErrorLevel::None)
        } else if atoms::some() == term {
            Ok(ErrorLevel::Some)
        } else if atoms::all() == term {
            Ok(ErrorLevel::All)
        } else {
            Err(Error::BadArg)
        }
    }
}

// Thread pool for `parse_async`.
// TODO: How do we decide on pool size?
lazy_static! {
    static ref POOL: scoped_pool::Pool = scoped_pool::Pool::new(4);
}

fn parse_sync<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let binary: Binary = args[0].decode()?;
    let sink = flat_dom::FlatSink::new();

    // TODO: Use Parser.from_bytes instead?
    let parser = html5ever::parse_document(sink, Default::default());
    let result = parser.one(std::str::from_utf8(binary.as_slice()).unwrap());

    // std::thread::sleep(std::time::Duration::from_millis(10));

    let result_term = flat_dom::flat_sink_to_rec_term(env, &result);

    Ok((atoms::html5ever_nif_result(), atoms::ok(), result_term).encode(env))
}

fn parse_async<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
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
                let binary: Binary = match input_term.load(inner_env).decode() {
                    Ok(inner) => inner,
                    Err(_) => panic!("argument is not a binary"),
                };

                let sink = flat_dom::FlatSink::new();

                // TODO: Use Parser.from_bytes instead?
                let parser = html5ever::parse_document(sink, Default::default());
                let result = parser.one(std::str::from_utf8(binary.as_slice()).unwrap());

                let result_term = flat_dom::flat_sink_to_rec_term(inner_env, &result);
                (atoms::html5ever_nif_result(), atoms::ok(), result_term).encode(inner_env)
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

fn flat_parse_sync<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
    let binary: Binary = args[0].decode()?;
    let sink = flat_dom::FlatSink::new();

    // TODO: Use Parser.from_bytes instead?
    let parser = html5ever::parse_document(sink, Default::default());
    let result = parser.one(std::str::from_utf8(binary.as_slice()).unwrap());

    // std::thread::sleep(std::time::Duration::from_millis(10));

    let result_term = flat_dom::flat_sink_to_flat_term(env, &result);

    Ok((atoms::html5ever_nif_result(), atoms::ok(), result_term).encode(env))
}

fn flat_parse_async<'a>(env: Env<'a>, args: &[Term<'a>]) -> NifResult<Term<'a>> {
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
                let binary: Binary = match input_term.load(inner_env).decode() {
                    Ok(inner) => inner,
                    Err(_) => panic!("argument is not a binary"),
                };

                let sink = flat_dom::FlatSink::new();

                // TODO: Use Parser.from_bytes instead?
                let parser = html5ever::parse_document(sink, Default::default());
                let result = parser.one(std::str::from_utf8(binary.as_slice()).unwrap());

                let result_term = flat_dom::flat_sink_to_flat_term(inner_env, &result);
                (atoms::html5ever_nif_result(), atoms::ok(), result_term).encode(inner_env)
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

rustler_export_nifs!(
    "Elixir.Html5ever.Native",
    [
        ("parse_sync", 1, parse_sync),
        ("parse_async", 1, parse_async),
        ("flat_parse_sync", 1, flat_parse_sync),
        ("flat_parse_async", 1, flat_parse_async)
    ],
    Some(on_load)
);

fn on_load<'a>(_env: Env<'a>, _load_info: Term<'a>) -> bool {
    true
}
