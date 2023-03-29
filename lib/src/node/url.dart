// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

/// The JavaScript URL class.
///
/// See https://developer.mozilla.org/en-US/docs/Web/API/URL.
@JS('URL')
@anonymous
class JSUrl {
  external JSUrl(String url, [String base]);
}
