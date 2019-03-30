// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../../value.dart';
import '../../../visitor/interface/modifiable_css.dart';
import '../declaration.dart';
import '../value.dart';
import 'node.dart';

/// A modifiable version of [CssDeclaration] for use in the evaluation step.
class ModifiableCssDeclaration extends ModifiableCssNode
    implements CssDeclaration {
  final CssValue<String> name;
  final CssValue<Value> value;
  final FileSpan valueSpanForMap;
  final FileSpan span;

  ModifiableCssDeclaration(this.name, this.value, this.span,
      {FileSpan valueSpanForMap})
      : valueSpanForMap = valueSpanForMap ?? span;

  T accept<T>(ModifiableCssVisitor<T> visitor) =>
      visitor.visitCssDeclaration(this);
}
