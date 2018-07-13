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
