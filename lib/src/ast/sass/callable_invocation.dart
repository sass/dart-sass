// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'argument_invocation.dart';
import 'node.dart';

abstract class CallableInvocation implements SassNode {
  ArgumentInvocation get arguments;
}
