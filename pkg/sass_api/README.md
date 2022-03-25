This package exposes additional APIs for working with [Dart Sass], including
access to the Sass AST and its load resolution logic.

[Dart Sass]: https://pub.dev/packages/sass

This is split out into a separate package because so that it can be versioned
separately. The `sass_api` package's API is expected to evolve more quickly than
the Sass language itself, and will likely have more breaking changes as the
internals evolve to suit the needs of the Sass compiler.

## Depending on Development Versions

Sometimes it's necessary to depend on a version of a package that hasn't been
released yet. Because this package directly re-exports names from the main
`sass` package, you'll need to make sure you have a Git dependency on both it
*and* the `sass` package:

```yaml
dependency_overrides:
  sass:
    git:
      url: https://github.com/sass/sass
      ref: main # Replace this with a feature branch if necessary
  sass_api:
    git:
      url: https://github.com/sass/sass
      ref: main # Make sure this is the same as above!
      path: pkg/sass_api
```
