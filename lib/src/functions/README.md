# Built-In Functions

This directory contains the standard functions that are built into Sass itself,
both those that are available globally and those that are available only through
built-in modules. Each of the files here exports a corresponding
[`BuiltInModule`, and most define a list of global functions as well.

[`BuiltInModule`]: ../module/built_in.dart

There are a few functions that Sass supports that aren't defined here:

* The `if()` function is defined directly in the [`functions.dart`] file,
  although in most cases this is actually parsed as an [`IfExpression`] and
  handled directly by [the evaluator] since it has special behavior about when
  its arguments are evaluated. The function itself only exists for edge cases
  like `if(...$args)` or `meta.get-function("if")`.

  [`functions.dart`]: ../functions.dart
  [`IfExpression`]: ../ast/sass/expression/if.dart
  [the evaluator]: ../visitor/async_evaluate.dart

* Certain functions in the `sass:meta` module require runtime information that's
  only available to the evaluator. These functions are defined in the evaluator
  itself so that they have access to its private variables.
