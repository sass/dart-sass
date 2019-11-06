// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS()
@anonymous
class Types {
  external set Boolean(Function function);
  external set Color(Function function);
  external set List(Function function);
  external set Map(Function function);
  external set Null(Function function);
  external set Number(Function function);
  external set String(Function function);
  external set Error(Function function);

  external factory Types(
      {Function Boolean,
      Function Color,
      Function List,
      Function Map,
      Function Null,
      Function Number,
      Function String,
      Function Error});
}
