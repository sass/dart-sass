## 1.0.0-alpha.7

* Properly parse `url()`s that contain comment-like text.

* Fix a few more small `@extend` bugs.

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
