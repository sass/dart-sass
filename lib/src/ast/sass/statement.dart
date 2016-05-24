// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/statement.dart';
import 'node.dart';

abstract class Statement implements SassNode {
  /*=T*/ visit/*<T>*/(StatementVisitor/*<T>*/ visitor);
}