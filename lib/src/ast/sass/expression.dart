// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../logger.dart';
import '../../parse/scss.dart';
import '../../visitor/interface/expression.dart';
import 'node.dart';

/// A SassScript expression in a Sass syntax tree.
abstract class Expression implements SassNode {
  /// Calls the appropriate visit method on [visitor].
  T accept<T>(ExpressionVisitor<T> visitor);

  /// Parses an expression from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory Expression.parse(String contents, {url, Logger logger}) =>
      new ScssParser(contents, url: url, logger: logger).parseExpression();
}
