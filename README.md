## Embedded Dart Sass

This is a wrapper for [Dart Sass][] that implements the compiler side of the
[Embedded Sass protocol][]. It's designed to be embedded in a host language,
which then exposes an API for users to invoke Sass and define custom functions
and importers.

[Dart Sass]: https://sass-lang.com/dart-sass
[Embedded Sass protocol]: https://github.com/sass/sass-embedded-protocol/blob/master/README.md#readme

### Usage

- `dart_sass_embedded` starts the compiler and listens on stdin.
- `dart_sass_embedded --version` prints `versionResponse` with `id = 0` in JSON and exits.

### Releases

Binary releases are available from the [GitHub release page]. We recommend that
embedded hosts embed these release binaries in their packages, or use a
post-install script to install a specific version of the embedded compiler to
avoid version skew.

[GitHub release page]: https://github.com/sass/dart-sass-embedded/releases

Disclaimer: this is not an official Google product.
