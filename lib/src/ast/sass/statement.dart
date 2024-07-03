// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../visitor/interface/statement.dart';
import 'node.dart';

// Note: despite not defining any methods here, this has to be a concrete class
// so we can expose its accept() function to the JS parser.

/// A statement in a Sass syntax tree.
///
/// {@category AST}
abstract class Statement implements SassNode {
  /// The location after any trailing whitespace and comments following this
  /// statement that aren't parsed as their own statements.
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
