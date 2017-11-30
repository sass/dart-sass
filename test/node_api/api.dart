// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// This library exposes Dart Sass's Node.js API, imported as JavaScript, back
/// to Dart. This is kind of convoluted, but it allows us to test the API as it
/// will be used in the real world without having to manually write any JS.

import 'package:sass/src/node/render_error.dart';
import 'package:sass/src/node/render_options.dart';
import 'package:sass/src/node/render_result.dart';
import 'package:sass/src/util/path.dart';

import 'package:js/js.dart';

export 'package:sass/src/node/importer_result.dart';
export 'package:sass/src/node/render_context.dart';
export 'package:sass/src/node/render_error.dart';
export 'package:sass/src/node/render_options.dart';
export 'package:sass/src/node/render_result.dart';

/// The Sass module.
final sass = _require(p.absolute("build/npm/sass.dart"));

/// A `null` that's guaranteed to be represented by JavaScript's `undefined`
/// value, not by `null`.
@JS()
external Object get undefined;

/// A `null` that's guaranteed to be represented by JavaScript's `null` value,
/// not by `undefined`.
///
/// We have to use eval here because otherwise dart2js will inline the null
/// value and then optimize it away.
final Object jsNull = _eval("null");

@JS("eval")
external Object _eval(String js);

@JS("process.chdir")
external void chdir(String directory);

@JS("require")
external Sass _require(String path);

@JS()
class Sass {
  external RenderResult renderSync(RenderOptions args);
  external void render(RenderOptions args,
      void callback(RenderError error, RenderResult result));
}

@JS("Error")
class JSError {
  external JSError(String message);
}
