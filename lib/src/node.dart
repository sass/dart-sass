// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'exception.dart';
import 'executable.dart' as executable;
import 'node/exports.dart';
import 'node/render_error.dart';
import 'node/render_options.dart';
import 'node/render_result.dart';
import 'node/utils.dart';
import 'render.dart';
import 'visitor/serialize.dart';

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
void _render(RenderOptions options,
    void callback(RenderError error, RenderResult result)) {
  try {
    var result = newRenderResult(render(options.file,
        useSpaces: options.indentType != 'tab',
        indentWidth: _parseIndentWidth(options.indentWidth),
        lineFeed: _parseLineFeed(options.linefeed)));
    callback(null, result);
  } on SassException catch (error) {
    // TODO: populate the error more thoroughly if possible.
    callback(newRenderError(message: error.message), null);
  }
}

/// Converts Sass to CSS.
///
/// This attempts to match the [node-sass `renderSync()` API][render] as closely
/// as possible.
///
/// [render]: https://github.com/sass/node-sass#options
RenderResult _renderSync(RenderOptions options) {
  try {
    return newRenderResult(render(options.file,
        useSpaces: options.indentType != 'tab',
        indentWidth: _parseIndentWidth(options.indentWidth),
        lineFeed: _parseLineFeed(options.linefeed)));
  } on SassException catch (error) {
    // TODO: populate the error more thoroughly if possible.
    jsThrow(newRenderError(message: error.message));
    throw "unreachable";
  }
}

/// Parses the indentation width into an [int].
int _parseIndentWidth(width) {
  if (width == null) return null;
  return width is int ? width : int.parse(width.toString());
}

/// Parses the name of a line feed type into a [LineFeed].
LineFeed _parseLineFeed(String str) {
  switch (str) {
    case 'cr':
      return LineFeed.cr;
    case 'crlf':
      return LineFeed.crlf;
    case 'lfcr':
      return LineFeed.lfcr;
    default:
      return LineFeed.lf;
  }
}
