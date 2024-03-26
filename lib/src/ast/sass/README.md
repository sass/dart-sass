# Sass Abstract Syntax Tree

This directory contains the abstract syntax tree that represents a Sass source
file, regardless of which syntax it was written in (SCSS, the indented syntax,
or plain CSS). The AST is constructed recursively by [a parser] from the leaf
nodes in towards the root, which allows it to be fully immutable.

[a parser]: ../../parse/README.md

The Sass AST is broken up into three categories:

1. The [statement AST], which represents statement-level constructs like
   variable assignments, style rules, and at-rules.

   [statement AST]: statement

2. The [expression AST], which represents SassScript expressions like function
   calls, operations, and value literals.

   [expression AST]: exprssion

3. Miscellaneous AST nodes that are used by both statements and expressions or
   don't fit cleanly into either category that live directly in this directory.

The Sass AST nodes are processed (usually from the root [`Stylesheet`]) by [the
evaluator], which runs the logic they encode and builds up a [CSS AST] that
represents the compiled stylesheet. They can also be transformed back into Sass
source using the `toString()` method. Since this is only ever used for debugging
and doesn't need configuration or full-featured indentation tracking, it doesn't
use a full visitor.

[`Stylesheet`]: statement/stylesheet.dart
[the evaluator]: ../../visitor/async_evaluate.dart
[CSS AST]: ../css/README.md
