// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../value.dart';

/// A modifiable version of [CssValue] for use in the evaluation step.
class ModifiableCssValue<T> implements CssValue<T> {
  T value;
  final FileSpan span;

  ModifiableCssValue(this.value, this.span);

  String toString() => value.toString();
}
