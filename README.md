## Embedded Dart Sass

This is a wrapper for [Dart Sass][] that implements the compiler side of the
[Embedded Sass protocol][]. It's designed to be embedded in a host language,
which then exposes an API for users to invoke Sass and define custom functions
and importers.

[Dart Sass]: https://sass-lang.com/dart-sass
[Embedded Sass protocol]: https://github.com/sass/sass-embedded-protocol/blob/master/README.md#readme

### Usage

- `dart-sass-embedded` starts the compiler and listens on stdin.
- `dart-sass-embedded --version` prints `versionResponse` with `id = 0` in JSON and exits.

### Development

To run the embedded compiler from source:

* Run `dart pub get`.

* [Install `buf`].

* Run `dart run grinder protobuf`.

From there, you can either run `dart bin/dart_sass_embedded.dart` directly or
`dart run grinder pkg-standalone-dev` to build a compiled development
executable.

[Install `buf`]: https://docs.buf.build/installation

### Releases

Binary releases are available from the [GitHub release page]. We recommend that
embedded hosts embed these release binaries in their packages, or use a
post-install script to install a specific version of the embedded compiler to
avoid version skew.

[GitHub release page]: https://github.com/sass/dart-sass-embedded/releases

Disclaimer: this is not an official Google product.
