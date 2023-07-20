# Value Types

This directory contains definitions for all the SassScript value types. These
definitions are used both to represent SassScript values internally and in the
public Dart API. They are usually produced by [the evaluator] as it evaluates
the expression-level [Sass AST].

[the evaluator]: ../visitor/async_evaluate.dart
[Sass AST]: ../ast/sass/README.md

Sass values are always immutable, even internally. Any changes to them must be
done by creating a new value. In some cases, it's easiest to make a mutable
copy, edit it, and then create a new immutable value from the result.
