// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

@JS('Buffer.from')
external _buffer(String source, String encoding);

@JS()
@anonymous
class NodeResult {
  external get buffer;

  external factory NodeResult._({buffer});
}

NodeResult newNodeResult(String css) =>
    new NodeResult._(buffer: _buffer(css, 'utf8'));
