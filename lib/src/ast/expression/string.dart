// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../expression.dart';
import 'interpolation.dart';

class StringExpression implements Expression {
  /// Interpolation that, when evaluated, produces the semantic content of the
  /// string.
  ///
  /// Unlike [asInterpolation], escapes are resolved and quotes are not
  /// included.
  final InterpolationExpression text;

  SourceSpan get span => text.span;

  /// Interpolation that, when evaluated, produces the syntax of the string.
  ///
  /// Unlike [text], his doesn't resolve escapes and does include quotes.
  InterpolationExpression get asInterpolation => throw new UnimplementedError();

  StringExpression(this.text);
}