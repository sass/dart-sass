// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// Almost all CSS output tests should go in sass-spec rather than here. This
// just covers tests that explicitly validate out that's considered too
// implementation-specific to verify in sass-spec.

import 'package:test/test.dart';

import 'package:sass/sass.dart';

void main() {
  group("emits private-use area characters as escapes in expanded mode", () {
    testCharacter(String escape) {
      test(escape, () {
        expect(compileString("a {b: $escape}"),
            equalsIgnoringWhitespace("a { b: $escape; }"));
      });
    }

    group("in the basic multilingual plane", () {
      testCharacter(r"\e000");
      testCharacter(r"\f000");
      testCharacter(r"\f8ff");
    });

    group("in the supplementary planes", () {
      testCharacter(r"\f0000");
      testCharacter(r"\fabcd");
      testCharacter(r"\ffffd");
      testCharacter(r"\100000");
      testCharacter(r"\10abcd");
      testCharacter(r"\10fffd");

      // Although these aren't technically in private-use area, they're in
      // private-use planes and they have no visual representation to we
      // escape them as well.
      group("that aren't technically in PUAs", () {
        testCharacter(r"\ffffe");
        testCharacter(r"\fffff");
        testCharacter(r"\10fffe");
        testCharacter(r"\10ffff");
      });
    });

    group("adds a space", () {
      test("if followed by a hex character", () {
        expect(compileString(r"a {b: '\e000 a'}"),
            equalsIgnoringWhitespace(r'a { b: "\e000 a"; }'));
      });

      test("if followed by a space", () {
        expect(compileString(r"a {b: '\e000  '}"),
            equalsIgnoringWhitespace(r'a { b: "\e000  "; }'));
      });
    });
  });

  // Regression test for sass/dart-sass#623. This needs to be tested here
  // because sass-spec normalizes CR LF newlines.
  group("normalizes newlines in a loud comment", () {
    test("in SCSS", () {
      expect(compileString("/* foo\r\n * bar */"), equals("/* foo\n * bar */"));
    });

    test("in Sass", () {
      expect(compileString("/*\r\n  foo\r\n  bar", syntax: Syntax.sass),
          equals("/* foo\n * bar */"));
    });
  });

  // Regression test for sass/dart-sass#688. This needs to be tested here
  // because it varies between Dart and Node.
  group("removes exponential notation", () {
    group("for integers", () {
      test(">= 1e21", () {
        expect(compileString("a {b: 1e21}"),
            equalsIgnoringWhitespace("a { b: 1${'0' * 21}; }"));
      });

      // At time of writing, numbers that are 20 digits or fewer are not printed
      // in exponential notation by either Dart or Node, and we rely on that to
      // determine when to get rid of the exponent. This test ensures that if that
      // ever changes, we know about it.
      test("< 1e21", () {
        expect(compileString("a {b: 1e20}"),
            equalsIgnoringWhitespace("a { b: 1${'0' * 20}; }"));
      });
    });

    group("for floating-point numbers", () {
      test("Infinity", () {
        expect(compileString("a {b: 1e999}"),
            equalsIgnoringWhitespace("a { b: Infinity; }"));
      });

      test(">= 1e21", () {
        expect(compileString("a {b: 1.01e21}"),
            equalsIgnoringWhitespace("a { b: 101${'0' * 19}; }"));
      });

      // At time of writing, numbers that are 20 digits or fewer are not printed
      // in exponential notation by either Dart or Node, and we rely on that to
      // determine when to get rid of the exponent. This test ensures that if that
      // ever changes, we know about it.
      test("< 1e21", () {
        expect(compileString("a {b: 1.01e20}"),
            equalsIgnoringWhitespace("a { b: 101${'0' * 18}; }"));
      });
    });
  });

  // Tests for sass/dart-sass#417.
  //
  // Note there's no need for "in Sass" cases as it's not possible to have
  // trailing loud comments in the Sass syntax.
  group("preserve trailing loud comments in SCSS", () {
    test("after open block", () {
      expect(compileString("""
selector { /* please don't move me */
  name: value;
}"""), equals("""
selector { /* please don't move me */
  name: value;
}"""));
    });

    test("after open block (multi-line selector)", () {
      expect(compileString("""
selector1,
selector2 { /* please don't move me */
  name: value;
}"""), equals("""
selector1,
selector2 { /* please don't move me */
  name: value;
}"""));
    });

    test("after close block", () {
      expect(compileString("""
selector {
  name: value;
} /* please don't move me */"""), equals("""
selector {
  name: value;
} /* please don't move me */"""));
    });

    test("only content in block", () {
      expect(compileString("""
selector {
  /* please don't move me */
}"""), equals("""
selector {
  /* please don't move me */
}"""));
    });

    test("only content in block (no newlines)", () {
      expect(compileString("""
selector { /* please don't move me */ }"""), equals("""
selector { /* please don't move me */ }"""));
    });

    test("after property in block", () {
      expect(compileString("""
selector {
  name1: value1; /* please don't move me 1 */
  name2: value2; /* please don't move me 2 */
  name3: value3; /* please don't move me 3 */
}"""), equals("""
selector {
  name1: value1; /* please don't move me 1 */
  name2: value2; /* please don't move me 2 */
  name3: value3; /* please don't move me 3 */
}"""));
    });

    test("after rule in block", () {
      expect(compileString("""
selector {
  @rule1; /* please don't move me 1 */
  @rule2; /* please don't move me 2 */
  @rule3; /* please don't move me 3 */
}"""), equals("""
selector {
  @rule1; /* please don't move me 1 */
  @rule2; /* please don't move me 2 */
  @rule3; /* please don't move me 3 */
}"""));
    });

    test("after top-level statement", () {
      expect(compileString("@rule; /* please don't move me */"),
          equals("@rule; /* please don't move me */"));
    });

    // The trailing comment detection logic looks for left braces to detect
    // whether a comment is on the same line as its parent node.  This test
    // checks to make sure it isn't confused by syntax that uses braces for
    // things other than starting child blocks.
    test("selector contains left brace", () {
      expect(compileString("""@rule1;
@rule2;
selector[href*="{"]
{ /* please don't move me */ }

@rule3;"""), equals("""@rule1;
@rule2;
selector[href*="{"] { /* please don't move me */ }

@rule3;"""));
    });

    test("loud comments in mixin", () {
      expect(compileString("""
@mixin loudComment {
  /* ... */
}

selector {
  @include loudComment;
}"""), "selector {\n  /* ... */\n}");
    });
  });
}
