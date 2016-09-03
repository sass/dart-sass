// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/css.dart';
import '../selector.dart';
import 'node.dart';
import 'value.dart';

class CssStyleRule extends CssParentNode {
  final CssValue<SelectorList> selector;

  final FileSpan span;

  bool get isInvisible {
    if (super.isInvisible) return true;
    return selector.value.components
        .every((complex) => complex.containsPlaceholder);
  }

  CssStyleRule(this.selector, this.span);

  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor) =>
      visitor.visitStyleRule(this);

  CssStyleRule copyWithoutChildren() => new CssStyleRule(selector, span);
}
