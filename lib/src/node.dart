// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import 'compile.dart';
import 'exception.dart';
import 'executable.dart' as executable;
import 'node/exports.dart';
import 'node/render_error.dart';
import 'node/render_options.dart';
import 'node/render_result.dart';
import 'node/utils.dart';
import 'util/path.dart';
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
    callback(null, _doRender(options));
  } on SassException catch (error) {
    callback(_wrapException(error), null);
  } catch (error) {
    callback(newRenderError(error.toString(), status: 3), null);
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
    return _doRender(options);
  } on SassException catch (error) {
    jsThrow(_wrapException(error));
  } catch (error) {
    jsThrow(newRenderError(error.toString(), status: 3));
  }
  throw "unreachable";
}

/// Converts Sass to CSS.
///
/// Unlike [_render] and [_renderSync], this doesn't do any special handling for
/// Dart exceptions.
RenderResult _doRender(RenderOptions options) {
  var start = new DateTime.now();
  CompileResult result;
  if (options.data != null) {
    if (options.file != null) {
      throw new ArgumentError(
          "options.data and options.file may not both be set.");
    }

    result = compileString(options.data,
        loadPaths: options.includePaths,
        indented: options.indentedSyntax ?? false,
        style: _parseOutputStyle(options.outputStyle),
        useSpaces: options.indentType != 'tab',
        indentWidth: _parseIndentWidth(options.indentWidth),
        lineFeed: _parseLineFeed(options.linefeed));
  } else if (options.file != null) {
    result = compile(options.file,
        loadPaths: options.includePaths,
        indented: options.indentedSyntax,
        style: _parseOutputStyle(options.outputStyle),
        useSpaces: options.indentType != 'tab',
        indentWidth: _parseIndentWidth(options.indentWidth),
        lineFeed: _parseLineFeed(options.linefeed));
  } else {
    throw new ArgumentError("Either options.data or options.file must be set.");
  }
  var end = new DateTime.now();

  return newRenderResult(result.css,
      entry: options.file ?? 'data',
      start: start.millisecondsSinceEpoch,
      end: end.millisecondsSinceEpoch,
      duration: end.difference(start).inMilliseconds,
      includedFiles: result.includedFiles.toList());
}

/// Converts a [SassException] to a [RenderError].
RenderError _wrapException(SassException exception) {
  var trace = exception is SassRuntimeException
      ? "\n" +
          exception.trace
              .toString()
              .trimRight()
              .split("\n")
              .map((frame) => "  $frame")
              .join("\n")
      : "\n  ${p.fromUri(exception.span.sourceUrl ?? '-')} "
      "${exception.span.start.line + 1}:${exception.span.start.column + 1}  "
      "root stylesheet";

  return newRenderError(exception.message + trace,
      formatted: exception.toString(),
      line: exception.span.start.line + 1,
      column: exception.span.start.column + 1,
      file: exception.span.sourceUrl == null
          ? 'stdin'
          : p.fromUri(exception.span.sourceUrl),
      status: 1);
}

/// Parse [style] into an [OutputStyle].
OutputStyle _parseOutputStyle(String style) {
  if (style == null || style == 'expanded') return OutputStyle.expanded;
  throw new ArgumentError('Unsupported output style "$style".');
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
