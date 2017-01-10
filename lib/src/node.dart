// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:js';
import 'package:js/js.dart';

import '../sass.dart';
import 'exception.dart';
import 'executable.dart' as executable;
import 'node/error.dart';
import 'node/exports.dart';
import 'node/options.dart';
import 'node/result.dart';

/// The entrypoint for Node.js.
///
/// This sets up exports that can be called from JS. These include a private
/// export that runs the normal `main()`, which is called from `package/sass.js`
/// to run the executable when installed from npm.
void main() {
  exports.run_ = allowInterop(executable.main);
  exports.render = allowInterop(_render);
  exports.renderSync = allowInterop(_renderSync);
  exports.info =
      "dart-sass\t${const String.fromEnvironment('version')}\t(Sass Compiler)\t"
      "[Dart]\n"
      "dart2js\t${const String.fromEnvironment('dart-version')}\t"
      "(Dart Compiler)\t[Dart]";
}

/// Converts Sass to CSS.
///
/// This attempts to match the [node-sass `render()` API][render] as closely as
/// possible.
///
/// [render]: https://github.com/sass/node-sass#options
Future _render(NodeOptions options,
    void callback(NodeError error, NodeResult result)) async {
  try {
    var result = newNodeResult(await render(options.file));
    callback(null, result);
  } on SassException catch (error) {
    // TODO: populate the error more thoroughly if possible.
    callback(new NodeError(message: error.message), null);
  }
}

/// Converts Sass to CSS.
///
/// This attempts to match the [node-sass `renderSync()` API][render] as closely
/// as possible.
///
/// [render]: https://github.com/sass/node-sass#options
Future<NodeResult> _renderSync(NodeOptions options) async {
  try {
    return newNodeResult(await render(options.file));
  } on SassException catch (error) {
    // TODO: populate the error more thoroughly if possible.
    throw new NodeError(message: error.message);
  }
}
