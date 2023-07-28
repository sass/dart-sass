// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: non_constant_identifier_names
// See dart-lang/sdk#47374

import 'package:js/js.dart';

import '../reflection.dart';

@JS()
@anonymous
class Types {
  external set Boolean(JSClass function);
  external set Color(JSClass function);
  external set List(JSClass function);
  external set Map(JSClass function);
  external set Null(JSClass function);
  external set Number(JSClass function);
  external set String(JSClass function);
  external set Error(JSClass function);

  external factory Types(
      {JSClass? Boolean,
      JSClass? Color,
      JSClass? List,
      JSClass? Map,
      JSClass? Null,
      JSClass? Number,
      JSClass? String,
      JSClass? Error});
}
