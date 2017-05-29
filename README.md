A [Dart][dart] implementation of [Sass][sass]. **Sass makes CSS fun again**.

[![Travis build status](https://api.travis-ci.org/sass/dart-sass.svg)](https://travis-ci.org/sass/dart-sass) [![Appveyor build status](https://ci.appveyor.com/api/projects/status/84rl9hvu8uoecgef?svg=true)](https://ci.appveyor.com/project/nex3/dart-sass)

[dart]: https://www.dartlang.org
[sass]: http://sass-lang.com/

* [Using Dart Sass](#using-dart-sass)
  * [From Chocolatey (Windows)](#from-chocolatey-windows)
  * [Standalone](#standalone)
  * [From npm](#from-npm)
  * [From Pub](#from-pub)
  * [From Source](#from-source)
* [Goals](#goals)
* [Behavioral Differences](#behavioral-differences)

## Using Dart Sass

There are a few different ways to install and run Dart Sass, depending on your
environment and your needs.

### From Chocolatey (Windows)

If you use [the Chocolatey package manager](https://chocolatey.org/) for
Windows, you can install Dart Sass by running

```cmd
choco install sass -prerelease
```

That'll give you a `sass` executable on your command line that will run Dart
Sass.

### Standalone

You can download the standalone Dart Sass archive for your operating
system—containing the Dart VM and the snapshot of the Sass library—from
[the release page][releases]. Extract it, add the directory to your path, and
the `dart-sass` executable is ready to run!

[releases]: https://github.com/sass/dart-sass/releases/

To add the directory to your path on Windows, open the Control Panel, then
search for and select "edit environment variables". Find the variable named
`PATH`, click Edit, add `;C:\path\to\dart-sass` to the end of the value, then
click OK.

On more Unix-y systems, edit your shell configuration file (usually `~/.bashrc`
or `~/.profile`) and add at the end:

```sh
export PATH=$PATH:/path/to/dart-sass
```

Regardless of your OS, you'll need to restart your terminal in order for this
configuration to take effect.

### From npm

Dart Sass is available, compiled to JavaScript, [as an npm package][npm]. You
can install it globally using `npm install -g dart-sass`, or to your project
using `npm install dart-sass`. This provides a `dart-sass` executable as well as
a library:

[npm]: https://www.npmjs.com/package/dart-sass

```js
var sass = require('dart-sass');

sass.render({file: scss_filename}, function(err, result) { /* ... */ });

// OR

var result = sass.renderSync({file: scss_filename});
```

The `render()` and `renderSync()` functions will eventually support the same API
as [node-sass's][render], but today they only supports the `file` option.

[render]: https://github.com/sass/node-sass#options

### From Pub

If you're a Dart user, you can install Dart Sass globally using `pub global
activate sass ^1.0.0-alpha`, which will provide a `dart-sass` executable. You can
also add it to your pubspec and use it as a library:

```dart
import 'package:sass/sass.dart' as sass;

void main(List<String> args) {
  print(sass.render(args.first));
}
```

See [the Dart API docs][api] for details.

[api]: https://www.dartdocs.org/documentation/sass/latest/sass/sass-library.html

### From Source

Assuming you've already checked out this repository:

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
  distribute Sass through npm or other JS package managers.

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
   indentation across the whole document. See [issue 2176][].

6. Colors do not support channel-by-channel arithmetic. See [issue 2144][].

7. Unitless numbers aren't `==` to unit numbers with the same value. In
   addition, map keys follow the same logic as `==`-equality. See
   [issue 1496][].

8. `rgba()` and `hsla()` alpha values with percentage units are interpreted as
   percentages. Other units are forbidden. See [issue 1525][].

9. Too many variable arguments passed to a function is an error. See
   [issue 1408][].

10. Allow `@extend` to reach outside a media query if there's an identical
    `@extend` defined outside that query. This isn't tracked explicitly, because
    it'll be irrelevant when [issue 1050][] is fixed.

11. Some selector pseudos containing placeholder selectors will be rendered
    where they wouldn't be in Ruby Sass. This better matches the semantics of
    the selectors in question, and is more efficient. See [issue 2228][].

12. The old-style `:property value` syntax is not supported in the indented
    syntax. See [issue 2245][].

13. The reference combinator is not supported. See [issue 303][].

14. Universal selector unification is symmetrical. See [issue 2247][].

15. `@extend` doesn't produce an error if it matches but fails to unify. See
    [issue 2250][].

16. Dart Sass currently only supports UTF-8 documents. We'd like to support
    more, but Dart currently doesn't support them. See [dart-lang/sdk#11744][],
    for example.

[issue 1599]: https://github.com/sass/sass/issues/1599
[issue 1126]: https://github.com/sass/sass/issues/1126
[issue 2120]: https://github.com/sass/sass/issues/2120
[issue 1122]: https://github.com/sass/sass/issues/1122
[issue 2176]: https://github.com/sass/sass/issues/2176
[issue 2144]: https://github.com/sass/sass/issues/2144
[issue 1496]: https://github.com/sass/sass/issues/1496
[issue 1525]: https://github.com/sass/sass/issues/1525
[issue 1408]: https://github.com/sass/sass/issues/1408
[issue 1050]: https://github.com/sass/sass/issues/1050
[issue 2228]: https://github.com/sass/sass/issues/2228
[issue 2245]: https://github.com/sass/sass/issues/2245
[issue 303]: https://github.com/sass/sass/issues/303
[issue 2247]: https://github.com/sass/sass/issues/2247
[issue 2250]: https://github.com/sass/sass/issues/2250
[dart-lang/sdk#11744]: https://github.com/dart-lang/sdk/issues/11744

Disclaimer: this is not an official Google product.
