A [Dart](https://www.dartlang.org) implementation of
[Sass](http://sass-lang.com/).

## Using Dart Sass

Dart Sass isn't ready for distribution yet, but it's possible to test it out by
running from source. This assumes you've already checked out this repository.

1. [Install Dart](https://www.dartlang.org/install). If you download it
  manually, make sure the SDK's `bin` directory is on your `PATH`.

2. In this repository, run `pub get`. This will install Dart Sass's
   dependencies.

3. Run `dart bin/sass.dart path/to/file.scss`.

That's it!

## Goals

Dart Sass is intended to eventually replace Ruby Sass as the canonical
implementation of the Sass language. It has a number of advantages:

* It's fast. The Dart VM is highly optimized, and getting faster all the time
  (for the latest performance numbers, see [`perf.md`][perf]). It's much faster
  than Ruby, and not too far away from C.

* It's portable. The Dart VM has no external dependencies and can compile
  applications into standalone snapshot files, so a fully-functional Dart Sass
  could be distributed as only three files (the VM, the snapshot, and a wrapper
  script). Dart can also be compiled to JavaScript, which would make it easy to
  distribute Sass through NPM or other JS package managers.

* It's friendlier to contributors. Dart is substantially easier to learn than
  Ruby, and many Sass users in Google in particular are already familiar with
  it. More contributors translates to faster, more consistent development.

[perf]: https://github.com/sass/dart-sass/blob/master/perf.md

Disclaimer: this is not an official Google product.
