// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';

import '../../ast/sass/argument_list.dart';
import '../../ast/sass/statement/content_rule.dart';
import '../../util/span.dart';

extension type JSArgumentList._(JSObject _) implements JSObject {
  ArgumentList get toDart => this as ArgumentList;
}

extension ArgumentListToJS on ArgumentList {
  JSArgumentList get toJS => this as JSArgumentList;
}
