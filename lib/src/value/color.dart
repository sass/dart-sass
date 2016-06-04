// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../visitor/value.dart';
import '../value.dart';

// TODO(nweiz): track original representation.
// TODO(nweiz): support an alpha channel.
class SassColor extends Value {
  final int red;
  final int green;
  final int blue;

  SassColor.rgb(this.red, this.green, this.blue);

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitColor(this);

  String toString() =>
      "#${_hexComponent(red)}${_hexComponent(green)}${_hexComponent(blue)}";
  
  String _hexComponent(int color) => color.toRadixString(16).padLeft(2, '0');
}
