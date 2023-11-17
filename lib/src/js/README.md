# JavaScript API

This directory contains Dart Sass's implementation of the Sass JS API. Dart's JS
interop support is primarily intended for _consuming_ JS libraries from Dart, so
we have to jump through some hoops in order to effectively _produce_ a JS
library with the desired API.

JS support has its own dedicated entrypoint in [`../js.dart`]. The [`cli_pkg`
package] ensures that when users load Dart Sass _as a library_, this entrypoint
is run instead of the CLI entrypoint, but otherwise it's up to us to set up the
library appropriately. To do so, we use JS interop to define an [`Exports`]
class that is in practice implemented by a CommonJS-like[^1] `exports` object,
and then assign various values to this object.

[`../js.dart`]: ../js.dart
[`cli_pkg` package]: https://github.com/google/dart_cli_pkg
[`Exports`]: exports.dart

[^1]: It's not _literally_ CommonJS because it needs to run directly on browsers
      as well, but it's still an object named `exports` that we can hang names
      off of.

## Value Types

The JS API value types pose a particular challenge from Dart. Although every
Dart class is represented by a JavaScript class when compiled to JS, Dart has no
way of specifying what the JS API of those classes should be. What's more, in
order to make the JS API as efficient as possible, we want to be able to pass
the existing Dart [`Value`] objects as-is to custom functions rather than
wrapping them with JS-only wrappers.

[`Value`]: ../value.dart

To solve the first problem, in [`reflection.dart`] we use JS interop to wrap the
manual method of defining a JavaScript class. We use this to create a
JS-specific class for each value type, with all the JS-specific methods and
properties defined by Sass's JS API spec. However, while normal JS constructors
just set some properties on `this`, our constructors for these classes return
Dart `Value` objects instead.

[`reflection.dart`]: reflection.dart

"But wait," I hear you say, "those `Value` objects aren't instances of the new
JS class you've created!" This is where the deep magic comes in. Once we've
defined our class with its phony constructor, we create a single Dart object of
the given `Value` subclass and _edit its JavaScript prototype chain_ to include
the new class we just created. Once that's done, all the Dart value types will
have exactly the right JS API (including responding correctly to `instanceof`!)
and the constructor will now correctly return an instance of the JS class.

## Legacy API

Dart Sass also supports the legacy JS API in the [`legacy`] directory. This hews
as close as possible to the API of the old `node-sass` package which wrapped the
old LibSass implementation. It's no longer being actively updated, but we still
need to support it at least until the next major version release of Dart Sass.

[`legacy`]: legacy
