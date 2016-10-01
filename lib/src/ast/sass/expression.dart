// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/expression.dart';
import 'node.dart';

/// A SassScript expression in a Sass syntax tree.
abstract class Expression implements SassNode {
  /// Calls the appropriate visit method on [visitor].
  /*=T*/ accept/*<T>*/(ExpressionVisitor/*<T>*/ visitor);
}
