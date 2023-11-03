# Selector Abstract Syntax Tree

This directory contains the abstract syntax tree that represents a parsed CSS
selector. This AST is constructed recursively by [the selector parser]. It's
fully immutable.

[the selector parser]: ../../parse/selector.dart

Unlike the [Sass AST], which is parsed from a raw source string before being
evaluated, the selector AST is parsed _during evaluation_. This is necessary to
ensure that there's a chance to resolve interpolation before fully parsing the
selectors in question.

[Sass AST]: ../sass/README.md

Although this AST doesn't include any SassScript, it _does_ include a few
Sass-specific constructs: the [parent selector] `&` and [placeholder selectors].
Parent selectors are resolved by [the evaluator] before it hands the AST off to
[the serializer], while placeholders are omitted in the serializer itself.

[parent selector]: parent.dart
[placeholder selectors]: placeholder.dart
[the evaluator]: ../../visitor/async_evaluate.dart
[the serializer]: ../../visitor/serialize.dart
