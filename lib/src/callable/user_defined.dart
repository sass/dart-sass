// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass.dart';
import '../callable.dart';
import '../environment.dart';

/// A callback defined in the user's Sass stylesheet.
class UserDefinedCallable implements Callable {
  /// The declaration.
  final CallableDeclaration declaration;

  /// The environment in which this callable was declared.
  final Environment environment;

  String get name => declaration.name;

  UserDefinedCallable(this.declaration, this.environment);
}
