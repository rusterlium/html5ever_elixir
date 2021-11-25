use rustler::types::binary::Binary;
use rustler::{Decoder, Encoder, Env, Error, NifResult, Term};

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

#[rustler::nif]
fn parse_sync<'a>(env: Env<'a>, binary: Binary) -> Term<'a> {
    parse(env, binary)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn parse_dirty<'a>(env: Env<'a>, binary: Binary) -> Term<'a> {
    parse(env, binary)
}

fn parse<'a>(env: Env<'a>, binary: Binary) -> Term<'a> {
    let sink = flat_dom::FlatSink::new();

    let utf = std::str::from_utf8(binary.as_slice()).unwrap();

    let parser = html5ever::parse_document(sink, Default::default());
    let result = parser.one(utf);

    let result_term = flat_dom::flat_sink_to_rec_term(env, &result);

    (atoms::html5ever_nif_result(), atoms::ok(), result_term).encode(env)
}

#[rustler::nif]
fn flat_parse_sync<'a>(env: Env<'a>, binary: Binary) -> Term<'a> {
    flat_parse(env, binary)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn flat_parse_dirty<'a>(env: Env<'a>, binary: Binary) -> Term<'a> {
    flat_parse(env, binary)
}

fn flat_parse<'a>(env: Env<'a>, binary: Binary) -> Term<'a> {
    let sink = flat_dom::FlatSink::new();

    let utf = std::str::from_utf8(binary.as_slice()).unwrap();

    let parser = html5ever::parse_document(sink, Default::default());
    let result = parser.one(utf);

    let result_term = flat_dom::flat_sink_to_flat_term(env, &result);

    (atoms::html5ever_nif_result(), atoms::ok(), result_term).encode(env)
}

rustler::init!(
    "Elixir.Html5ever.Native",
    [parse_sync, parse_dirty, flat_parse_sync, flat_parse_dirty],
    load = on_load
);

fn on_load<'a>(_env: Env<'a>, _load_info: Term<'a>) -> bool {
    true
}
