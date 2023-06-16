use flat_dom::FlatSink;
use rustler::types::binary::Binary;
use rustler::{Env, Term};

use tendril::TendrilSink;
use thiserror::Error;

mod common;
mod flat_dom;

#[derive(Error, Debug)]
pub enum Html5everExError {
    #[error("cannot transform bytes from binary to a valid UTF8 string")]
    BytesToUtf8(#[from] std::str::Utf8Error),

    #[error("cannot insert entry in a map")]
    MapEntry,
}

impl rustler::Encoder for Html5everExError {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        format!("{self}").encode(env)
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn parse<'a>(
    env: Env<'a>,
    binary: Binary,
    attributes_as_maps: bool,
) -> Result<Term<'a>, Html5everExError> {
    let flat_sink = build_flat_sink(binary.as_slice())?;

    flat_dom::flat_sink_to_rec_term(env, &flat_sink, attributes_as_maps)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn flat_parse<'a>(
    env: Env<'a>,
    binary: Binary,
    attributes_as_maps: bool,
) -> Result<Term<'a>, Html5everExError> {
    let flat_sink = build_flat_sink(binary.as_slice())?;

    flat_dom::flat_sink_to_flat_term(env, &flat_sink, attributes_as_maps)
}

fn build_flat_sink(bin_slice: &[u8]) -> Result<FlatSink, Html5everExError> {
    let utf8 = std::str::from_utf8(bin_slice)?;

    let sink = flat_dom::FlatSink::new();
    let parser = html5ever::parse_document(sink, Default::default());

    Ok(parser.one(utf8))
}

rustler::init!(
    "Elixir.Html5ever.Native",
    [parse, flat_parse],
    load = on_load
);

fn on_load<'a>(_env: Env<'a>, _load_info: Term<'a>) -> bool {
    true
}
