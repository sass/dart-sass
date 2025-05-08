This directory contains JS type definitions for Dart types that are passed as-is
to JavaScript, without wrappers or conversions. This isn't officially supported
by Dart's JS interop because it fundamentally cannot work with WASM, but it does
work in practice with compilation to JS and it's substantially more efficient
than converting or wrapping every interface.
