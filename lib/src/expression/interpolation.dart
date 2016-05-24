// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

class InterpolationExpression {
  /// If this contains no interpolation, returns the plain text it contains.
  ///
  /// Otherwise, returns `null`.
  String get asPlain;

  InterpolationExpression(List/* <String|Expression> */ contents,
      {SourceSpan span});
}