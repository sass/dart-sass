// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:tuple/tuple.dart';

import '../ast/sass.dart';
import '../exception.dart';
import '../parse/scss.dart';
import '../utils.dart';

/// Parses a function signature of the format allowed by Node Sass's functions
/// option and returns its name and declaration.
///
/// If [requireParens] is `false`, this allows parentheses to be omitted.
///
/// Throws a [SassFormatException] if parsing fails.
Tuple2<String, ArgumentDeclaration> parseSignature(String signature,
    {bool requireParens = true}) {
  try {
    return ScssParser(signature).parseSignature(requireParens: requireParens);
  } on SassFormatException catch (error, stackTrace) {
    throwWithTrace(
        SassFormatException(
            'Invalid signature "$signature": ${error.message}', error.span),
        stackTrace);
  }
}
