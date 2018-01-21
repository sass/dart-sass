// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS()
@anonymous
class Types {
  external set Boolean(function);
  external set Color(function);
  external set List(function);
  external set Map(function);
  external set Null(function);
  external set Number(function);
  external set String(function);

  external factory Types({Boolean, Color, List, Map, Null, Number, String});
}
