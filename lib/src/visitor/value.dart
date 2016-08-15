// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../value.dart';

abstract class ValueVisitor<T> {
  T visitBoolean(SassBoolean value) => null;
  T visitIdentifier(SassIdentifier value) => null;
  T visitNumber(SassNumber value) => null;
  T visitString(SassString value) => null;
  T visitColor(SassColor value) => null;

  T visitList(SassList value) {
    for (var element in value.contents) {
      element.accept(this);
    }
    return null;
  }

  T visitMap(SassMap value) {
    value.contents.forEach((key, value) {
      key.accept(this);
      value.accept(this);
    });
    return null;
  }
}
