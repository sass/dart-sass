# Visitors

This directory contains various types that implement the [visitor pattern] for
[various ASTs]. A few of these, such as [the evaluator] and [the serializer],
implement critical business logic for the Sass compiler. Most of the rest are
either small utilities or base classes for small utilities that need to run over
an AST to determine some kind of information about it. Some are even entirely
unused within Sass itself, and exist only to support users of the [`sass_api`]
package.

[visitor pattern]: https://en.wikipedia.org/wiki/Visitor_pattern
[various ASTs]: ../ast
[the evaluator]: async_evaluate.dart
[the serializer]: serialize.dart
[`sass_api`]: https://pub.dev/packages/sass_api
