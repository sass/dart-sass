// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../visitor/interface/modifiable_css.dart';
import '../import.dart';
import '../value.dart';
import 'node.dart';

/// A modifiable version of [CssImport] for use in the evaluation step.
final class ModifiableCssImport(
  @override final CssValue<String> url,
  @override final FileSpan span, {
  @override final CssValue<String>? modifiers,
}) extends ModifiableCssNode implements CssImport {
  @override
  T accept<T>(ModifiableCssVisitor<T> visitor) => visitor.visitCssImport(this);
}
