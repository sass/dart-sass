// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass.dart';
import '../callable.dart';
import '../environment.dart';

class UserDefinedCallable implements Callable {
  final CallableDeclaration declaration;

  final Environment environment;

  String get name => declaration.name;
  ArgumentDeclaration get arguments => declaration.arguments;

  UserDefinedCallable(this.declaration, this.environment);
}
