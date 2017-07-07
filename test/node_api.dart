// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// This library exposes Dart Sass's Node.js API, imported as JavaScript, back
/// to Dart. This is kind of convoluted, but it allows us to test the API as it
/// will be used in the real world without having to manually write any JS.

import 'dart:typed_data';

import 'package:sass/src/node/render_error.dart';
import 'package:sass/src/node/render_options.dart';
import 'package:sass/src/node/render_result.dart';

import 'package:js/js.dart';

export 'package:sass/src/node/render_error.dart';
export 'package:sass/src/node/render_options.dart';
export 'package:sass/src/node/render_result.dart';
import 'package:sass/src/util/path.dart';

/// The Sass module.
final sass = _require(p.absolute("build/npm/sass.dart"));

@JS("require")
external Sass _require(String path);

@JS()
class Sass {
  external RenderResult renderSync(RenderOptions args);
  external void render(RenderOptions args,
      void callback(RenderError error, RenderResult result));
}
