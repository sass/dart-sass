// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'argument_invocation.dart';
import 'node.dart';

/// An abstract class for invoking a callable (a function or mixin).
abstract class CallableInvocation implements SassNode {
  /// The arguments passed to the callable.
  ArgumentInvocation get arguments;
}
