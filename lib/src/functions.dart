// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'ast/sass.dart';
import 'callable.dart';
import 'environment.dart';
import 'value.dart';

void defineCoreFunctions(Environment environment) {
  environment.setFunction(new BuiltInCallable(
      "inspect",
      new ArgumentDeclaration([new Argument("value")]),
      (arguments) => new SassIdentifier(arguments.single.toString())));
}
