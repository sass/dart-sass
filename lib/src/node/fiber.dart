// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS()
@anonymous
class FiberClass {
  // Work around sdk#31490.
  external Fiber call(function());

  external Fiber get current;

  external yield([value]);
}

@JS()
@anonymous
class Fiber {
  external run([value]);
}
