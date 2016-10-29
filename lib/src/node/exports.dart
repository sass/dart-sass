// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS()
class Exports {
  external set run_(function);
  external set render(function);
  external set info(String info);
}

@JS()
external Exports get exports;
