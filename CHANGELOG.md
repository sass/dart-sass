## 1.55.0

* **Potentially breaking bug fix:** Sass numbers are now universally stored as
  64-bit floating-point numbers, rather than sometimes being stored as integers.
  This will generally make arithmetic with very large numbers more reliable and
  more consistent across platforms, but it does mean that numbers between nine
  quadrillion and nine quintillion will no longer be represented with full
  accuracy when compiling Sass on the Dart VM.

* **Potentially breaking bug fix:** Sass equality is now properly [transitive].
  Two numbers are now considered equal (after doing unit conversions) if they
  round to the same `1e-11`th. Previously, numbers were considered equal if they
  were within `1e-11` of one another, which led to some circumstances where `$a
  == $b` and `$b == $c` but `$a != $b`.

[transitive]: https://en.wikipedia.org/wiki/Transitive_property

* **Potentially breaking bug fix:** Various functions in `sass:math` no longer
  treat floating-point numbers that are very close (but not identical) to
  integers as integers. Instead, these functions now follow the floating-point
  specification exactly. For example, `math.pow(0.000000000001, -1)` now returns
  `1000000000000` instead of `Infinity`.

* Emit a deprecation warning for `$a -$b` and `$a +$b`, since these look like
  they could be unary operations but they're actually parsed as binary
  operations. Either explicitly write `$a - $b` or `$a (-$b)`. See
  https://sass-lang.com/d/strict-unary for more details.

### Dart API

* Add an optional `argumentName` parameter to `SassScriptException()` to make it
  easier to throw exceptions associated with particular argument names.

* Most APIs that previously returned `num` now return `double`. All APIs
  continue to _accept_ `num`, although in Dart 2.0.0 these APIs will be changed
  to accept only `double`.

### JS API

* Fix a bug in which certain warning spans would not have their properties
  accessible by the JS API.

## 1.54.9

* Fix an incorrect span in certain `@media` query deprecation warnings.

## 1.54.8

* No user-visible changes.

## 1.54.7

* Add support for 32-bit ARM releases on Linux.

## 1.54.6

* Fix a bug where a `@media` query could be incorrectly omitted from a
  stylesheet if it had multiple levels of nested `@media` queries within it
  *and* the inner queries were mergeable but the outer query was not.

## 1.54.5

* Properly consider `a ~ c` to be a superselector of `a ~ b ~ c` and `a + b +
  c`.

* Properly consider `b > c` to be a superselector of `a > b > c`, and similarly
  for other combinators.

* Properly calculate specificity for selector pseudoclasses.

* Deprecate use of `random()` when `$limit` has units to make it explicit that
   `random()` currently ignores units. A future version will no longer ignore
  units.

* Don't throw an error when the same module is `@forward`ed multiple times
  through a configured module.

### Embedded Sass

* Rather than downloading the embedded compiler for the local platform on
  install, the `sass-embedded` npm package now declares optional dependencies on
  platform-specific embedded compiler packages.

## 1.54.4

* Improve error messages when passing incorrect units that are also
  out-of-bounds to various color functions.

## 1.54.3

* Release a native ARM64 executable for Mac OS.

## 1.54.2

* No user-visible changes.

## 1.54.1

* When unifying selectors for `@extend` and `selector.unify()`, ensure that
  `:root`, `:scope`, `:host`, and `:host-context` only appear at the beginning
  of complex selectors.

## 1.54.0

* Deprecate selectors with leading or trailing combinators, or with multiple
  combinators in a row. If they're included in style rules after nesting is
  resolved, Sass will now produce a deprecation warning and, in most cases, omit
  the selector. Leading and trailing combinators can still be freely used for
  nesting purposes.

  See https://sass-lang.com/d/bogus-combinators for more details.

* Add partial support for new media query syntax from Media Queries Level 4. The
  only exception are logical operations nested within parentheses, as these were
  previously interpreted differently as SassScript expressions.

  A parenthesized media condition that begins with `not` or an opening
  parenthesis now produces a deprecation warning. In a future release, these
  will be interpreted as plain CSS instead.

* Deprecate passing non-`deg` units to `color.hwb()`'s `$hue` argument.

* Fix a number of bugs when determining whether selectors with pseudo-elements
  are superselectors.

* Treat `*` as a superselector of all selectors.

### Dart API

* Add a top-level `fakeFromImport()` function for testing custom importers
  that use `AsyncImporter.fromImport`.

### JS API

* Add a `charset` option that controls whether or not Sass emits a
  `@charset`/BOM for non-ASCII stylesheets.

* Fix Sass npm package types for TS 4.7+ Node16 and NodeNext module resolution.

## 1.53.0

* Add support for calling `var()` with an empty second argument, such as
  `var(--side, )`.

### JS API

* Fix a bug where `meta.load-css()` would sometimes resolve relative URLs
  incorrectly when called from a mixin using the legacy JS API.

### Embedded Sass

* Respect npm's proxy settings when downloading the embedded Sass compiler.

## 1.52.3

* Fix crash when trailing loud comments (`/* ... */`) appear twice in a row
  across two different imports which themselves imported the same file each.

## 1.52.2

* Preserve location of trailing loud comments (`/* ... */`) instead of pushing
  the comment to the next line.

## 1.52.1

### Command Line Interface

* Fix a bug where `--watch` mode would close immediately in TTY mode. This was
  caused by our change to close `--watch` when stdin was closed *outside of* TTY
  mode, which has been reverted for now while we work on a fix.

## 1.52.0

* Add support for arbitrary modifiers at the end of plain CSS imports, in
  addition to the existing `supports()` and media queries. Sass now allows any
  sequence of identifiers of functions after the URL of an import for forwards
  compatibility with future additions to the CSS spec.

* Fix an issue where source locations tracked through variable references could
  potentially become incorrect.

* Fix a bug where a loud comment in the source can break the source map when
  embedding the sources, when using the command-line interface or the legacy JS
  API.

### JS API

* `SassNumber.assertUnit()` and `SassNumber.assertNoUnits()` now correctly
  return the number called on when it passes the assertion.

## 1.51.0

* **Potentially breaking change**: Change the order of maps returned by
  `map.deep-merge()` to match those returned by `map.merge()`. All keys that
  appeared in the first map will now be listed first in the same order they
  appeared in that map, followed by any new keys added from the second map.

* Improve the string output of some AST nodes in error messages.

## 1.50.1

### Embedded Sass

* The JS embedded host and the embedded compiler will now properly avoid
  resolving imports relative to the current working directory unless `'.'` is
  passed as a load path.

* Fix a bug in the JS embedded host's implementation of the legacy JS API where
  imports that began with `/` could crash on Windows.

## 1.50.0

* `@extend` now treats [`:where()`] the same as `:is()`.

[`:where()`]: https://developer.mozilla.org/en-US/docs/Web/CSS/:where

### Command Line Interface

* Closing the standard input stream will now cause the `--watch` command to stop
  running.

### Embedded Sass

* Fix a bug where the JS embedded host crashed when invoking a legacy importer
  after resolving a relative filesystem import.

* Improve error messages when returning non-`Object` values from legacy
  importers.

## 1.49.11

* Add support for 64-bit ARM releases on Linux.

### Embedded Sass

* The embedded compiler now correctly sets the `id` field for all
  `OutboundMessage`s.

## 1.49.10

* Quiet deps mode now silences compiler warnings in mixins and functions that
  are defined in dependencies even if they're invoked from application
  stylesheets.

* In expanded mode, Sass will now emit colors using `rgb()`, `rbga()`, `hsl()`,
  and `hsla()` function notation if they were defined using the corresponding
  notation. As per our browser support policy, this change was only done once
  95% of browsers were confirmed to support this output format, and so is not
  considered a breaking change.

  Note that this output format is intended for human readability and not for
  interoperability with other tools. As always, Sass targets the CSS
  specification, and any tool that consumes Sass's output should parse all
  colors that are supported by the CSS spec.

* Fix a bug in which a color written using the four- or eight-digit hex format
  could be emitted as a hex color rather than a format with higher browser
  compatibility.

* Calculations are no longer simplified within supports declarations

## 1.49.9

### Embedded Sass

* Fixed a bug where the legacy API could crash when passed an empty importer
  list.

## 1.49.8

* Fixed a bug where some plain CSS imports would not be emitted.

### JS API

* Fix a bug where inspecting the Sass module in the Node.js console crashed on
  Node 17.

### Embedded Sass

* Fix a bug where source map URLs were incorrectly generated when passing
  importers to the legacy API.

## 1.49.7

### Embedded Sass

* First stable release the `sass-embedded` npm package that contains the Node.js
  Embedded Host.

* First stable release of the `sass_embedded` pub package that contains the
  Embedded Dart Sass compiler.

## 1.49.6

* No user-visible changes.

## 1.49.5

* No user-visible changes.

## 1.49.4

* No user-visible changes.

## 1.49.3

* No user-visible changes.

## 1.49.2

* No user-visible changes.

## 1.49.1

* Stop supporting non-LTS Node.js versions.

## 1.49.0

* Fix a bug in `string.insert` with certain negative indices.

### JS API

* Add support for the `sourceMapIncludeSources` option in the new JS API.

#### TypeScript Declarations

* Fix a bug where `LegacyPluginThis.options.linefeed` was typed to return
  abbreviations when it actually returned literal linefeed characters.

## 1.48.0

### JS API

* **Potentially breaking bug fix:** Match the specification of the new JS API by
  setting `LegacyResult.map` to `undefined` rather than `null`.

#### TypeScript Declarations

* Add a declaration for the `NULL` constant.

## 1.47.0

### JS API

#### TypeScript Declarations

* Add declarations for the `TRUE` and `FALSE` constants.

## 1.46.0

### JS API

* **Potentially breaking bug fix:** Match the specification of the new JS API by
  passing `undefined` rather than `null` to `Logger.warn()` for an unset `span`.

#### TypeScript Declarations

* Add a declaration for the `LegacyPluginThis.options.context` field.

* Update the definition of `LegacyAsyncFunction` to include explicit definitions
  with zero through six arguments before the `done` parameter. This makes it
  possible for TypeScript users to pass in callbacks that take a specific number
  of arguments, rather than having to declare a callback that takes an arbitrary
  number.

* Add a declaration for `types.Error`, a legacy API class that can be returned
  by asynchronous functions to signal asynchronous errors.

* Add a `LegacyAsyncFunctionDone` type for the `done` callback that's passed to
  `LegacyAsyncFunction`.

## 1.45.2

### JS API

* **Potentially breaking bug fix:** Change the default value of the `separator`
  parameter for `new SassArgumentList()` to `','` rather than `null`. This
  matches the API specification.

## 1.45.1

* **Potentially breaking bug fix:** Properly parse custom properties in
  `@supports` conditions. Note that this means that SassScript expressions on
  the right-hand side of custom property `@supports` queries now need to be
  interpolated, as per https://sass-lang.com/d/css-vars.

* **Potentially breaking bug fix:** Fix a bug where `inspect()` was not
  properly printing nested, empty, bracketed lists.

## 1.45.0

### JS API

This release includes an entirely new JavaScript API, designed to be more
idiomatic, performant, and usable. The old API will continue to be supported
until Dart Sass 2.0.0, but it is now considered deprecated and should be avoided
for new code.

The new API includes:

* `compile()` and `compileAsync()` functions that take Sass file paths and
  return the result of compiling them to CSS. The async function returns a
  `Promise` rather than using a callback-based API.

* `compileString()` and `compileStringAsync()` functions that take a string of
  Sass source and compiles it to CSS. As above, the async function returns a
  `Promise`.

* A new importer API that more closely matches the Sass specification's logic
  for resolving loads. This makes it much easier for Sass to cache information
  across `@import` and `@use` rules, which substantially improves performance
  for applications that rely heavily on repeated `@import`s.

* A new custom function API, including much more usable JS representations of
  Sass value types complete with type-assertion functions, easy map and list
  lookups, and compatibility with the [`immutable`] package. **Unlike in the
  legacy API,** function callbacks now take one argument which contains an array
  of Sass values (rather than taking a separate JS argument for each Sass
  argument).

[`immutable`]: https://immutable-js.com/

For full documentation of this API, please see [the Sass website][js-api].

[js-api]: https://sass-lang.com/documentation/js-api

This release also adds TypeScript type definitions.

## 1.44.0

* Suggest `calc()` as an alternative in `/`-as-division deprecation messages.

### Dart API

* Add `SassNumber.convert()` and `SassNumber.convertValue()`. These work like
  `SassNumber.coerce()` and `SassNumber.coerceValue()`, except they don't treat
  unitless numbers as universally compatible.

* Fix a bug where `SassNumber.coerceToMatch()` and
  `SassNumber.coerceValueToMatch()` wouldn't coerce single-unit numbers to
  match unitless numbers.

## 1.43.5

* Fix a bug where calculations with different operators were incorrectly
  considered equal.

* Properly parse attribute selectors with empty namespaces.

### JS API

* Print more detailed JS stack traces. This is mostly useful for the Sass team's
  own debugging purposes.

## 1.43.4

### JS API

* Fix a bug where the `logger` option was ignored for the `render()` function.

## 1.43.3

* Improve performance.

## 1.43.2

* Improve the error message when the default namespace of a `@use` rule is not
  a valid identifier.

## 1.43.1

* No user-visible changes.

## 1.43.0

### JS API

* Add support for the `logger` option. This takes an object that can define
  `warn` or `debug` methods to add custom handling for messages emitted by the
  Sass compiler. See [the JS API docs] for details.

  [the JS API docs]: https://sass-lang.com/documentation/js-api/interfaces/Logger

* Add a `Logger.silent` object that can be passed to the `logger` option to
  silence all messages from the Sass compiler.

## 1.42.1

* Fix a bug where Sass variables and function calls in calculations weren't
  being resolved correctly if there was a parenthesized interpolation elsewhere
  in the file.

## 1.42.0

* `min()` and `max()` expressions are once again parsed as calculations as long
  as they contain only syntax that's allowed in calculation expressions. To
  avoid the backwards-compatibility issues that were present in 1.40.0, they now
  allow unitless numbers to be mixed with numbers with units just like the
  global `min()` and `max()` functions. Similarly, `+` and `-` operations within
  `min()` and `max()` functions allow unitless numbers to be mixed with numbers
  with units.

## 1.41.1

* Preserve parentheses around `var()` functions in calculations, because they
  could potentially be replaced with sub-expressions that might need to be
  parenthesized.

## 1.41.0

* Calculation values can now be combined with strings using the `+` operator.
  This was an error in 1.40.0, but this broke stylesheets that were relying on
  `$value + ""` expressions to generically convert values to strings. (Note that
  the Sass team recommends the use of `"#{$value}"` or `inspect($value)` for
  that use-case.)

* The `selector.unify()` function now correctly returns `null` when one selector
  is a `:host` or `:host-context` and the other is a selector that's guaranteed
  to be within the current shadow DOM. The `@extend` logic has been updated
  accordingly as well.

* Fix a bug where extra whitespace in `min()`, `max()`, `clamp()`, and `calc()`
  expressions could cause bogus parse errors.

* Fix a bug where the right-hand operand of a `-` in a calculation could
  incorrectly be stripped of parentheses.

### Dart API

* `SassCalculation.plus()` now allows `SassString` arguments.

## 1.40.1

* **Potentially breaking bug fix:** `min()` and `max()` expressions outside of
  calculations now behave the same way they did in 1.39.2, returning unquoted
  strings if they contain no Sass-specific features and calling the global
  `min()` and `max()` functions otherwise. Within calculations, they continue to
  behave how they did in 1.40.0.

  This fixes an unintended breaking change added in 1.40.0, wherein passing a
  unitless number and a number without units to `min()` or `max()` now produces
  an error. Since this breakage affects a major Sass library, we're temporarily
  reverting support for `min()` and `max()` calculations while we work on
  designing a longer-term fix.

## 1.40.0

* Add support for first-class `calc()` expressions (as well as `clamp()` and
  plain-CSS `min()` and `max()`). This means:

  * `calc()` expressions will be parsed more thoroughly, and errors will be
    highlighted where they weren't before. **This may break your stylesheets,**
    but only if they were already producing broken CSS.

  * `calc()` expressions will be simplified where possible, and may even return
    numbers if they can be simplified away entirely.

  * `calc()` expressions that can't be simplified to numbers return a new data
    type known as "calculations".

  * Sass variables and functions can now be used in `calc()` expressions.

  * New functions `meta.calc-name()` and `meta.calc-args()` can now inspect
    calculations.

### Dart API

* Add a new value type, `SassCalculation`, that represents calculations.

* Add new `CalculationOperation`, `CalculationOperator`, and
  `CalculationInterpolation` types to represent types of arguments that may
  exist as part of a calculation.

* Add a new `Value.assertCalculation()` method.

* Add a new `Number.hasCompatibleUnits()` method.

## 1.39.2

* Fix a bug where configuring with `@use ... with` would throw an error when
  that variable was defined in a module that also contained `@forward ... with`.

## 1.39.1

* Partial fix for a bug where `@at-root` does not work properly in nested
  imports that contain `@use` rules. If the only `@use` rules in the nested
  import are for built-in modules, `@at-root` should now work properly.

## 1.39.0

### JS API

* Add a `charset` option that controls whether or not Sass emits a
  `@charset`/BOM for non-ASCII stylesheets.

## 1.38.2

* No user-visible changes

## 1.38.1

* No user-visible changes

## 1.38.0

* In expanded mode, emit characters in Unicode private-use areas as escape
  sequences rather than literal characters.

* Fix a bug where quotes would be omitted for an attribute selector whose value
  was a single backslash.

* Properly consider numbers that begin with `.` as "plain CSS" for the purposes
  of parsing plain-CSS `min()` and `max()` functions.

* Allow `if` to be used as an unquoted string.

* Properly parse backslash escapes within `url()` expressions.

* Fix a couple bugs where `@extend`s could be marked as unsatisfied when
  multiple identical `@extend`s extended selectors across `@use` rules.

### Command Line Interface

* Strip CRLF newlines from snippets of the original stylesheet that are included
  in the output when an error occurs.

### JS API

* Don't crash when a Windows path is returned by a custom Node importer at the
  same time as file contents.

* Don't crash when an error occurs in a stylesheet loaded via a custom importer
  with a custom URL scheme.

### Dart API

* Add a `SassArgumentList.keywordsWithoutMarking` getter to access the keyword
  arguments of an argument list without marking them accessed.

## 1.37.5

* No user-visible changes.

## 1.37.4

* No user-visible changes.

## 1.37.3

* No user-visible changes.

## 1.37.2

* No user-visible changes.

## 1.37.1

* No user-visible changes.

## 1.37.0

### Dart API

* **Potentially breaking bug fix:** `SassNumber.asSlash`,
  `SassNumber.withSlash()`, and `SassNumber.withoutSlash()` have been marked as
  `@internal`. They were never intended to be used outside the `sass` package.

* **Potentially breaking bug fix:** `SassException` has been marked as `@sealed`
  to formally indicate that it's not intended to be extended outside of the
  `sass` package.

* Add a `Value.withListContents()` method that returns a new Sass list with the
  same list separator and brackets as the current value, interpreted as a list.

## 1.36.0

### Dart API

* Added `compileToResult()`, `compileStringToResult()`,
  `compileToResultAsync()`, and `compileStringToResultAsync()` methods. These
  are intended to replace the existing `compile*()` methods, which are now
  deprecated. Rather than returning a simple string, these return a
  `CompileResult` object, which will allow us to add additional information
  about the compilation without having to introduce further deprecations.

  * Instead of passing a `sourceMaps` callback to `compile*()`, pass
    `sourceMaps: true` to `compile*ToResult()` and access
    `CompileResult.sourceMap`.

  * The `CompileResult` object exposes a `loadedUrls` object which lists the
    canonical URLs accessed during a compilation. This information was
    previously unavailable except through the JS API.

## 1.35.2

* **Potentially breaking bug fix**: Properly throw an error for Unicode ranges
  that have too many `?`s after hexadecimal digits, such as `U+12345??`.

* **Potentially breaking bug fix:** Fixed a bug where certain local variable
  declarations nested within multiple `@if` statements would incorrectly
  override a global variable. It's unlikely that any real stylesheets were
  relying on this bug, but if so they can simply add `!global` to the variable
  declaration to preserve the old behavior.

* **Potentially breaking bug fix:** Fix a bug where imports of root-relative
  URLs (those that begin with `/`) in `@import` rules would be passed to
  both Dart and JS importers as `file:` URLs.

* Properly support selector lists for the `$extendee` argument to
  `selector.extend()` and `selector.replace()`.

* Fix an edge case where `@extend` wouldn't affect a selector within a
  pseudo-selector such as `:is()` that itself extended other selectors.

* Fix a race condition where `meta.load-css()` could trigger an internal error
  when running in asynchronous mode.

### Dart API

* Use the `@internal` annotation to indicate which `Value` APIs are available
  for public use.

## 1.35.1

* Fix a bug where the quiet dependency flag didn't silence warnings in some
  stylesheets loaded using `@import`.

## 1.35.0

* Fix a couple bugs that could prevent some members from being found in certain
  files that use a mix of imports and the module system.

* Fix incorrect recommendation for migrating division expressions that reference
  namespaced variables.

### JS API

* Add a `quietDeps` option which silences compiler warnings from stylesheets
  loaded through importers and load paths.

* Add a `verbose` option which causes the compiler to emit all deprecation
  warnings, not just 5 per feature.

## 1.34.1

* Fix a bug where `--update` would always compile any file that depends on a
  built-in module.

* Fix the URL for the `@-moz-document` deprecation message.

* Fix a bug with `@for` loops nested inside property declarations.

## 1.34.0

* Don't emit the same warning in the same location multiple times.

* Cap deprecation warnings at 5 per feature by default.

### Command Line Interface

* Add a `--quiet-deps` flag which silences compiler warnings from stylesheets
  loaded through `--load-path`s.

* Add a `--verbose` flag which causes the compiler to emit all deprecation
  warnings, not just 5 per feature.

### Dart API

* Add a `quietDeps` argument to `compile()`, `compileString()`,
  `compileAsync()`, and `compileStringAsync()` which silences compiler warnings
  from stylesheets loaded through importers, load paths, and `package:` URLs.

* Add a `verbose` argument to `compile()`, `compileString()`, `compileAsync()`,
  and `compileStringAsync()` which causes the compiler to emit all deprecation
  warnings, not just 5 per feature.

## 1.33.0

* Deprecate the use of `/` for division. The new `math.div()` function should be
  used instead. See [this page][] for details.

[this page]: https://sass-lang.com/documentation/breaking-changes/slash-div

* Add a `list.slash()` function that returns a slash-separated list.

* **Potentially breaking bug fix:** The heuristics around when potentially
  slash-separated numbers are converted to slash-free numbers—for example, when
  `1/2` will be printed as `0.5` rather than `1/2`—have been slightly expanded.
  Previously, a number would be made slash-free if it was passed as an argument
  to a *user-defined function*, but not to a *built-in function*. Now it will be
  made slash-free in both cases. This is a behavioral change, but it's unlikely
  to affect any real-world stylesheets.

* [`:is()`][] now behaves identically to `:matches()`.

[`:is()`]: https://developer.mozilla.org/en-US/docs/Web/CSS/:is

* Fix a bug where non-integer numbers that were very close to integer
  values would be incorrectly formatted in CSS.

* Fix a bug where very small number and very large negative numbers would be
  incorrectly formatted in CSS.

### JS API

* The `this` context for importers now has a `fromImport` field, which is `true`
  if the importer is being invoked from an `@import` and `false` otherwise.
  Importers should only use this to determine whether to load [import-only
  files].

[import-only files]: https://sass-lang.com/documentation/at-rules/import#import-only-files

### Dart API

* Add an `Importer.fromImport` getter, which is `true` if the current
  `Importer.canonicalize()` call comes from an `@import` rule and `false`
  otherwise. Importers should only use this to determine whether to load
  [import-only files].

## 1.32.13

* **Potentially breaking bug fix:** Null values in `@use` and `@forward`
  configurations no longer override the `!default` variable, matching the
  behavior of the equivalent code using `@import`.

* Use the proper parameter names in error messages about `string.slice`

## 1.32.12

* Fix a bug that disallowed more than one module from extending the same
  selector from a module if that selector itself extended a selector from
  another upstream module.

## 1.32.11

* Fix a bug where bogus indented syntax errors were reported for lines that
  contained only whitespace.

## 1.32.10

* No user-visible changes.

## 1.32.9

* Fix a typo in a deprecation warning.

### JavaScript API

* Drop support for Chokidar 2.x. This version was incompatible with Node 14, but
  due to shortcomings in npm's version resolver sometimes still ended up
  installed anyway. Only declaring support for 3.0.0 should ensure compatibility
  going forward.

### Dart API

* Allow the null safety release of args and watcher.

### Command Line Interface

* Add a `-w` shorthand for the `--watch` flag.

## 1.32.8

* Update chokidar version for Node API tests.

### JavaScript API

* Allow a custom function to access the `render()` options object within its
  local context, as `this.options`.

## 1.32.7

* Allow the null safety release of stream_transform.

* Allow `@forward...with` to take arguments that have a `!default` flag without
  a trailing comma.

* Improve the performance of unitless and single-unit numbers.

## 1.32.6

### Node JS API

* Fix Electron support when `nodeIntegration` is disabled.

### Dart API

* All range checks for `SassColor` constructors now throw `RangeError`s with
  `start` and `end` set.

## 1.32.5

* **Potentially breaking bug fix:** When using `@for` with numbers that have
  units, the iteration variable now matches the unit of the initial number. This
  matches the behavior of Ruby Sass and LibSass.

### Node JS API

* Fix a few infrequent errors when calling `render()` with `fiber` multiple
  times simultaneously.

* Avoid possible mangled error messages when custom functions or importers throw
  unexpected exceptions.

* Fix Electron support when `nodeIntegration` is disabled.

## 1.32.4

* No user-visible changes.

## 1.32.3

* Optimize `==` for numbers that have different units.

## 1.32.2

* Print the actual number that was received in unit deprecation warnings for
  color functions.

## 1.32.1

* Don't emit permissions errors on Windows and OS X when trying to determine the
  real case of path names.

## 1.32.0

* Deprecate passing non-`%` numbers as lightness and saturation to `hsl()`,
  `hsla()`, `color.adjust()`, and `color.change()`. This matches the CSS
  specification, which also requires `%` for all lightness and saturation
  parameters. See [the Sass website][color-units] for more details.

* Deprecate passing numbers with units other than `deg` as the hue to `hsl()`,
  `hsla()`, `adjust-hue()`, `color.adjust()`, and `color.change()`. Unitless
  numbers *are* still allowed here, since they're allowed by CSS. See [the Sass
  website][color-units] for more details.

* Improve error messages about incompatible units.

* Properly mark some warnings emitted by `sass:color` functions as deprecation
  warnings.

### Dart API

* Rename `SassNumber.valueInUnits()` to `SassNumber.coerceValue()`. The old name
  remains, but is now deprecated.

* Rename `SassNumber.coerceValueToUnit()`, a shorthand for
  `SassNumber.coerceValue()` that takes a single numerator unit.

* Add `SassNumber.coerceToMatch()` and `SassNumber.coerceValueToMatch()`, which
  work like `SassNumber.coerce()` and `SassNumber.coerceValue()` but take a
  `SassNumber` whose units should be matched rather than taking the units
  explicitly. These generate better error messages than `SassNumber.coerce()`
  and `SassNumber.coerceValue()`.

* Add `SassNumber.convertToMatch()` and `SassNumber.convertValueToMatch()`,
  which work like `SassNumber.coerceToMatch()` and
  `SassNumber.coerceValueToMatch()` except they throw exceptions when converting
  unitless values to or from units.

* Add `SassNumber.compatibleWithUnit()`, which returns whether the number can be
  coerced to a single numerator unit.

## 1.31.0

* Add support for parsing `clamp()` as a special math function, the same way
  `calc()` is parsed.

* Properly load files in case-sensitive Windows directories with upper-case
  names.

## 1.30.0

* Fix a bug where `@at-root (without: all)` wouldn't properly remove a
  `@keyframes` context when parsing selectors.

### Node JS API

* The generated `main()` function in `sass.js` now returns a `Promise` that
  completes when the executable is finished running.

### Dart API

* Fix a bug that prevented importers from returning null when loading from a
  URL that they had already canonicalized.

## 1.29.0

* Support a broader syntax for `@supports` conditions, based on the latest
  [Editor's Draft of CSS Conditional Rules 3]. Almost all syntax will be allowed
  (with interpolation) in the conditions' parentheses, as well as function
  syntax such as `@supports selector(...)`.

[Editor's Draft of CSS Conditional Rules 3]: https://drafts.csswg.org/css-conditional-3/#at-supports

## 1.28.0

* Add a [`color.hwb()`] function to `sass:color` that can express colors in [HWB] format.

[`color.hwb()`]: https://sass-lang.com/documentation/modules/color#hwb
[HWB]: https://en.wikipedia.org/wiki/HWB_color_model

* Add [`color.whiteness()`] and [`color.blackness()`] functions to `sass:color`
  to get a color's [HWB] whiteness and blackness components.

[`color.whiteness()`]: https://sass-lang.com/documentation/modules/color#whiteness
[`color.blackness()`]: https://sass-lang.com/documentation/modules/color#blackness

* Add `$whiteness` and `$blackness` parameters to [`color.adjust()`],
  [`color.change()`], and [`color.scale()`] to modify a color's [HWB] whiteness
  and blackness components.

[`color.adjust()`]: https://sass-lang.com/documentation/modules/color#adjust
[`color.change()`]: https://sass-lang.com/documentation/modules/color#change
[`color.scale()`]: https://sass-lang.com/documentation/modules/color#scale

### Dart API

* Add [HWB] support to the `SassColor` class, including a `SassColor.hwb()`
  constructor, `whiteness` and `blackness` getters, and a `changeHwb()` method.

[HWB]: https://en.wikipedia.org/wiki/HWB_color_model

## 1.27.2

* No user-visible changes.

## 1.27.1

* **Potentially breaking bug fix:** `meta.load-css()` now correctly uses the
  name `$url` for its first argument, rather than `$module`.

* Don't crash when using `Infinity` or `NaN` as a key in a map.

* Emit a proper parse error for a `=` with no right-hand side in a function.

* Avoid going exponential on certain recursive `@extend` edge cases.

## 1.27.0

* Adds an overload to `map.merge()` that supports merging a nested map.

  `map.merge($map1, $keys..., $map2)`: The `$keys` form a path to the nested map
  in `$map1`, into which `$map2` gets merged.

  See [the Sass documentation][map-merge] for more details.

  [map-merge]: https://sass-lang.com/documentation/modules/map#merge

* Adds an overloaded `map.set()` function.

  `map.set($map, $key, $value)`: Adds to or updates `$map` with the specified
  `$key` and `$value`.

  `map.set($map, $keys..., $value)`: Adds to or updates a map that is nested
  within `$map`. The `$keys` form a path to the nested map in `$map`, into
  which `$value` is inserted.

  See [the Sass documentation][map-set] for more details.

  [map-set]: https://sass-lang.com/documentation/modules/map#set

* Add support for nested maps to `map.get()`.
  For example, `map.get((a: (b: (c: d))), a, b, c)` would return `d`.
  See [the documentation][map-get] for more details.

  [map-get]: https://sass-lang.com/documentation/modules/map#get

* Add support for nested maps in `map.has-key`.
  For example, `map.has-key((a: (b: (c: d))), a, b, c)` would return true.
  See [the documentation][map-has-key] for more details.

  [map-has-key]: https://sass-lang.com/documentation/modules/map#has-key

* Add a `map.deep-merge()` function. This works like `map.merge()`, except that
  nested map values are *also* recursively merged. For example:

  ```
  map.deep-merge(
    (color: (primary: red, secondary: blue),
    (color: (secondary: teal)
  ) // => (color: (primary: red, secondary: teal))
  ```

  See [the Sass documentation][map-deep-merge] for more details.

  [map-deep-merge]: https://sass-lang.com/documentation/modules/map#deep-merge

* Add a `map.deep-remove()` function. This allows you to remove keys from
  nested maps by passing multiple keys. For example:

  ```
  map.deep-remove(
    (color: (primary: red, secondary: blue)),
    color, primary
  ) // => (color: (secondary: blue))
  ```

  See [the Sass documentation][map-deep-remove] for more details.

  [map-deep-remove]: https://sass-lang.com/documentation/modules/map#deep-remove

* Fix a bug where custom property values in plain CSS were being parsed as
  normal property values.

### Dart API

* Add a `Value.tryMap()` function which returns the `Value` as a `SassMap` if
  it's a valid map, or `null` otherwise. This allows function authors to safely
  retrieve maps even if they're internally stored as empty lists, without having
  to catch exceptions from `Value.assertMap()`.

## 1.26.12

* Fix a bug where nesting properties beneath a Sass-syntax custom property
  (written as `#{--foo}: ...`) would crash.

## 1.26.11

* **Potentially breaking bug fix:** `selector.nest()` now throws an error
  if the first arguments contains the parent selector `&`.

* Fixes a parsing bug with inline comments in selectors.

* Improve some error messages for edge-case parse failures.

* Throw a proper error when the same built-in module is `@use`d twice.

* Don't crash when writing `Infinity` in JS mode.

* Produce a better error message for positional arguments following named
  arguments.

## 1.26.10

* Fixes a bug where two adjacent combinators could cause an error.

## 1.26.9

* Use an updated version of `node_preamble` when compiling to JS.

## 1.26.8

* Fixes an error when emitting source maps to stdout.

## 1.26.7

* No user-visible changes.

## 1.26.6

* Fix a bug where escape sequences were improperly recognized in `@else` rules.

### JavaScript API

* Add `sass.NULL`, `sass.TRUE`, and `sass.FALSE` constants to match Node Sass's
  API.

* If a custom Node importer returns both `file` and `contents`, don't attempt to
  read the `file`. Instead, use the `contents` provided by the importer, with
  `file` as the canonical url.

## 1.26.5

* No user-visible changes.

## 1.26.4

* Be more memory-efficient when handling `@forward`s through `@import`s.

## 1.26.3

* Fix a bug where `--watch` mode could go into an infinite loop compiling CSS
  files to themselves.

## 1.26.2

* More aggressively eliminate redundant selectors in the `selector.extend()` and
  `selector.replace()` functions.

## 1.26.1

### Command Line Interface

* Fix a longstanding bug where `--watch` mode could enter into a state where
  recompilation would not occur after a syntax error was introduced into a
  dependency and then fixed.

## 1.26.0

* **Potentially breaking bug fix:** `@use` rules whose URLs' basenames begin
  with `_` now correctly exclude that `_` from the rules' namespaces.

* Fix a bug where imported forwarded members weren't visible in mixins and
  functions that were defined before the `@import`.

* Don't throw errors if the exact same member is loaded or forwarded from
  multiple modules at the same time.

## 1.25.2

* Fix a bug where, under extremely rare circumstances, a valid variable could
  become unassigned.

## 1.25.0

* Add functions to the built-in "sass:math" module.

  * `clamp($min, $number, $max)`. Clamps `$number` in between `$min` and `$max`.

  * `hypot($numbers...)`. Given *n* numbers, outputs the length of the
    *n*-dimensional vector that has components equal to each of the inputs.

  * Exponential. All inputs must be unitless.
    * `log($number)` or `log($number, $base)`. If no base is provided, performs
       a natural log.
    * `pow($base, $exponent)`
    * `sqrt($number)`

  * Trigonometric. The input must be an angle. If no unit is given, the input is
    assumed to be in `rad`.
    * `cos($number)`
    * `sin($number)`
    * `tan($number)`

  * Inverse trigonometric. The output is in `deg`.
    * `acos($number)`. Input must be unitless.
    * `asin($number)`. Input must be unitless.
    * `atan($number)`. Input must be unitless.
    * `atan2($y, $x)`. `$y` and `$x` must have compatible units or be unitless.

* Add the variables `$pi` and `$e` to the built-in "sass:math" module.

### JavaScript API

* `constructor.value` fields on value objects now match their Node Sass
  equivalents.

## 1.24.5

* Highlight contextually-relevant sections of the stylesheet in error messages,
  rather than only highlighting the section where the error was detected.

## 1.24.4

### JavaScript API

* Fix a bug where source map generation would crash with an absolute source map
  path and a custom importer that returns string file contents.

## 1.24.3

### Command Line Interface

* Fix a bug where `sass --version` would crash for certain executable
  distributions.

## 1.24.2

### JavaScript API

* Fix a bug introduced in the previous release that prevented custom importers
  in Node.js from loading import-only files.

## 1.24.1

* Fix a bug where the wrong file could be loaded when the same URL is used by
  both a `@use` rule and an `@import` rule.

## 1.24.0

* Add an optional `with` clause to the `@forward` rule. This works like the
  `@use` rule's `with` clause, except that `@forward ... with` can declare
  variables as `!default` to allow downstream modules to reconfigure their
  values.

* Support configuring modules through `@import` rules.

## 1.23.8

* **Potentially breaking bug fix:** Members loaded through a nested `@import`
  are no longer ever accessible outside that nested context.

* Don't throw an error when importing two modules that both forward members with
  the same name. The latter name now takes precedence over the former, as per
  the specification.

### Dart API

* `SassFormatException` now implements `SourceSpanFormatException` (and thus
  `FormatException`).

## 1.23.7

* No user-visible changes

## 1.23.6

* No user-visible changes.

## 1.23.5

* Support inline comments in the indented syntax.

* When an overloaded function receives the wrong number of arguments, guess
  which overload the user actually meant to invoke, and display the invalid
  argument error for that overload.

* When `@error` is used in a function or mixin, print the call site rather than
  the location of the `@error` itself to better match the behavior of calling a
  built-in function that throws an error.

## 1.23.4

### Command-Line Interface

* Fix a bug where `--watch` wouldn't watch files referred to by `@forward`
  rules.

## 1.23.3

* Fix a bug where selectors were being trimmed over-eagerly when `@extend`
  crossed module boundaries.

## 1.23.2

### Command-Line Interface

* Fix a bug when compiling all Sass files in a directory where a CSS file could
  be compiled to its own location, creating an infinite loop in `--watch` mode.

* Properly compile CSS entrypoints in directories outside of `--watch` mode.

## 1.23.1

* Fix a bug preventing built-in modules from being loaded within a configured
  module.

* Fix a bug preventing an unconfigured module from being loaded from within two
  different configured modules.

* Fix a bug when `meta.load-css()` was used to load some files that included
  media queries.

* Allow `saturate()` in plain CSS files, since it can be used as a plain CSS
  filter function.

* Improve the error messages for trying to access functions like `lighten()`
  from the `sass:color` module.

## 1.23.0

* **Launch the new Sass module system!** This adds:

  * The [`@use` rule][], which loads Sass files as *modules* and makes their
    members available only in the current file, with automatic namespacing.

    [`@use` rule]: https://sass-lang.com/documentation/at-rules/use

  * The [`@forward` rule][], which makes members of another Sass file available
    to stylesheets that `@use` the current file.

    [`@forward` rule]: https://sass-lang.com/documentation/at-rules/forward

  * Built-in modules named `sass:color`, `sass:list`, `sass:map`, `sass:math`,
    `sass:meta`, `sass:selector`, and `sass:string` that provide access to all
    the built-in Sass functions you know and love, with automatic module
    namespaces.

  * The [`meta.load-css()` mixin][], which includes the CSS contents of a module
    loaded from a (potentially dynamic) URL.

    [`meta.load-css()` mixin]: https://sass-lang.com/documentation/modules/meta#load-css

  * The [`meta.module-variables()` function][], which provides access to the
    variables defined in a given module.

    [`meta.module-variables()` function]: https://sass-lang.com/documentation/modules/meta#module-variables

  * The [`meta.module-functions()` function][], which provides access to the
    functions defined in a given module.

    [`meta.module-functions()` function]: https://sass-lang.com/documentation/modules/meta#module-functions

  Check out [the Sass blog][migrator blog] for more information on the new
  module system. You can also use the new [Sass migrator][] to automatically
  migrate your stylesheets to the new module system!

  [migrator blog]: https://sass-lang.com/blog/the-module-system-is-launched
  [Sass migrator]: https://sass-lang.com/documentation/cli/migrator

## 1.22.12

* **Potentially breaking bug fix:** character sequences consisting of two or
  more hyphens followed by a number (such as `--123`), or two or more hyphens on
  their own (such as `--`), are now parsed as identifiers [in accordance with
  the CSS spec][ident-token-diagram].

  [ident-token-diagram]: https://drafts.csswg.org/css-syntax-3/#ident-token-diagram

  The sequence `--` was previously parsed as multiple applications of the `-`
  operator. Since this is unlikely to be used intentionally in practice, we
  consider this bug fix safe.

### Command-Line Interface

* Fix a bug where changes in `.css` files would be ignored in `--watch` mode.

### JavaScript API

* Allow underscore-separated custom functions to be defined.

* Improve the performance of Node.js compilation involving many `@import`s.

## 1.22.11

* Don't try to load unquoted plain-CSS indented-syntax imports.

* Fix a couple edge cases in `@extend` logic and related selector functions:

  * Recognize `:matches()` and similar pseudo-selectors as superselectors of
    matching complex selectors.

  * Recognize `::slotted()` as a superselector of other `::slotted()` selectors.

  * Recognize `:current()` with a vendor prefix as a superselector.

## 1.22.10

* Fix a bug in which `get-function()` would fail to find a dash-separated
  function when passed a function name with underscores.

## 1.22.9

* Include argument names when reporting range errors and selector parse errors.

* Avoid double `Error:` headers when reporting selector parse errors.

* Clarify the error message when the wrong number of positional arguments are
  passed along with a named argument.

### JavaScript API

* Re-add support for Node Carbon (8.x).

## 1.22.8

### JavaScript API

* Don't crash when running in a directory whose name contains URL-sensitive
  characters.

* Drop support for Node Carbon (8.x), which doesn't support `url.pathToFileURL`.

## 1.22.7

* Restrict the supported versions of the Dart SDK to `^2.4.0`.

## 1.22.6

* **Potentially breaking bug fix:** The `keywords()` function now converts
  underscore-separated argument names to hyphen-separated names. This matches
  LibSass's behavior, but not Ruby Sass's.

* Further improve performance for logic-heavy stylesheets.

* Improve a few error messages.

## 1.22.5

### JavaScript API

* Improve performance for logic-heavy stylesheets.

## 1.22.4

* Fix a bug where at-rules imported from within a style rule would appear within
  that style rule rather than at the root of the document.

## 1.22.3

* **Potentially breaking bug fix:** The argument name for the `saturate()`
  function is now `$amount`, to match the name in LibSass and originally in Ruby
  Sass.

* **Potentially breaking bug fix:** The `invert()` function now properly returns
  `#808080` when passed `$weight: 50%`. This matches the behavior in LibSass and
  originally in Ruby Sass, as well as being consistent with other nearby values
  of `$weight`.

* **Potentially breaking bug fix:** The `invert()` function now throws an error
  if it's used [as a plain CSS function][plain-CSS invert] *and* the Sass-only
  `$weight` parameter is passed. This never did anything useful, so it's
  considered a bug fix rather than a full breaking change.

  [plain-CSS invert]: https://developer.mozilla.org/en-US/docs/Web/CSS/filter-function/invert

* **Potentially breaking bug fix**: The `str-insert()` function now properly
  inserts at the end of the string if the `$index` is `-1`. This matches the
  behavior in LibSass and originally in Ruby Sass.

* **Potentially breaking bug fix**: An empty map returned by `map-remove()` is
  now treated as identical to the literal value `()`, rather than being treated
  as though it had a comma separator. This matches the original behavior in Ruby
  Sass.

* The `adjust-color()` function no longer throws an error when a large `$alpha`
  value is combined with HSL adjustments.

* The `alpha()` function now produces clearer error messages when the wrong
  number of arguments are passed.

* Fix a bug where the `str-slice()` function could produce invalid output when
  passed a string that contains characters that aren't represented as a single
  byte in UTF-16.

* Improve the error message for an unknown separator name passed to the `join()`
  or `append()` functions.

* The `zip()` function no longer deadlocks if passed no arguments.

* The `map-remove()` function can now take a `$key` named argument. This matches
  the signature in LibSass and originally in Ruby Sass.

## 1.22.2

### JavaScript API

* Avoid re-assigning the `require()` function to make the code statically
  analyzable by Webpack.

## 1.22.1

### JavaScript API

* Expand the dependency on `chokidar` to allow 3.x.

## 1.22.0

* Produce better stack traces when importing a file that contains a syntax
  error.

* Make deprecation warnings for `!global` variable declarations that create new
  variables clearer, especially in the case where the `!global` flag is
  unnecessary because the variables are at the top level of the stylesheet.

### Dart API

* Add a `Value.realNull` getter, which returns Dart's `null` if the value is
  Sass's null.

## 1.21.0

### Dart API

* Add a `sass` executable when installing the package through `pub`.

* Add a top-level `warn()` function for custom functions and importers to print
  warning messages.

## 1.20.3

* No user-visible changes.

## 1.20.2

* Fix a bug where numbers could be written using exponential notation in
  Node.js.

* Fix a crash that would appear when writing some very large integers to CSS.

### Command-Line Interface

* Improve performance for stand-alone packages on Linux and Mac OS.

### JavaScript API

* Pass imports to custom importers before resolving them using `includePaths` or
  the `SASS_PATH` environment variable. This matches Node Sass's behavior, so
  it's considered a bug fix.

## 1.20.1

* No user-visible changes.

## 1.20.0

* Support attribute selector modifiers, such as the `i` in `[title="test" i]`.

### Command-Line Interface

* When compilation fails, Sass will now write the error message to the CSS
  output as a comment and as the `content` property of a `body::before` rule so
  it will show up in the browser (unless compiling to standard output). This can
  be disabled with the `--no-error-css` flag, or forced even when compiling to
  standard output with the `--error-css` flag.

### Dart API

* Added `SassException.toCssString()`, which returns the contents of a CSS
  stylesheet describing the error, as above.

## 1.19.0

* Allow `!` in `url()`s without quotes.

### Dart API

* `FilesystemImporter` now doesn't change its effective directory if the working
  directory changes, even if it's passed a relative argument.

## 1.18.0

* Avoid recursively listing directories when finding the canonical name of a
  file on case-insensitive filesystems.

* Fix importing files relative to `package:`-imported files.

* Don't claim that "package:" URLs aren't supported when they actually are.

### Command-Line Interface

* Add a `--no-charset` flag. If this flag is set, Sass will never emit a
  `@charset` declaration or a byte-order mark, even if the CSS file contains
  non-ASCII characters.

### Dart API

* Add a `charset` option to `compile()`, `compileString()`, `compileAsync()` and
  `compileStringAsync()`. If this option is set to `false`, Sass will never emit
  a `@charset` declaration or a byte-order mark, even if the CSS file contains
  non-ASCII characters.

* Explicitly require that importers' `canonicalize()` methods be able to take
  paths relative to their outputs as valid inputs. This isn't considered a
  breaking change because the importer infrastructure already required this in
  practice.

## 1.17.4

* Consistently parse U+000C FORM FEED, U+000D CARRIAGE RETURN, and sequences of
  U+000D CARRIAGE RETURN followed by U+000A LINE FEED as individual newlines.

### JavaScript API

* Add a `sass.types.Error` constructor as an alias for `Error`. This makes our
  custom function API compatible with Node Sass's.

## 1.17.3

* Fix an edge case where slash-separated numbers were written to the stylesheet
  with a slash even when they're used as part of another arithmetic operation,
  such as being concatenated with a string.

* Don't put style rules inside empty `@keyframes` selectors.

## 1.17.2

* Deprecate `!global` variable assignments to variables that aren't yet defined.
  This deprecation message can be avoided by assigning variables to `null` at
  the top level before globally assigning values to them.

### Dart API

* Explicitly mark classes that were never intended to be subclassed or
  implemented as "sealed".

## 1.17.1

* Properly quote attribute selector values that start with identifiers but end
  with a non-identifier character.

## 1.17.0

* Improve error output, particularly for errors that cover multiple lines.

* Improve source locations for some parse errors. Rather than pointing to the
  next token that wasn't what was expected, they point *after* the previous
  token. This should generally provide more context for the syntax error.

* Produce a better error message for style rules that are missing the closing
  `}`.

* Produce a better error message for style rules and property declarations
  within `@function` rules.

### Command-Line Interface

* Passing a directory on the command line now compiles all Sass source files in
  the directory to CSS files in the same directory, as though `dir:dir` were
  passed instead of just `dir`.

* The new error output uses non-ASCII Unicode characters by default. Add a
  `--no-unicode` flag to disable this.

## 1.16.1

* Fix a performance bug where stylesheet evaluation could take a very long time
  when many binary operators were used in sequence.

## 1.16.0

* `rgb()` and `hsl()` now treat unquoted strings beginning with `env()`,
  `min()`, and `max()` as special number strings like `calc()`.

## 1.15.3

* Properly merge `all and` media queries. These queries were previously being
  merged as though `all` referred to a specific media type, rather than all
  media types.

* Never remove units from 0 values in compressed mode. This wasn't safe in
  general, since some properties (such as `line-height`) interpret `0` as a
  `<number>` rather than a `<length>` which can break CSS transforms. It's
  better to do this optimization in a dedicated compressor that's aware of CSS
  property semantics.

* Match Ruby Sass's behavior in some edge-cases involving numbers with many
  significant digits.

* Emit escaped tab characters in identifiers as `\9` rather than a backslash
  followed by a literal tab.

### Command-Line Interface

* The source map generated for a stylesheet read from standard input now uses a
  `data:` URL to include that stylesheet's contents in the source map.

### Node JS API

* `this.includePaths` for a running importer is now a `;`-separated string on
  Windows, rather than `:`-separated. This matches Node Sass's behavior.

### Dart API

* The URL used in a source map to refer to a stylesheet loaded from an importer
  is now `ImportResult.sourceMapUrl` as documented.

## 1.15.2

### Node JS API

* When `setValue()` is called on a Sass string object, make it unquoted even if
  it was quoted originally, to match the behavior of Node Sass.

## 1.15.1

* Always add quotes to attribute selector values that begin with `--`, since IE
  11 doesn't consider them to be identifiers.

## 1.15.0

* Add support for passing arguments to `@content` blocks. See [the
  proposal][content-args] for details.

* Add support for the new `rgb()` and `hsl()` syntax introduced in CSS Colors
  Level 4, such as `rgb(0% 100% 0% / 0.5)`. See [the proposal][color-4-rgb-hsl]
  for more details.

* Add support for interpolation in at-rule names. See [the
  proposal][at-rule-interpolation] for details.

* Add paths from the `SASS_PATH` environment variable to the load paths in the
  command-line interface, Dart API, and JS API. These load paths are checked
  just after the load paths explicitly passed by the user.

* Allow saturation and lightness values outside of the `0%` to `100%` range in
  the `hsl()` and `hsla()` functions. They're now clamped to be within that
  range rather than producing an error if they're outside it.

* Properly compile selectors that end in escaped whitespace.

[content-args]: https://github.com/sass/language/blob/master/accepted/content-args.md
[color-4-rgb-hsl]: https://github.com/sass/language/blob/master/accepted/color-4-rgb-hsl.md
[at-rule-interpolation]: https://github.com/sass/language/blob/master/accepted/at-rule-interpolation.md

### JavaScript API

* Always include the error location in error messages.

## 1.14.4

* Properly escape U+0009 CHARACTER TABULATION in unquoted strings.

## 1.14.3

* Treat `:before`, `:after`, `:first-line`, and `:first-letter` as
  pseudo-elements for the purposes of `@extend`.

* When running in compressed mode, remove spaces around combinators in complex
  selectors, so a selector like `a > b` is output as `a>b`.

* Properly indicate the source span for errors involving binary operation
  expressions whose operands are parenthesized.

## 1.14.2

* Fix a bug where loading the same stylesheet from two different import paths
  could cause its imports to fail to resolve.

* Properly escape U+001F INFORMATION SEPARATOR ONE in unquoted strings.

### Command-Line Interface

* Don't crash when using `@debug` in a stylesheet passed on standard input.

### Dart API

* `AsyncImporter.canonicalize()` and `Importer.canonicalize()` must now return
  absolute URLs. Relative URLs are still supported, but are deprecated and will
  be removed in a future release.

## 1.14.1

* Canonicalize escaped digits at the beginning of identifiers as hex escapes.

* Properly parse property declarations that are both *in* content blocks and
  written *after* content blocks.

### Command-Line Interface

* Print more readable paths in `--watch` mode.

## 1.14.0

### BREAKING CHANGE

In accordance with our [compatibility policy][], breaking changes made for CSS
compatibility reasons are released as minor version revision after a three-month
deprecation period.

[compatibility policy]: README.md#compatibility-policy

* Tokens such as `#abcd` that are now interpreted as hex colors with alpha
  channels, rather than unquoted ID strings.

## 1.13.4

### Node JS

* Tweak JS compilation options to substantially improve performance.

## 1.13.3

* Properly generate source maps for stylesheets that emit `@charset`
  declarations.

### Command-Line Interface

* Don't error out when passing `--embed-source-maps` along with
  `--embed-sources` for stylesheets that contain non-ASCII characters.

## 1.13.2

* Properly parse `:nth-child()` and `:nth-last-child()` selectors with
  whitespace around the argument.

* Don't emit extra whitespace in the arguments for `:nth-child()` and
  `:nth-last-child()` selectors.

* Fix support for CSS hacks in plain CSS mode.

## 1.13.1

* Allow an IE-style single equals operator in plain CSS imports.

## 1.13.0

* Allow `@extend` to be used with multiple comma-separated simple selectors.
  This is already supported by other implementations, but fell through the
  cracks for Dart Sass until now.

* Don't crash when a media rule contains another media rule followed by a style
  rule.

## 1.12.0

### Dart API

* Add a `SassException` type that provides information about Sass compilation
  failures.

### Node JS API

* Remove the source map comment from the compiled JS. We don't ship with the
  source map, so this pointed to nothing.

## 1.11.0

* Add support for importing plain CSS files. They can only be imported *without*
  an extension—for example, `@import "style"` will import `style.css`. Plain CSS
  files imported this way only support standard CSS features, not Sass
  extensions.

  See [the proposal][css-import] for details.

* Add support for CSS's `min()` and `max()` [math functions][]. A `min()` and
  `max()` call will continue to be parsed as a Sass function if it involves any
  Sass-specific features like variables or function calls, but if it's valid
  plain CSS (optionally with interpolation) it will be emitted as plain CSS instead.

  See [the proposal][css-min-max] for details.

* Add support for range-format media features like `(10px < width < 100px)`. See
  [the proposal][media-ranges] for details.

* Normalize escape codes in identifiers so that, for example, `éclair` and
  `\E9clair` are parsed to the same value. See
  [the proposal][identifier-escapes] for details.

* Don't choke on a [byte-order mark][] at the beginning of a document when
  running in JavaScript.

[math functions]: https://drafts.csswg.org/css-values/#math-function
[css-import]: https://github.com/sass/language/blob/master/accepted/css-imports.md
[css-min-max]: https://github.com/sass/language/blob/master/accepted/min-max.md
[media-ranges]: https://github.com/sass/language/blob/master/accepted/media-ranges.md
[identifier-escapes]: https://github.com/sass/language/blob/master/accepted/identifier-escapes.md
[byte-order mark]: https://en.wikipedia.org/wiki/Byte_order_mark

### Command-Line Interface

* The `--watch` command now continues to recompile a file after a syntax error
  has been detected.

### Dart API

* Added a `Syntax` enum to indicate syntaxes for Sass source files.

* The `compile()` and `compileAsync()` functions now parse files with the `.css`
  extension as plain CSS.

* Added a `syntax` parameter to `compileString()` and `compileStringAsync()`.

* Deprecated the `indented` parameter to `compileString()` and `compileStringAsync()`.

* Added a `syntax` parameter to `new ImporterResult()` and a
  `ImporterResult.syntax` getter to set the syntax of the source file.

* Deprecated the `indented` parameter to `new ImporterResult()` and the
  `ImporterResult.indented` getter in favor of `syntax`.

## 1.10.4

### Command-Line Interface

* Fix a Homebrew installation failure.

## 1.10.3

### Command-Line Interface

* Run the Chocolatey script with the correct arguments so it doesn't crash.

## 1.10.2

* No user-visible changes.

## 1.10.1

### Node JS API

* Don't crash when passing both `includePaths` and `importer`.

## 1.10.0

* When two `@media` rules' queries can't be merged, leave nested rules in place
  for browsers that support them.

* Fix a typo in an error message.

## 1.9.2

### Node JS API

* Produce more readable filesystem errors, such as when a file doesn't exist.

## 1.9.1

### Command-Line Interface

* Don't emit ANSI codes to Windows terminals that don't support them.

* Fix a bug where `--watch` crashed on Mac OS.

## 1.9.0

### Node API

* Add support for `new sass.types.Color(argb)` for creating colors from ARGB hex
  numbers. This was overlooked when initially adding support for Node Sass's
  JavaScript API.

## 1.8.0

### Command-Line Interface

* Add a `--poll` flag to make `--watch` mode repeatedly check the filesystem for
  updates rather than relying on native filesystem notifications.

* Add a `--stop-on-error` flag to stop compiling additional files once an error
  is encountered.

## 1.7.3

* No user-visible changes.

## 1.7.2

* Add a deprecation warning for `@-moz-document`, except for cases where only an
  empty `url-prefix()` is used. Support is [being removed from Firefox][] and
  will eventually be removed from Sass as well.

[being removed from Firefox]: https://www.fxsitecompat.com/en-CA/docs/2018/moz-document-support-has-been-dropped-except-for-empty-url-prefix/

* Fix a bug where `@-moz-document` functions with string arguments weren't being
  parsed.

### Command-Line Interface

* Don't crash when a syntax error is added to a watched file.

## 1.7.1

* Fix crashes in released binaries.

## 1.7.0

* Emit deprecation warnings for tokens such as `#abcd` that are ambiguous
  between ID strings and hex colors with alpha channels. These will be
  interpreted as colors in a release on or after 19 September 2018.

* Parse unambiguous hex colors with alpha channels as colors.

* Fix a bug where relative imports from files on the load path could look in the
  incorrect location.

## 1.6.2

### Command-Line Interface

* Fix a bug where the source map comment in the generated CSS could refer to the
  source map file using an incorrect URL.

## 1.6.1

* No user-visible changes.

## 1.6.0

* Produce better errors when expected tokens are missing before a closing brace.

* Avoid crashing when compiling a non-partial stylesheet that exists on the
  filesystem next to a partial with the same name.

### Command-Line Interface

* Add support for the `--watch`, which watches for changes in Sass files on the
  filesystem and ensures that the compiled CSS is up-to-date.

* When using `--update`, surface errors when an import doesn't exist even if the
  file containing the import hasn't been modified.

* When compilation fails, delete the output file rather than leaving an outdated
  version.

## 1.5.1

* Fix a bug where an absolute Windows path would be considered an `input:output`
  pair.

* Forbid custom properties that have no values, like `--foo:;`, since they're
  forbidden by the CSS spec.

## 1.5.0

* Fix a bug where an importer would be passed an incorrectly-resolved URL when
  handling a relative import.

* Throw an error when an import is ambiguous due to a partial and a non-partial
  with the same name, or multiple files with different extensions. This matches
  the standard Sass behavior.

### Command-Line Interface

* Add an `--interactive` flag that supports interactively running Sass
  expressions (thanks to [Jen Thakar][]!).

[Jen Thakar]: https://github.com/jathak

## 1.4.0

* Improve the error message for invalid semicolons in the indented syntax.

* Properly disallow semicolons after declarations in the indented syntax.

### Command-Line Interface

* Add support for compiling multiple files at once by writing
  `sass input.scss:output.css`. Note that unlike Ruby Sass, this *always*
  compiles files by default regardless of when they were modified.

  This syntax also supports compiling entire directories at once. For example,
  `sass templates/stylesheets:public/css` compiles all non-partial Sass files
  in `templates/stylesheets` to CSS files in `public/css`.

* Add an `--update` flag that tells Sass to compile only stylesheets that have
  been (transitively) modified since the CSS file was generated.

### Dart API

* Add `Importer.modificationTime()` and `AsyncImporter.modificationTime()` which
  report the last time a stylesheet was modified.

### Node API

* Generate source maps when the `sourceMaps` option is set to a string and the
  `outFile` option is not set.

## 1.3.2

* Add support for `@elseif` as an alias of `@else if`. This is not an
  intentional feature, so using it will cause a deprecation warning. It will be
  removed at some point in the future.

## 1.3.1

### Node API

* Fix loading imports relative to stylesheets that were themselves imported
  though relative include paths.

## 1.3.0

### Command-Line Interface

* Generate source map files by default when writing to disk. This can be
  disabled by passing `--no-source-map`.

* Add a `--source-map-urls` option to control whether the source file URLs in
  the generated source map are relative or absolute.

* Add an `--embed-sources` option to embed the contents of all source files in
  the generated source map.

* Add an `--embed-source-map` option to embed the generated source map as a
  `data:` URL in the generated CSS.

### Dart API

* Add a `sourceMap` parameter to `compile()`, `compileString()`,
  `compileAsync()`, and `compileStringAsync()`. This takes a callback that's
  called with a [`SingleMapping`][] that contains the source map information for
  the compiled CSS file.

[`SingleMapping`]: https://www.dartdocs.org/documentation/source_maps/latest/source_maps.parser/SingleMapping-class.html

### Node API

* Added support for the `sourceMap`, `omitSourceMapUrl`, `outFile`,
  `sourceMapContents`, `sourceMapEmbed`, and `sourceMapRoot` options to
  `render()` and `renderSync()`.

* Fix a bug where passing a relative path to `render()` or `renderSync()` would
  cause relative imports to break.

* Fix a crash when printing warnings in stylesheets compiled using `render()` or
  `renderSync()`.

* Fix a bug where format errors were reported badly on Windows.

## 1.2.1

* Always emit units in compressed mode for `0` dimensions other than lengths and
  angles.

## 1.2.0

* The command-line executable will now create the directory for the resulting
  CSS if that directory doesn't exist.

* Properly parse `#{$var} -#{$var}` as two separate values in a list rather than
  one value being subtracted from another.

* Improve the error message for extending compound selectors.

## 1.1.1

* Add a commit that was accidentally left out of 1.1.0.

## 1.1.0

* The command-line executable can now be used to write an output file to disk
  using `sass input.scss output.css`.

* Use a POSIX-shell-compatible means of finding the location of the `sass` shell
  script.

## 1.0.0

**Initial stable release.**

### Changes Since 1.0.0-rc.1

* Allow `!` in custom property values ([#260][]).

[#260]: https://github.com/sass/dart-sass/issues/260

#### Dart API

* Remove the deprecated `render()` function.

#### Node API

* Errors are now subtypes of the `Error` type.

* Allow both the `data` and `file` options to be passed to `render()` and
  `renderSync()` at once. The `data` option will be used as the contents of the
  stylesheet, and the `file` option will be used as the path for error reporting
  and relative imports. This matches Node Sass's behavior.

## 1.0.0-rc.1

* Add support for importing an `_index.scss` or `_index.sass` file when
  importing a directory.

* Add a `--load-path` command-line option (alias `-I`) for passing additional
  paths to search for Sass files to import.

* Add a `--quiet` command-line option (alias `-q`) for silencing warnings.

* Add an `--indented` command-line option for using the indented syntax with a
  stylesheet from standard input.

* Don't merge the media queries `not type` and `(feature)`. We had previously
  been generating `not type and (feature)`, but that's not actually the
  intersection of the two queries.

* Don't crash on `$x % 0`.

* The standalone executable distributed on GitHub is now named `sass` rather
  than `dart-sass`. The `dart-sass` executable will remain, with a deprecation
  message, until 1.0.0 is released.

### Dart API

* Add a `Logger` class that allows users to control how messages are printed by
  stylesheets.

* Add a `logger` parameter to `compile()`, `compileAsync()`, `compileString()`,
  and `compileStringAsync()`.

### Node JS API

* Import URLs passed to importers are no longer normalized. For example, if a
  stylesheet contains `@import "./foo.scss"`, importers will now receive
  `"./foo.scss"` rather than `"foo.scss"`.

## 1.0.0-beta.5.3

* Support hard tabs in the indented syntax.

* Improve the formatting of comments that don't start on the same line as the
  opening `/*`.

* Preserve whitespace after `and` in media queries in compressed mode.

### Indented Syntax

* Properly parse multi-line selectors.

* Don't deadlock on `/*` comments.

* Don't add an extra `*/` to comments that already have it.

* Preserve empty lines in `/*` comments.

## 1.0.0-beta.5.2

* Fix a bug where some colors would crash `compressed` mode.

## 1.0.0-beta.5.1

* Add a `compressed` output style.

* Emit a warning when `&&` is used, since it's probably not what the user means.

* `round()` now returns the correct results for negative numbers that should
  round down.

* `var()` may now be passed in place of multiple arguments to `rgb()`, `rgba()`,
  `hsl()` and `hsla()`.

* Fix some cases where equivalent numbers wouldn't count as the same keys in
  maps.

* Fix a bug where multiplication like `(1/1px) * (1px/1)` wouldn't properly
  cancel out units.

* Fix a bug where dividing by a compatible unit would produce an invalid
  result.

* Remove a non-`sh`-compatible idiom from the standalone shell script.

### Dart API

* Add a `functions` parameter to `compile()`, `compleString()`,
  `compileAsync()`, and `compileStringAsync()`. This allows users to define
  custom functions in Dart that can be invoked from Sass stylesheets.

* Expose the `Callable` and `AsyncCallable` types, which represent functions
  that can be invoked from Sass.

* Expose the `Value` type and its subclasses, as well as the top-level
  `sassTrue`, `sassFalse`, and `sassNull` values, which represent Sass values
  that may be passed into or returned from custom functions.

* Expose the `OutputStyle` enum, and add a `style` parameter to `compile()`,
  `compleString()`, `compileAsync()`, and `compileStringAsync()` that allows
  users to control the output style.

### Node JS API

* Support the `functions` option.

* Support the `"compressed"` value for the `outputStyle` option.

## 1.0.0-beta.4

* Support unquoted imports in the indented syntax.

* Fix a crash when `:not(...)` extends a selector that appears in
  `:not(:not(...))`.

### Node JS API

* Add support for asynchronous importers to `render()` and `renderSync()`.

### Dart API

* Add `compileAsync()` and `compileStringAsync()` methods. These run
  asynchronously, which allows them to take asynchronous importers (see below).

* Add an `AsyncImporter` class. This allows imports to be resolved
  asynchronously in case no synchronous APIs are available. `AsyncImporter`s are
  only compatible with `compileAysnc()` and `compileStringAsync()`.

## 1.0.0-beta.3

* Properly parse numbers with exponents.

* Don't crash when evaluating CSS variables whose names are entirely
  interpolated (for example, `#{--foo}: ...`).

### Node JS API

* Add support for the `importer` option to `render()` and `renderSync()`.
  Only synchronous importers are currently supported.

### Dart API

* Added an `Importer` class. This can be extended by users to provide support
  for custom resolution for `@import` rules.

* Added built-in `FilesystemImporter` and `PackageImporter` implementations that
  support resolving `file:` and `package:` URLs, respectively.

* Added an `importers` argument to the `compile()` and `compileString()`
  functions that provides `Importer`s to use when resolving `@import` rules.

* Added a `loadPaths` argument to the `compile()` and `compileString()`
  functions that provides paths to search for stylesheets when resolving
  `@import` rules. This is a shorthand for passing `FilesystemImporter`s to the
  `importers` argument.

## 1.0.0-beta.2

* Add support for the `::slotted()` pseudo-element.

* Generated transparent colors will now be emitted as `rgba(0, 0, 0, 0)` rather
  than `transparent`. This works around a bug wherein IE incorrectly handles the
  latter format.

### Command-Line Interface

* Improve the logic for whether to use terminal colors by default.

### Node JS API

* Add support for `data`, `includePaths`, `indentedSyntax`, `lineFeed`,
  `indentWidth`, and `indentType` options to `render()` and `renderSync()`.

* The result object returned by `render()` and `renderSync()` now includes the
  `stats` object which provides metadata about the compilation process.

* The error object thrown by `render()` and `renderSync()` now includes `line`,
  `column`, `file`, `status`, and `formatted` fields. The `message` field and
  `toString()` also provide more information.

### Dart API

* Add a `renderString()` method for rendering Sass source that's not in a file
  on disk.

## 1.0.0-beta.1

* Drop support for the reference combinator. This has been removed from the
  spec, and will be deprecated and eventually removed in other implementations.

* Trust type annotations when compiling to JavaScript, which makes it
  substantially faster.

* Compile to minified JavaScript, which decreases the code size substantially
  and makes startup a little faster.

* Fix a crash when inspecting a string expression that ended in "\a".

* Fix a bug where declarations and `@extend` were allowed outside of a style
  rule in certain circumstances.

* Fix `not` in parentheses in `@supports` conditions.

* Allow `url` as an identifier name.

* Properly parse `/***/` in selectors.

* Properly parse unary operators immediately after commas.

* Match Ruby Sass's rounding behavior for all functions.

* Allow `\` at the beginning of a selector in the indented syntax.

* Fix a number of `@extend` bugs:

  * `selector-extend()` and `selector-replace()` now allow compound selector
    extendees.

  * Remove the universal selector `*` when unifying with other selectors.

  * Properly unify the result of multiple simple selectors in the same compound
    selector being extended.

  * Properly handle extensions being extended.

  * Properly follow the [first law of `@extend`][laws].

  * Fix selector specificity tracking to follow the
    [second law of `@extend`][laws].

  * Allow extensions that match selectors but fail to unify.

  * Partially-extended selectors are no longer used as parent selectors.

  * Fix an edge case where both the extender and the extended selector
    have invalid combinator sequences.

  * Don't crash with a "Bad state: no element" error in certain edge cases.

[laws]: https://github.com/sass/sass/issues/324#issuecomment-4607184

## 1.0.0-alpha.9

* Elements without a namespace (such as `div`) are no longer unified with
  elements with the empty namespace (such as `|div`). This unification didn't
  match the results returned by `is-superselector()`, and was not guaranteed to
  be valid.

* Support `&` within `@at-root`.

* Properly error when a compound selector is followed immediately by `&`.

* Properly handle variable scoping in `@at-root` and nested properties.

* Properly handle placeholder selectors in selector pseudos.

* Properly short-circuit the `or` and `and` operators.

* Support `--$variable`.

* Don't consider unitless numbers equal to numbers with units.

* Warn about using named colors in interpolation.

* Don't emit loud comments in functions.

* Detect import loops.

* Fix `@import` with a `supports()` clause.

* Forbid functions named "and", "or", and "not".

* Fix `type-of()` with a function.

* Emit a nicer error for invalid tokens in a selector.

* Fix `invert()` with a `$weight` parameter.

* Fix a unit-parsing edge-cases.

* Always parse imports with queries as plain CSS imports.

* Support `&` followed by a non-identifier.

* Properly handle split media queries.

* Properly handle a placeholder selector that isn't at the beginning of a
  compound selector.

* Fix more `str-slice()` bugs.

* Fix the `%` operator.

* Allow whitespace between `=` and the mixin name in the indented syntax.

* Fix some slash division edge cases.

* Fix `not` when used like a function.

* Fix attribute selectors with single-character values.

* Fix some bugs with the `call()` function.

* Properly handle a backslash followed by a CRLF sequence in a quoted string.

* Fix numbers divided by colors.

* Support slash-separated numbers in arguments to plain CSS functions.

* Error out if a function is passed an unknown named parameter.

* Improve the speed of loading large files on Node.

* Don't consider browser-prefixed selector pseudos to be superselectors of
  differently- or non-prefixed selector pseudos with the same base name.

* Fix an `@extend` edge case involving multiple combinators in a row.

* Fix a bug where a `@content` block could get incorrectly passed to a mixin.

* Properly isolate the lexical environments of different calls to the same mixin
  and function.

## 1.0.0-alpha.8

* Add the `content-exists()` function.

* Support interpolation in loud comments.

* Fix a bug where even valid semicolons and exclamation marks in custom property
  values were disallowed.

* Disallow invalid function names.

* Disallow extending across media queries.

* Properly parse whitespace after `...` in argument declaration lists.

* Support terse mixin syntax in the indented syntax.

* Fix `@at-root` query parsing.

* Support special functions in `@-moz-document`.

* Support `...` after a digit.

* Fix some bugs when treating a map as a list of pairs.

## 1.0.0-alpha.7

* Fix `function-exists()`, `variable-exists()`, and `mixin-exists()` to use the
  lexical scope rather than always using the global scope.

* `str-index()` now correctly inserts at negative indices.

* Properly parse `url()`s that contain comment-like text.

* Fix a few more small `@extend` bugs.

* Fix a bug where interpolation in a quoted string was being dropped in some
  circumstances.

* Properly handle `@for` rules where each bound has a different unit.

* Forbid mixins and functions from being defined in control directives.

* Fix a superselector-computation edge case involving `:not()`.

* Gracefully handle input files that are invalid UTF-8.

* Print a Sass stack trace when a file fails to load.

## 1.0.0-alpha.6

* Allow `var()` to be passed to `rgb()`, `rgba()`, `hsl()`, and `hsla()`.

* Fix conversions between numbers with `dpi`, `dpcm`, and `dppx` units.
  Previously these conversions were inverted.

* Don't crash when calling `str-slice()` with an `$end-at` index lower than the
  `$start-at` index.

* `str-slice()` now correctly returns `""` when `$end-at` is negative and points
  before the beginning of the string.

* Interpolation in quoted strings now properly preserves newlines.

* Don't crash when passing only `$hue` or no keyword arguments to
  `adjust-color()`, `scale-color()`, or `change-color()`.

* Preserve escapes in identifiers. This used to only work for identifiers in
  SassScript.

* Fix a few small `@extend` bugs.

## 1.0.0-alpha.5

* Fix bounds-checking for `opacify()`, `fade-in()`, `transparentize()`, and
  `fade-out()`.

* Fix a bug with `@extend` superselector calculations.

* Fix some cases where `#{...}--` would fail to parse in selectors.

* Allow a single number to be passed to `saturate()` for use in filter contexts.

* Fix a bug where `**/` would fail to close a loud comment.

* Fix a bug where mixin and function calls could set variables incorrectly.

* Move plain CSS `@import`s to the top of the document.

## 1.0.0-alpha.4

* Add support for bracketed lists.

* Add support for Unicode ranges.

* Add support for the Microsoft-style `=` operator.

* Print the filename for `@debug` rules.

* Fix a bug where `1 + - 2` and similar constructs would crash the parser.

* Fix a bug where `@extend` produced the wrong result when used with
  selector combinators.

* Fix a bug where placeholder selectors were not allowed to be unified.

* Fix the `mixin-exists()` function.

* Fix `:nth-child()` and `:nth-last-child()` parsing when they contain `of
  selector`.

## 1.0.0-alpha.3

* Fix a bug where color equality didn't take the alpha channel into account.

* Fix a bug with converting some RGB colors to HSL.

* Fix a parent selector resolution bug.

* Properly declare the arguments for `opacify()` and related functions.

* Add a missing dependency on the `stack_trace` package.

* Fix broken Windows archives.

* Emit colors using their original representation if possible.

* Emit colors without an original representation as names if possible.

## 1.0.0-alpha.2

* Fix a bug where variables, functions, and mixins were broken in imported
  files.

## 1.0.0-alpha.1

* Initial alpha release.
