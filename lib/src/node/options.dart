// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS()
class NodeOptions {
  external String get file;
  external String get indentType;
  external dynamic get indentWidth;
}
