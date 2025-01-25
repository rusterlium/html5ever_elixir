use rustler::{Encoder, Env, Term};

use html5ever::QualName;
use tendril::StrTendril;

// Zero-cost wrapper types which makes it possible to implement
// Encoder for these externally defined types.
// Unsure if this is a great way of doing it, but it's the way
// that produced the cleanest and least noisy code.
pub struct QualNameWrapper<'a>(pub &'a QualName);
pub struct StrTendrilWrapper<'a>(pub &'a StrTendril);

impl Encoder for QualNameWrapper<'_> {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let data: &str = &self.0.local;
        data.encode(env)
    }
}
impl Encoder for StrTendrilWrapper<'_> {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let data: &str = self.0;
        data.encode(env)
    }
}
