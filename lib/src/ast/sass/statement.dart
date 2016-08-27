// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/statement.dart';
import 'node.dart';

export 'at_rule.dart';
export 'argument_declaration.dart';
export 'argument_invocation.dart';
export 'argument.dart';
export 'callable_declaration.dart';
export 'comment.dart';
export 'declaration.dart';
export 'extend_rule.dart';
export 'function_declaration.dart';
export 'include.dart';
export 'interpolation.dart';
export 'media_query.dart';
export 'media_rule.dart';
export 'mixin_declaration.dart';
export 'return.dart';
export 'style_rule.dart';
export 'stylesheet.dart';
export 'variable_declaration.dart';

abstract class Statement implements SassNode {
  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor);
}