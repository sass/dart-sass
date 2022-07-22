// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

/// A combinator that defines the relationship between selectors in a
/// [ComplexSelector].
///
/// {@category AST}
@sealed
class Combinator {
  /// Matches the right-hand selector if it's immediately adjacent to the
  /// left-hand selector in the DOM tree.
  static const nextSibling = Combinator._("+");

  /// Matches the right-hand selector if it's a direct child of the left-hand
  /// selector in the DOM tree.
  static const child = Combinator._(">");

  /// Matches the right-hand selector if it comes after the left-hand selector
  /// in the DOM tree.
  static const followingSibling = Combinator._("~");

  /// The combinator's token text.
  final String _text;

  const Combinator._(this._text);

  String toString() => _text;
}
