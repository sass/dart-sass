// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass/statement.dart';

export 'callable/built_in.dart';
export 'callable/user_defined.dart';

abstract class Callable {
  String get name;

  ArgumentDeclaration get arguments;
}
