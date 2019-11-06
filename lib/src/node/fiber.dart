// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS()
@anonymous
class FiberClass {
  // Work around sdk#31490.
  external Fiber call(Object function());

  external Fiber get current;

  external Object yield([Object value]);
}

@JS()
@anonymous
class Fiber {
  external Object run([Object value]);
}
