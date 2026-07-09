// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../callable.dart';

/// A callable that emits a plain CSS function.
///
/// This can't be used for mixins.
final class PlainCssCallable implements Callable {
  @override
  final String name;

  PlainCssCallable(this.name);

  @override
  bool operator ==(Object other) =>
      other is PlainCssCallable && name == other.name;

  @override
  int get hashCode => name.hashCode;
}
