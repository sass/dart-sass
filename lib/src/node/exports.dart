// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'types.dart';

@JS()
class Exports {
  external set run_(Function function);
  external set render(Function function);
  external set renderSync(Function function);
  external set info(String info);
  external set types(Types types);
}

@JS()
external Exports get exports;
