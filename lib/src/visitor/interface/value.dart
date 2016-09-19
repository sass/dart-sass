// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../value.dart';

abstract class ValueVisitor<T> {
  T visitBoolean(SassBoolean value);
  T visitColor(SassColor value);
  T visitList(SassList value);
  T visitMap(SassMap value);
  T visitNull(SassNull value);
  T visitNumber(SassNumber value);
  T visitString(SassString value);
}
