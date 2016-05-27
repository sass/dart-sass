// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/css.dart';
import '../node.dart';

export '../../ast/css/comment.dart';
export '../../ast/css/declaration.dart';
export '../../ast/css/style_rule.dart';
export '../../ast/css/stylesheet.dart';
export '../../ast/css/value.dart';

abstract class CssNode extends AstNode {
  /*=T*/ accept/*<T>*/(CssVisitor/*<T>*/ visitor);
}
