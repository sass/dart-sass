// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'callable/async.dart';

export 'callable/async.dart';
export 'callable/async_built_in.dart';
export 'callable/built_in.dart';
export 'callable/plain_css.dart';
export 'callable/user_defined.dart';

/// An interface for objects, such as functions and mixins, that can be invoked
/// from Sass by passing in arguments.
///
/// This extends [AsyncCallable] because all synchronous callables are also
/// usable in asynchronous contexts. [Callable]s are usable with both the
/// synchronous and asynchronous `compile()` functions, and as such should be
/// used in preference to [AsyncCallable]s if possible.
abstract class Callable extends AsyncCallable {}
