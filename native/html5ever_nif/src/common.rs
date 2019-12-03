use rustler::{Encoder, Env, Term};

use html5ever::QualName;
use tendril::StrTendril;

// Zero-cost wrapper types which makes it possible to implement
// Encoder for these externally defined types.
// Unsure if this is a great way of doing it, but it's the way
// that produced the cleanest and least noisy code.
pub struct QNW<'a>(pub &'a QualName);
pub struct STW<'a>(pub &'a StrTendril);

impl<'b> Encoder for QNW<'b> {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let data: &str = &*self.0.local;
        data.encode(env)
    }
}
impl<'b> Encoder for STW<'b> {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let data: &str = &*self.0;
        data.encode(env)
    }
}
