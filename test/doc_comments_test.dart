// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:sass/src/ast/sass.dart';
import 'package:test/test.dart';

void main() {
  group('documentation comments', () {
    group('in SCSS', () {
      test('attach to variable declarations', () {
        final contents = r'''
            /// Results my vary.
            $vary: 5.16em;''';
        final stylesheet = Stylesheet.parseScss(contents);
        final variable =
            stylesheet.children.whereType<VariableDeclaration>().first;

        expect(variable.comment.docComment, equals('Results my vary.'));
      });

      test('attach to function rules', () {
        final contents = r'''
            /// A fun function!
            @function fun($val) {
              // Not a doc comment.
              @return ($val / 1000) * 1em;
            }''';
        final stylesheet = Stylesheet.parseScss(contents);
        final function = stylesheet.children.whereType<FunctionRule>().first;

        expect(function.comment.docComment, equals('A fun function!'));
      });

      test('attach to mixin rules', () {
        final contents = r'''
            /// Mysterious mixin.
            @mixin mystery {
              // All black.
              color: black;
              background-color: black;
            }''';
        final stylesheet = Stylesheet.parseScss(contents);
        final mix = stylesheet.children.whereType<MixinRule>().first;

        expect(mix.comment.docComment, equals('Mysterious mixin.'));
      });

      test('are null when there are no triple-slash comments', () {
        final contents = r'''
            // Regular comment.
            $vary: 5.16em;''';
        final stylesheet = Stylesheet.parseScss(contents);
        final variable =
            stylesheet.children.whereType<VariableDeclaration>().first;

        expect(variable.comment.docComment, isNull);
      });

      test('are not carried over across members', () {
        final contents = r'''
            /// Mysterious mixin.
            @mixin mystery {
              // All black.
              color: black;
              background-color: black;
            }

            /// A fun function!
            @function fun($val) {
              // Not a doc comment.
              @return ($val / 1000) * 1em;
            }''';
        final stylesheet = Stylesheet.parseScss(contents);
        final mix = stylesheet.children.whereType<MixinRule>().first;
        final function = stylesheet.children.whereType<FunctionRule>().first;

        expect(mix.comment.docComment, equals('Mysterious mixin.'));
        expect(function.comment.docComment, equals('A fun function!'));
      });

      test('do not include double-slash comments', () {
        final contents = r'''
            // Not a doc comment.
            /// Line 1
            /// Line 2
            // Not a doc comment.
            /// Line 3
            // Not a doc comment.
            $vary: 5.16em;''';
        final stylesheet = Stylesheet.parseScss(contents);
        final variable =
            stylesheet.children.whereType<VariableDeclaration>().first;

        expect(variable.comment.docComment, equals('Line 1\nLine 2\nLine 3'));
      });
    });

    group('in indented syntax', () {
      test('attach to variable declarations', () {
        final contents = r'''
/// Results my vary.
$vary: 5.16em''';
        final stylesheet = Stylesheet.parseSass(contents);
        final variable =
            stylesheet.children.whereType<VariableDeclaration>().first;

        expect(variable.comment.docComment, equals('Results my vary.'));
      });

      test('attach to function rules', () {
        final contents = r'''
/// A fun function!
@function fun($val)
  // Not a doc comment.
  @return ($val / 1000) * 1em''';
        final stylesheet = Stylesheet.parseSass(contents);
        final function = stylesheet.children.whereType<FunctionRule>().first;

        expect(function.comment.docComment, equals('A fun function!'));
      });

      test('attach to mixin rules', () {
        final contents = r'''
/// Mysterious mixin.
@mixin mystery
  // All black.
  color: black
  background-color: black''';
        final stylesheet = Stylesheet.parseSass(contents);
        final mix = stylesheet.children.whereType<MixinRule>().first;

        expect(mix.comment.docComment, equals('Mysterious mixin.'));
      });

      test('are null when there are no triple-slash comments', () {
        final contents = r'''
// Regular comment.
$vary: 5.16em''';
        final stylesheet = Stylesheet.parseSass(contents);
        final variable =
            stylesheet.children.whereType<VariableDeclaration>().first;

        expect(variable.comment.docComment, isNull);
      });

      test('are not carried over across members', () {
        final contents = r'''
/// Mysterious mixin.
@mixin mystery
  // All black.
  color: black
  background-color: black

/// A fun function!
@function fun($val)
  // Not a doc comment.
  @return ($val / 1000) * 1em''';
        final stylesheet = Stylesheet.parseSass(contents);
        final mix = stylesheet.children.whereType<MixinRule>().first;
        final function = stylesheet.children.whereType<FunctionRule>().first;

        expect(mix.comment.docComment, equals('Mysterious mixin.'));
        expect(function.comment.docComment, equals('A fun function!'));
      });

      test('do not include double-slash comments', () {
        final contents = r'''
// Not a doc comment.
/// Line 1
   Line 2
// Not a doc comment.
  Should be ignored.
$vary: 5.16em''';
        final stylesheet = Stylesheet.parseSass(contents);
        final variable =
            stylesheet.children.whereType<VariableDeclaration>().first;

        expect(variable.comment.docComment, equals('Line 1\nLine 2'));
      });

      test('are compacted into one from adjacent comments', () {
        final contents = r'''
// Not a doc comment.
/// Line 1
/// Line 2
   Line 3
/// Line 4
$vary: 5.16em''';
        final stylesheet = Stylesheet.parseSass(contents);
        final variable =
            stylesheet.children.whereType<VariableDeclaration>().first;

        expect(stylesheet.children.length, equals(2));
        expect(variable.comment.docComment,
            equals('Line 1\nLine 2\nLine 3\nLine 4'));
      });
    });
  });
}
