// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js_core/unsafe.dart';

import '../../ast/sass/argument_list.dart';

extension ArgumentListToJS on ArgumentList {
  UnsafeDartWrapper<ArgumentList> get toJS => toUnsafeWrapper;
}
