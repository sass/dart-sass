// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../value.dart';

/// An interface for [visitors][] that traverse SassScript values.
///
/// [visitors]: https://en.wikipedia.org/wiki/Visitor_pattern
abstract class ValueVisitor<T> {
  T visitBoolean(SassBoolean value);
  T visitCalculation(SassCalculation value);
  T visitColor(SassColor value);
  T visitFunction(SassFunction value);
  T visitList(SassList value);
  T visitMap(SassMap value);
  T visitNull();
  T visitNumber(SassNumber value);
  T visitString(SassString value);
}
