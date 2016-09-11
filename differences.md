# Differences from Ruby Sass

Dart Sass was created and architected by Natalie Weizenbaum, the lead designer
and developer of Ruby Sass. Its architecture is informed by lessons learned from
working on the Ruby implementation, and as such differs in a number of key ways.
This document is intended to record the differences and to act as a guide to
Dart Sass for developers familiar with Ruby Sass.

1. The biggest difference is that Dart Sass intentionally tries to minimize the
   number of whole-stylesheet compilation phases. Ruby Sass loses a lot of time
   to the raw mechanics of AST traversal, so minimizing that should produce
   enough benefit to offset the more complex code.

   The parse phase and the CSS serialization phase both still exist and do more
   or less the same thing as in Ruby Sass. However, the perform, cssize, and
   extend phases are now a single perform phase. This phase executes SassScript
   and builds the final CSS syntax tree from the resulting information. Extends
   and bubbling are applied as the tree is being created.

   The nesting verification phases have been removed in favor of more thorough
   parser-based checking for appropriate nesting, as well as dynamic
   valid-parent checks in the perform phase where necessary.

2. Dart Sass uses entirely separate abstract syntax trees for the Sass input
   than for the CSS output, rather than having some node types shared between
   them. This better models the fact that the data being consumed from the user
   is very different than the data being emitted. In particular, the input data
   often has SassScript in places where the output needs to rely on plain CSS
   for proper formatting.

3. The Sass abstract syntax tree is immutable. This is enabled in part by #2,
   since there's no need to set resolved data on a node that was not previously
   resolved. Immutability makes code dealing with the AST much easier to reason
   about and consequently to refactor.

   The CSS AST, however, is mutable. This is necessary to avoid duplicating all
   the data in the tree when converting it to an immutable form. This is
   especially important because bubbling behavior requires that nodes either be
   inserted or removed from between existing children. We may still use
   interfaces to expose only an immutable view of the CSS AST after
   construction, though.

4. There's no distinction between the statement-level parser and the
   expression-level parser. This distinction in Ruby Sass was an artifact of the
   original indented-syntax-only implementation and didn't really provide any
   utility.

5. The parser is character-based rather than regular-expression-based. This is
   faster due to Dart's well-tuned support for integers, and it gives developers
   finer control over the precise workings of the parser.

6. The parser is more switch-based and less recursion-based. The Ruby Sass
   parser's methods returned a value or `nil`, and much of its logic was based
   on trying to consume one production and moving on to another if the first
   returned `nil`. This makes parsing tend towards `O(n)` in the number of
   productions. The Dart Sass parser instead checks the first character (or
   several characters if necessary) and chooses which production to consume
   based on those.

7. The indented syntax parser and the SCSS parser are subclasses of the same
   superclass. This substantially reduces the amount of duplicated code between
   the two, and makes it easier to give the indented parser good error messaging
   and source span tracking.

8. The environment uses an array of maps to track variable (and eventually
   function and mixin) definitions. This requires fewer allocations and produces
   more cache locality.

9. Because extension is done during the creation of the CSS AST, it works
   differently than the Ruby implementation. Ruby builds a collection of all
   `@extend` directives, and then iterates over the tree applying them to each
   selector as applicable. The perform visitor has similar behavior when
   extending selectors that appear after the `@extend`, but it also needs to
   handle selectors that appear before. To do so, it builds a map of simple
   selectors to the rules that contain them. When an `@extend` is encountered,
   it indexes into this map to determine if anything needs to be extended, and
   applies the extend as needed.

There are also some intentional behavioral differences. These are generally
places where Ruby Sass has an undesired behavior, and it's substantially easier
to implement the correct behavior than it would be to implement compatible
behavior. These should all have tracking bugs against Ruby Sass to update the
official behavior.

1. `@extend .a.b` has the same semantics as `@extend .a; @extend .b`. See
   [issue 1599][].

2. Subject selectors are not supported. See [issue 1126][].

3. Pseudo selector arguments are parsed as `<declaration-value>`s rather than
   having a more limited custom parsing. See [issue 2120][].

4. The numeric precision is set to 10. See [issue 1122][].

5. The indented syntax parser is more flexible: it doesn't require consistent
   indentation across the whole document. This doesn't have an issue yet; I need
   to talk to Chris to determine if it's actually the right way forward.

[issue 1599]: https://github.com/sass/sass/issues/1599
[issue 1126]: https://github.com/sass/sass/issues/1126
[issue 2120]: https://github.com/sass/sass/issues/2120
[issue 1122]: https://github.com/sass/sass/issues/1122

