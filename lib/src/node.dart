// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../sass.dart';
import 'executable.dart' as executable;
import 'node/error.dart';
import 'node/exports.dart';
import 'node/options.dart';
import 'node/result.dart';

/// The entrypoint for Node.js.
///
/// This sets up exports that can be called from JS. These include a private
/// export that runs the normal `main()`, which is called from `package/sass.js`
/// to run the executable when installed from NPM.
void main() {
  exports.run_ = allowInterop(executable.main);
  exports.render = allowInterop(_render);
}

/// Converts Sass to CSS.
///
/// This attempts to match the [node-sass `render()` API][render] as closely as
/// possible.
///
/// [render]: https://github.com/sass/node-sass#options
NodeResult _render(NodeOptions options,
    [void callback(NodeError error, NodeResult result)]) {
  try {
    var result = newNodeResult(render(options.file));
    if (callback == null) return result;
    callback(null, result);
  } catch (error) {
    // TODO: should this also be a NodeError?
    if (callback == null) rethrow;

    // TODO: populate the error more thoroughly if possible.
    callback(new NodeError(message: error.message), null);
  }
  return null;
}
