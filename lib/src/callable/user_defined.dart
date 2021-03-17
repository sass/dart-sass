// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass.dart';
import '../callable.dart';

/// A callback defined in the user's Sass stylesheet.
///
/// The type parameter [E] should either be `Environment` or `AsyncEnvironment`.
class UserDefinedCallable<E> implements Callable {
  /// The declaration.
  final CallableDeclaration declaration;

  /// The environment in which this callable was declared.
  final E environment;

  String get name => declaration.name;

  UserDefinedCallable(this.declaration, this.environment);
}
