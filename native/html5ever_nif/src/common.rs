use ::rustler::{NifEncoder, NifEnv, NifTerm};

use ::html5ever::QualName;
use ::tendril::StrTendril;

// Zero-cost wrapper types which makes it possible to implement
// NifEncoder for these externally defined types.
// Unsure if this is a great way of doing it, but it's the way
// that produced the cleanest and least noisy code.
pub struct QNW<'a>(pub &'a QualName);
pub struct STW<'a>(pub &'a StrTendril);

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
