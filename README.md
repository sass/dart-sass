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

## Behavioral Differences

There are a few intentional behavioral differences between Dart Sass and Ruby
Sass. These are generally places where Ruby Sass has an undesired behavior, and
it's substantially easier to implement the correct behavior than it would be to
implement compatible behavior. These should all have tracking bugs against Ruby
Sass to update the reference behavior.

1. `@extend` only accepts simple selectors, as does the second argument of
   `selector-extend()`. See [issue 1599][].

2. Subject selectors are not supported. See [issue 1126][].

3. Pseudo selector arguments are parsed as `<declaration-value>`s rather than
   having a more limited custom parsing. See [issue 2120][].

4. The numeric precision is set to 10. See [issue 1122][].

5. The indented syntax parser is more flexible: it doesn't require consistent
   indentation across the whole document. This doesn't have an issue yet; I need
   to talk to Chris to determine if it's actually the right way forward.

6. Colors do not support channel-by-channel arithmetic. See [issue 2144][].

7. Unitless numbers aren't `==` to unit numbers with the same value. In
   addition, map keys follow the same logic as `==`-equality. See
   [issue 1496][].

[issue 1599]: https://github.com/sass/sass/issues/1599
[issue 1126]: https://github.com/sass/sass/issues/1126
[issue 2120]: https://github.com/sass/sass/issues/2120
[issue 1122]: https://github.com/sass/sass/issues/1122
[issue 2144]: https://github.com/sass/sass/issues/2144
[issue 1496]: https://github.com/sass/sass/issues/1496

Disclaimer: this is not an official Google product.
