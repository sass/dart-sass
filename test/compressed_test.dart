// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:test/test.dart';

import 'package:sass/sass.dart';

void main() {
  group("in style rules", () {
    test("removes unnecessary whitespace and semicolons", () {
      expect(_compile("a {x: y}"), equals("a{x:y}"));
    });

    group("for selectors", () {
      test("preserves whitespace where necessary", () {
        expect(_compile("a b .c {x: y}"), equals("a b .c{x:y}"));
      });

      test("removes whitespace after commas", () {
        expect(_compile("a, b, .c {x: y}"), equals("a,b,.c{x:y}"));
      });

      test("doesn't preserve newlines", () {
        expect(_compile("a,\nb,\n.c {x: y}"), equals("a,b,.c{x:y}"));
      });

      test("removes whitespace around combinators", () {
        expect(_compile("a > b {x: y}"), equals("a>b{x:y}"));
        expect(_compile("a + b {x: y}"), equals("a+b{x:y}"));
        expect(_compile("a ~ b {x: y}"), equals("a~b{x:y}"));
      });

      group("in prefixed pseudos", () {
        test("preserves whitespace", () {
          expect(_compile("a:nth-child(2n of b) {x: y}"),
              equals("a:nth-child(2n of b){x:y}"));
        });

        test("removes whitespace after commas", () {
          expect(_compile("a:nth-child(2n of b, c) {x: y}"),
              equals("a:nth-child(2n of b,c){x:y}"));
        });
      });

      group("in attribute selectors with modifiers", () {
        test("removes whitespace when quotes are required", () {
          expect(_compile('[a=" " b] {x: y}'), equals('[a=" "b]{x:y}'));
        });

        test("doesn't remove whitespace when quotes aren't required", () {
          expect(_compile('[a="b"c] {x: y}'), equals('[a=b c]{x:y}'));
        });
      });
    });

    group("for declarations", () {
      test("preserves semicolons when necessary", () {
        expect(_compile("a {q: r; s: t}"), equals("a{q:r;s:t}"));
      });

      group("of custom properties", () {
        test("folds whitespace for multiline properties", () {
          expect(_compile("""
            a {
              --foo: {
                q: r;
                b {
                  s: t;
                }
              }
            }
          """), equals("a{--foo: { q: r; b { s: t; } } }"));
        });

        test("folds whitespace for single-line properties", () {
          expect(_compile("""
            a {
              --foo: a   b\t\tc;
            }
          """), equals("a{--foo: a b\tc}"));
        });

        test("preserves semicolons when necessary", () {
          expect(_compile("""
            a {
              --foo: {
                a: b;
              };
              --bar: x y;
              --baz: q r;
            }
          """), equals("a{--foo: { a: b; };--bar: x y;--baz: q r}"));
        });
      });
    });
  });

  group("values:", () {
    group("numbers", () {
      test("omit the leading 0", () {
        expect(_compile("a {b: 0.123}"), equals("a{b:.123}"));
        expect(_compile("a {b: 0.123px}"), equals("a{b:.123px}"));
      });
    });

    group("lists", () {
      test("don't include spaces after commas", () {
        expect(_compile("a {b: x, y, z}"), equals("a{b:x,y,z}"));
      });

      test("do include spaces when space-separated", () {
        expect(_compile("a {b: x y z}"), equals("a{b:x y z}"));
      });
    });

    group("colors", () {
      test("use names when they're shortest", () {
        expect(_compile("a {b: #f00}"), equals("a{b:red}"));
      });

      test("use terse hex when it's shortest", () {
        expect(_compile("a {b: white}"), equals("a{b:#fff}"));
      });

      test("use verbose hex when it's shortest", () {
        expect(_compile("a {b: darkgoldenrod}"), equals("a{b:#b8860b}"));
      });

      test("use rgba() when necessary", () {
        expect(_compile("a {b: rgba(255, 0, 0, 0.5)}"),
            equals("a{b:rgba(255,0,0,.5)}"));
      });

      test("don't error when there's no name", () {
        expect(_compile("a {b: #cc3232}"), equals("a{b:#cc3232}"));
      });
    });
  });

  group("the top level", () {
    test("removes whitespace and semicolons between at-rules", () {
      expect(_compile("@foo; @bar; @baz;"), equals("@foo;@bar;@baz"));
    });

    test("removes whitespace between style rules", () {
      expect(_compile("a {b: c} x {y: z}"), equals("a{b:c}x{y:z}"));
    });
  });

  group("@supports", () {
    test("removes whitespace around the condition", () {
      expect(_compile("@supports (display: flex) {a {b: c}}"),
          equals("@supports(display: flex){a{b:c}}"));
    });

    test("preserves whitespace before the condition if necessary", () {
      expect(_compile("@supports not (display: flex) {a {b: c}}"),
          equals("@supports not (display: flex){a{b:c}}"));
    });
  });

  group("@media", () {
    test("removes whitespace around the query", () {
      expect(_compile("@media (min-width: 900px) {a {b: c}}"),
          equals("@media(min-width: 900px){a{b:c}}"));
    });

    test("preserves whitespace before the query if necessary", () {
      expect(_compile("@media screen {a {b: c}}"),
          equals("@media screen{a{b:c}}"));
    });

    test("preserves whitespace before the query if necessary", () {
      expect(_compile("@media screen {a {b: c}}"),
          equals("@media screen{a{b:c}}"));
    });

    // Removing whitespace after "and", "or", or "not" is forbidden because it
    // would cause it to parse as a function token.
    test('removes whitespace before "and" when possible', () {
      expect(
          _compile("""
        @media screen and (min-width: 900px) and (max-width: 100px) {
          a {b: c}
        }
      """),
          equals("@media screen and (min-width: 900px)and (max-width: 100px)"
              "{a{b:c}}"));
    });

    test("preserves whitespace around the modifier", () {
      expect(_compile("@media only screen {a {b: c}}"),
          equals("@media only screen{a{b:c}}"));
    });
  });

  group("@keyframes", () {
    test("removes whitespace after the selector", () {
      expect(_compile("@keyframes a {from {a: b}}"),
          equals("@keyframes a{from{a:b}}"));
    });

    test("removes whitespace after commas", () {
      expect(_compile("@keyframes a {from, to {a: b}}"),
          equals("@keyframes a{from,to{a:b}}"));
    });
  });

  group("@import", () {
    test("removes whitespace before the URL", () {
      expect(_compile('@import "foo.css";'), equals('@import"foo.css"'));
    });

    test("converts a url() to a string", () {
      expect(_compile('@import url(foo.css);'), equals('@import"foo.css"'));
      expect(_compile('@import url("foo.css");'), equals('@import"foo.css"'));
    });

    test("removes whitespace before a media query", () {
      expect(_compile('@import "foo.css" screen;'),
          equals('@import"foo.css"screen'));
    });

    test("removes whitespace before a supports condition", () {
      expect(_compile('@import "foo.css" supports(display: flex);'),
          equals('@import"foo.css"supports(display: flex)'));
    });
  });

  group("comments", () {
    test("are removed", () {
      expect(_compile("/* foo bar */"), isEmpty);
      expect(_compile("""
        a {
          b: c;
          /* foo bar */
          d: e;
        }
      """), equals("a{b:c;d:e}"));
    });

    test("remove their parents if they're the only contents", () {
      expect(_compile("a {/* foo bar */}"), isEmpty);
      expect(_compile("""
        a {
          /* foo bar */
          /* baz bang */
        }
      """), isEmpty);
    });

    test("are preserved with /*!", () {
      expect(_compile("/*! foo bar */"), equals("/*! foo bar */"));
      expect(
          _compile("/*! foo */\n/*! bar */"), equals("/*! foo *//*! bar */"));
      expect(_compile("""
        a {
          /*! foo bar */
        }
      """), equals("a{/*! foo bar */}"));
    });
  });
}

/// Like [compileString], but always produces compressed output.
String _compile(String source) =>
    compileString(source, style: OutputStyle.compressed);
