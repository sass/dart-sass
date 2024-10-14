// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../exception.dart';
import '../../logger.dart';
import '../../parse/scss.dart';
import '../../visitor/interface/expression.dart';
import '../../visitor/is_calculation_safe.dart';
import '../../visitor/source_interpolation.dart';
import '../sass.dart';

// Note: this has to be a concrete class so we can expose its accept() function
// to the JS parser.

/// A SassScript expression in a Sass syntax tree.
///
/// {@category AST}
/// {@category Parsing}
@sealed
abstract class Expression implements SassNode {
  /// Calls the appropriate visit method on [visitor].
  T accept<T>(ExpressionVisitor<T> visitor);

  Expression();

  /// Whether this expression can be used in a calculation context.
  ///
  /// @nodoc
  @internal
  bool get isCalculationSafe => accept(const IsCalculationSafeVisitor());

  /// If this expression is valid interpolated plain CSS, returns the equivalent
  /// of parsing its source as an interpolated unknown value.
  ///
  /// Otherwise, returns null.
  ///
  /// @nodoc
  @internal
  Interpolation? get sourceInterpolation {
    var visitor = SourceInterpolationVisitor();
    accept(visitor);
    return visitor.buffer?.interpolation(span);
  }

  /// Parses an expression from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Expression.parse(String contents, {Object? url, Logger? logger}) =>
      ScssParser(contents, url: url, logger: logger).parseExpression();
}
