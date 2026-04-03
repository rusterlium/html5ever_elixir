mod arena_sink;
mod common;

use rustler::types::binary::Binary;
use rustler::{Env, Term};

use thiserror::Error;

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
    let utf8 = std::str::from_utf8(binary.as_slice())?;

    let arena = typed_arena::Arena::new();
    let first_node = arena_sink::html5ever_parse_slice_into_arena(utf8.as_bytes(), &arena);
    let term = arena_sink::nodes_to_term(env, first_node, attributes_as_maps);

    Ok(term)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn flat_parse<'a>(
    env: Env<'a>,
    binary: Binary,
    attributes_as_maps: bool,
) -> Result<Term<'a>, Html5everExError> {
    let utf8 = std::str::from_utf8(binary.as_slice())?;

    let arena = typed_arena::Arena::new();
    let first_node = arena_sink::html5ever_parse_slice_into_arena(utf8.as_bytes(), &arena);
    arena_sink::nodes_to_flat_term(env, first_node, attributes_as_maps)
}

rustler::init!("Elixir.Html5ever.Native");
