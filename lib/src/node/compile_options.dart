// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'logger.dart';
import 'url.dart';

@JS()
@anonymous
class CompileOptions {
  // TODO(nweiz): support alertAscii
  external bool? get alertColor;
  external List<String>? get loadPaths;
  external bool? get quietDeps;
  external String? get style;
  external bool? get verbose;
  external bool? get sourceMap;
  external NodeLogger? get logger;
}

@JS()
@anonymous
class CompileStringOptions extends CompileOptions {
  external String? get syntax;
  external JSUrl? get url;
}
