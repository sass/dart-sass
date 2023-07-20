# Sass Parser

This directory contains various parsers used by Sass. The two most relevant
classes are:

* [`Parser`]: The base class of all other parsers, which includes basic
  infrastructure, utilities, and methods for parsing common CSS constructs that
  appear across multiple different specific parsers.

  [`Parser`]: parser.dart

* [`StylesheetParser`]: The base class specifically for the initial stylesheet
  parse. Almost all of the logic for parsing Sass files, both statement- and
  expression-level, lives here. Only places where individual syntaxes differ
  from one another are left abstract or overridden by subclasses.

  [`StylesheetParser`]: stylesheet.dart

All Sass parsing is done by hand using the [`string_scanner`] package, which we
use to read the source byte-by-byte while also tracking source span information
which we can then use to report errors and generate source maps. We don't use
any kind of parser generator, partly because Sass's grammar requires arbitrary
backtracking in various places and partly because handwritten code is often
easier to read and debug.

[`string_scanner`]: https://pub.dev/packages/string_scanner

The parser is simple recursive descent. There's usually a method for each
logical production that either consumes text and returns its corresponding AST
node or throws an exception; in some cases, a method (conventionally beginning
with `try`) will instead consume text and return a node if it matches and return
null without consuming anything if it doesn't.
