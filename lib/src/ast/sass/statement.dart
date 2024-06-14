// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../visitor/interface/statement.dart';
import 'node.dart';

/// A statement in a Sass syntax tree.
///
/// {@category AST}
abstract interface class Statement implements SassNode {
  /// The location after any trailing whitespace and comments that aren't parsed
  /// as their own statements.
  ///
  /// This is used to generate PostCSS "raws", strings that are used to
  /// reconstruct or modify the exact formatting of the original stylesheet.
  ///
  /// :nodoc
  @internal
  FileLocation get afterTrailing;

  /// Calls the appropriate visit method on [visitor].
  T accept<T>(StatementVisitor<T> visitor);
}
