// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/statement.dart';
import 'node.dart';

export 'comment.dart';
export 'declaration.dart';
export 'style_rule.dart';
export 'stylesheet.dart';
export 'variable_declaration.dart';

abstract class Statement implements SassNode {
  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor);
}