// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:sass/src/ast/sass.dart';
import 'package:test/test.dart';

void main() {
  group('documentation comments', () {
    group('SCSS syntax:', () {
      test('variable declarations are found', () {
        final contents = r'''
            /// Results my vary.
            $vary: 5.16em;''';
        final stylesheet = Stylesheet.parseScss(contents);
        final variable = stylesheet.children
                .firstWhere((child) => child is VariableDeclaration)
            as VariableDeclaration;

        expect(variable.comment.docComment, equals('Results my vary.'));
      });

      test('function rules are found', () {
        final contents = r'''
            /// A fun function!
            @function fun($val) {
              // Not a doc comment.
              @return ($val / 1000) * 1em;
            }''';
        final stylesheet = Stylesheet.parseScss(contents);
        final function = stylesheet.children
            .firstWhere((child) => child is FunctionRule) as FunctionRule;

        expect(function.comment.docComment, equals('A fun function!'));
      });

      test('mixin rules are found', () {
        final contents = r'''
            /// Mysterious mixin.
            @mixin mystery {
              // All black.
              color: black;
              background-color: black;
            }''';
        final stylesheet = Stylesheet.parseScss(contents);
        final mix = stylesheet.children
            .firstWhere((child) => child is MixinRule) as MixinRule;

        expect(mix.comment.docComment, equals('Mysterious mixin.'));
      });

      test('attached to the correct children', () {
        final contents = r'''
            // Regular comment.
            $vary: 5.16em;

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
        final variable = stylesheet.children
                .firstWhere((child) => child is VariableDeclaration)
            as VariableDeclaration;
        final mix = stylesheet.children
            .firstWhere((child) => child is MixinRule) as MixinRule;
        final function = stylesheet.children
            .firstWhere((child) => child is FunctionRule) as FunctionRule;

        expect(variable.comment.docComment, isNull);
        expect(mix.comment.docComment, equals('Mysterious mixin.'));
        expect(function.comment.docComment, equals('A fun function!'));
      });

      test('correct comment lines included', () {
        final contents = r'''
            // Not a doc comment.
            /// Line 1
            /// Line 2
            /// Line 3
            $vary: 5.16em;''';
        final stylesheet = Stylesheet.parseScss(contents);
        final variable = stylesheet.children
                .firstWhere((child) => child is VariableDeclaration)
            as VariableDeclaration;

        expect(variable.comment.docComment, equals('Line 1\nLine 2\nLine 3'));
      });
    });

    group('indented syntax:', () {
      test('variable declarations are found', () {
        final contents = r'''
/// Results my vary.
$vary: 5.16em''';
        final stylesheet = Stylesheet.parseSass(contents);
        final variable = stylesheet.children
                .firstWhere((child) => child is VariableDeclaration)
            as VariableDeclaration;

        expect(variable.comment.docComment, equals('Results my vary.'));
      });

      test('function rules', () {
        final contents = r'''
/// A fun function!
@function fun($val)
  // Not a doc comment.
  @return ($val / 1000) * 1em''';
        final stylesheet = Stylesheet.parseSass(contents);
        final function = stylesheet.children
            .firstWhere((child) => child is FunctionRule) as FunctionRule;

        expect(function.comment.docComment, equals('A fun function!'));
      });

      test('mixin rules are found', () {
        final contents = r'''
/// Mysterious mixin.
@mixin mystery
  // All black.
  color: black
  background-color: black''';
        final stylesheet = Stylesheet.parseSass(contents);
        final mix = stylesheet.children
            .firstWhere((child) => child is MixinRule) as MixinRule;

        expect(mix.comment.docComment, equals('Mysterious mixin.'));
      });

      test('attached to the correct children', () {
        final contents = r'''
// Regular comment.
$vary: 5.16em

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
        final variable = stylesheet.children
                .firstWhere((child) => child is VariableDeclaration)
            as VariableDeclaration;
        final mix = stylesheet.children
            .firstWhere((child) => child is MixinRule) as MixinRule;
        final function = stylesheet.children
            .firstWhere((child) => child is FunctionRule) as FunctionRule;

        expect(variable.comment.docComment, isNull);
        expect(mix.comment.docComment, equals('Mysterious mixin.'));
        expect(function.comment.docComment, equals('A fun function!'));
      });

      test('correct comment lines included', () {
        final contents = r'''
// Not a doc comment.
/// Line 1
   Line 2
$vary: 5.16em''';
        final stylesheet = Stylesheet.parseSass(contents);
        final variable = stylesheet.children
                .firstWhere((child) => child is VariableDeclaration)
            as VariableDeclaration;

        expect(variable.comment.docComment, equals('Line 1\nLine 2'));
      });

      test('compacting adjacent comments into one', () {
        final contents = r'''
// Not a doc comment.
/// Line 1
/// Line 2
   Line 3
$vary: 5.16em''';
        final stylesheet = Stylesheet.parseSass(contents);
        final variable = stylesheet.children
                .firstWhere((child) => child is VariableDeclaration)
            as VariableDeclaration;

        expect(stylesheet.children.length, equals(2));
        expect(variable.comment.docComment, equals('Line 1\nLine 2\nLine 3'));
      });
    });
  });
}
