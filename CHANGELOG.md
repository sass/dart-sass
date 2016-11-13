## 1.0.0-alpha.4

* Add support for Unicode ranges.

* Add support for the Microsoft-style `=` operator.

* Fix a bug where `1 + - 2` and similar constructs would crash the parser.

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
