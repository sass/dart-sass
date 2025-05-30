## 0.4.23

* Update types for compatibility with the latest PostCSS.

* **Potentially-breaking bug fix**: parenthesized, comma-separated lists are now
  correctly wrapped in a `ParenthesizedExpression`.

## 0.4.22

* No user-visible changes.

## 0.4.21

* No user-visible changes.

## 0.4.20

* No user-visible changes.

## 0.4.19

* No user-visible changes.

## 0.4.18

* No user-visible changes.

## 0.4.17

* No user-visible changes.

## 0.4.16

* Use union types rather than base classes for Sass nodes wherever possible.
  This makes it possible for TypeScript to automatically narrow node types based
  on `sassType` checks.

* Add support for parsing null literals.

* Add support for parsing parenthesized expressions.

* Add support for parsing selector expressions.

* Add support for parsing the `supports()` function in `@import` modifiers.

* Add support for parsing unary operation expressions.

* Add support for parsing variable expressions.

## 0.4.15

* Add support for parsing list expressions.

* Add support for parsing map expressions.

* Add support for parsing function calls.

* Add support for parsing interpolated function calls.

## 0.4.14

* Add support for parsing color expressions.

## 0.4.13

* No user-visible changes.

## 0.4.12

* Fix more bugs in the automated release process.

## 0.4.11

* Fix the automated release process.

## 0.4.10

* Add support for parsing the `@import` rule.

## 0.4.9

* Add support for parsing the `@include` rule.

* Add support for parsing declarations.

* Add support for parsing the `@if` and `@else` rules.

* Fix the deploy of this package so that it actually contains the package's
  compiled contents.

## 0.4.8

* Add support for parsing the `@mixin` rule.

* Add support for parsing the `@return` rule.

## 0.4.7

* No user-visible changes.

## 0.4.6

* No user-visible changes.

## 0.4.5

* Add support for parsing the `@forward` rule.

## 0.4.4

* No user-visible changes.

## 0.4.3

* Add support for parsing the `@while` rule.

## 0.4.2

* Add support for parsing variable declarations.

* Add support for parsing the `@warn` rule.

## 0.4.1

* Add `BooleanExpression` and `NumberExpression`.

* Add support for parsing the `@use` rule.

## 0.4.0

* **Breaking change:** Warnings are no longer emitted during parsing, so the
  `logger` option has been removed from `SassParserOptions`.

## 0.3.2

* No user-visible changes.

## 0.3.1

* No user-visible changes.

## 0.3.0

* No user-visible changes.

## 0.2.6

* No user-visible changes.

## 0.2.5

* Add support for parsing the `@supports` rule.

## 0.2.4

* No user-visible changes.

## 0.2.3

* No user-visible changes.

## 0.2.2

* No user-visible changes.

## 0.2.1

* No user-visible changes.

## 0.2.0

* Initial unstable release.
