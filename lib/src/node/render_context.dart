// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'render_context_options.dart';

@JS()
@anonymous
class RenderContext {
  external RenderContextOptions get options;

  external factory RenderContext({RenderContextOptions options});
}
