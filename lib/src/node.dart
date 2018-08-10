// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:js_util';
import 'dart:typed_data';

import 'package:js/js.dart';
import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart';

import 'ast/sass.dart';
import 'callable.dart';
import 'compile.dart';
import 'exception.dart';
import 'executable.dart' as executable;
import 'importer/node.dart';
import 'node/error.dart';
import 'node/exports.dart';
import 'node/function.dart';
import 'node/render_context.dart';
import 'node/render_context_options.dart';
import 'node/render_options.dart';
import 'node/render_result.dart';
import 'node/types.dart';
import 'node/value.dart';
import 'node/utils.dart';
import 'parse/scss.dart';
import 'syntax.dart';
import 'value.dart';
import 'visitor/serialize.dart';

/// The entrypoint for Node.js.
///
/// This sets up exports that can be called from JS. These include a private
/// export that runs the normal `main()`, which is called from `package/sass.js`
/// to run the executable when installed from npm.
void main() {
  exports.run_ =
      allowInterop((args) => executable.main(new List.from(args as List)));
  exports.render = allowInterop(_render);
  exports.renderSync = allowInterop(_renderSync);
  exports.info =
      "dart-sass\t${const String.fromEnvironment('version')}\t(Sass Compiler)\t"
      "[Dart]\n"
      "dart2js\t${const String.fromEnvironment('dart-version')}\t"
      "(Dart Compiler)\t[Dart]";

  exports.types = new Types(
      Boolean: booleanConstructor,
      Color: colorConstructor,
      List: listConstructor,
      Map: mapConstructor,
      Null: nullConstructor,
      Number: numberConstructor,
      String: stringConstructor);
}

/// Converts Sass to CSS.
///
/// This attempts to match the [node-sass `render()` API][render] as closely as
/// possible.
///
/// [render]: https://github.com/sass/node-sass#options
void _render(
    RenderOptions options, void callback(JSError error, RenderResult result)) {
  if (options.fiber != null) {
    options.fiber.call(allowInterop(() {
      try {
        callback(null, _renderSync(options));
      } catch (error) {
        callback(error as JSError, null);
      }
    })).run();
  } else {
    _renderAsync(options).then((result) {
      callback(null, result);
    }, onError: (error, stackTrace) {
      if (error is SassException) {
        callback(_wrapException(error), null);
      } else {
        callback(_newRenderError(error.toString(), status: 3), null);
      }
    });
  }
}

/// Converts Sass to CSS asynchronously.
Future<RenderResult> _renderAsync(RenderOptions options) async {
  var start = new DateTime.now();
  var file = options.file == null ? null : p.absolute(options.file);
  CompileResult result;
  if (options.data != null) {
    result = await compileStringAsync(options.data,
        nodeImporter: _parseImporter(options, start),
        functions: _parseFunctions(options, asynch: true),
        syntax: isTruthy(options.indentedSyntax) ? Syntax.sass : null,
        style: _parseOutputStyle(options.outputStyle),
        useSpaces: options.indentType != 'tab',
        indentWidth: _parseIndentWidth(options.indentWidth),
        lineFeed: _parseLineFeed(options.linefeed),
        url: options.file == null ? 'stdin' : p.toUri(file).toString(),
        sourceMap: _enableSourceMaps(options));
  } else if (options.file != null) {
    result = await compileAsync(file,
        nodeImporter: _parseImporter(options, start),
        functions: _parseFunctions(options, asynch: true),
        syntax: isTruthy(options.indentedSyntax) ? Syntax.sass : null,
        style: _parseOutputStyle(options.outputStyle),
        useSpaces: options.indentType != 'tab',
        indentWidth: _parseIndentWidth(options.indentWidth),
        lineFeed: _parseLineFeed(options.linefeed),
        sourceMap: _enableSourceMaps(options));
  } else {
    throw new ArgumentError("Either options.data or options.file must be set.");
  }

  return _newRenderResult(options, result, start);
}

/// Converts Sass to CSS.
///
/// This attempts to match the [node-sass `renderSync()` API][render] as closely
/// as possible.
///
/// [render]: https://github.com/sass/node-sass#options
RenderResult _renderSync(RenderOptions options) {
  try {
    var start = new DateTime.now();
    var file = options.file == null ? null : p.absolute(options.file);
    CompileResult result;
    if (options.data != null) {
      result = compileString(options.data,
          nodeImporter: _parseImporter(options, start),
          functions: _parseFunctions(options).cast(),
          syntax: isTruthy(options.indentedSyntax) ? Syntax.sass : null,
          style: _parseOutputStyle(options.outputStyle),
          useSpaces: options.indentType != 'tab',
          indentWidth: _parseIndentWidth(options.indentWidth),
          lineFeed: _parseLineFeed(options.linefeed),
          url: options.file == null ? 'stdin' : p.toUri(file).toString(),
          sourceMap: _enableSourceMaps(options));
    } else if (options.file != null) {
      result = compile(file,
          nodeImporter: _parseImporter(options, start),
          functions: _parseFunctions(options).cast(),
          syntax: isTruthy(options.indentedSyntax) ? Syntax.sass : null,
          style: _parseOutputStyle(options.outputStyle),
          useSpaces: options.indentType != 'tab',
          indentWidth: _parseIndentWidth(options.indentWidth),
          lineFeed: _parseLineFeed(options.linefeed),
          sourceMap: _enableSourceMaps(options));
    } else {
      throw new ArgumentError(
          "Either options.data or options.file must be set.");
    }

    return _newRenderResult(options, result, start);
  } on SassException catch (error) {
    jsThrow(_wrapException(error));
  } catch (error) {
    jsThrow(_newRenderError(error.toString(), status: 3));
  }
  throw "unreachable";
}

/// Converts an exception to a [JSError].
JSError _wrapException(exception) {
  if (exception is SassException) {
    var trace = exception is SassRuntimeException
        ? "\n" +
            exception.trace
                .toString()
                .trimRight()
                .split("\n")
                .map((frame) => "  $frame")
                .join("\n")
        : "\n  ${p.prettyUri(exception.span.sourceUrl ?? '-')} "
        "${exception.span.start.line + 1}:${exception.span.start.column + 1}  "
        "root stylesheet";

    return _newRenderError(exception.message + trace,
        formatted: exception.toString(),
        line: exception.span.start.line + 1,
        column: exception.span.start.column + 1,
        file: exception.span.sourceUrl == null
            ? 'stdin'
            : p.fromUri(exception.span.sourceUrl),
        status: 1);
  } else {
    return new JSError(exception.toString());
  }
}

/// Parses `functions` from [RenderOptions] into a list of [Callable]s or
/// [AsyncCallable]s.
///
/// This is typed to always return [AsyncCallable], but in practice it will
/// return a `List<Callable>` if [asynch] is `false`.
List<AsyncCallable> _parseFunctions(RenderOptions options,
    {bool asynch: false}) {
  if (options.functions == null) return const [];

  var result = <AsyncCallable>[];
  jsForEach(options.functions, (signature, callback) {
    Tuple2<String, ArgumentDeclaration> tuple;
    try {
      tuple = new ScssParser(signature as String).parseSignature();
    } on SassFormatException catch (error) {
      throw new SassFormatException(
          'Invalid signature "${signature}": ${error.message}', error.span);
    }

    if (options.fiber != null) {
      result.add(
          new BuiltInCallable.parsed(tuple.item1, tuple.item2, (arguments) {
        var fiber = options.fiber.current;
        var jsArguments = arguments.map(wrapValue).toList()
          ..add(allowInterop(([result]) {
            // Schedule a microtask so we don't try to resume the running fiber
            // if [importer] calls `done()` synchronously.
            scheduleMicrotask(() => fiber.run(result));
          }));
        var result = Function.apply(callback as Function, jsArguments);
        return unwrapValue(
            isUndefined(result) ? options.fiber.yield() : result);
      }));
    } else if (!asynch) {
      result.add(new BuiltInCallable.parsed(
          tuple.item1,
          tuple.item2,
          (arguments) => unwrapValue(Function.apply(
              callback as Function, arguments.map(wrapValue).toList()))));
    } else {
      result.add(new AsyncBuiltInCallable.parsed(tuple.item1, tuple.item2,
          (arguments) async {
        var completer = new Completer();
        var jsArguments = arguments.map(wrapValue).toList()
          ..add(allowInterop(([result]) => completer.complete(result)));
        var result = Function.apply(callback as Function, jsArguments);
        return unwrapValue(
            isUndefined(result) ? await completer.future : result);
      }));
    }
  });
  return result;
}

/// Parses [importer] and [includePaths] from [RenderOptions] into a
/// [NodeImporter].
NodeImporter _parseImporter(RenderOptions options, DateTime start) {
  List<JSFunction> importers;
  if (options.importer == null) {
    importers = [];
  } else if (options.importer is List) {
    importers = (options.importer as List).cast();
  } else {
    importers = [options.importer as JSFunction];
  }

  var includePaths = new List<String>.from(options.includePaths ?? []);

  RenderContext context;
  if (importers.isNotEmpty) {
    context = new RenderContext(
        options: new RenderContextOptions(
            file: options.file,
            data: options.data,
            includePaths: ([p.current]..addAll(includePaths)).join(":"),
            precision: SassNumber.precision,
            style: 1,
            indentType: options.indentType == 'tab' ? 1 : 0,
            indentWidth: _parseIndentWidth(options.indentWidth) ?? 2,
            linefeed: _parseLineFeed(options.linefeed).text,
            result: new RenderResult(
                stats: new RenderResultStats(
                    start: start.millisecondsSinceEpoch,
                    entry: options.file ?? 'data'))));
    context.options.context = context;
  }

  if (options.fiber != null) {
    importers = importers.map((importer) {
      return allowInteropCaptureThis((thisArg, String url, String previous,
          [_]) {
        var fiber = options.fiber.current;
        var result =
            call3(importer, thisArg, url, previous, allowInterop((result) {
          // Schedule a microtask so we don't try to resume the running fiber if
          // [importer] calls `done()` synchronously.
          scheduleMicrotask(() => fiber.run(result));
        }));
        if (isUndefined(result)) return options.fiber.yield();
        return result;
      }) as JSFunction;
    }).toList();
  }

  return new NodeImporter(context, includePaths, importers);
}

/// Parse [style] into an [OutputStyle].
OutputStyle _parseOutputStyle(String style) {
  if (style == null || style == 'expanded') return OutputStyle.expanded;
  if (style == 'compressed') return OutputStyle.compressed;
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

/// Creates a [RenderResult] that exposes [result] in the Node Sass API format.
RenderResult _newRenderResult(
    RenderOptions options, CompileResult result, DateTime start) {
  var end = new DateTime.now();

  var css = result.css;
  Uint8List sourceMapBytes;
  if (_enableSourceMaps(options)) {
    var sourceMapPath = options.sourceMap is String
        ? options.sourceMap as String
        : options.outFile + '.map';
    var sourceMapDir = p.dirname(sourceMapPath);

    result.sourceMap.sourceRoot = options.sourceMapRoot;
    if (options.outFile == null) {
      if (options.file == null) {
        result.sourceMap.targetUrl = 'stdin.css';
      } else {
        result.sourceMap.targetUrl =
            p.toUri(p.setExtension(options.file, '.css')).toString();
      }
    } else {
      result.sourceMap.targetUrl =
          p.toUri(p.relative(options.outFile, from: sourceMapDir)).toString();
    }

    var sourceMapDirUrl = p.toUri(sourceMapDir).toString();
    for (var i = 0; i < result.sourceMap.urls.length; i++) {
      var source = result.sourceMap.urls[i];
      if (source == "stdin") continue;
      result.sourceMap.urls[i] = p.url.relative(source, from: sourceMapDirUrl);
    }

    var json = result.sourceMap
        .toJson(includeSourceContents: options.sourceMapContents);
    sourceMapBytes = utf8Encode(jsonEncode(json));

    if (!isTruthy(options.omitSourceMapUrl)) {
      var url = options.sourceMapEmbed
          ? new Uri.dataFromBytes(sourceMapBytes, mimeType: "application/json")
          : p.toUri(options.outFile == null
              ? sourceMapPath
              : p.relative(sourceMapPath, from: p.dirname(options.outFile)));
      css += "\n\n/*# sourceMappingURL=$url */";
    }
  }

  return new RenderResult(
      css: utf8Encode(css),
      map: sourceMapBytes,
      stats: new RenderResultStats(
          entry: options.file ?? 'data',
          start: start.millisecondsSinceEpoch,
          end: end.millisecondsSinceEpoch,
          duration: end.difference(start).inMilliseconds,
          includedFiles: result.includedFiles.toList()));
}

/// Returns whether source maps are enabled by [options].
bool _enableSourceMaps(RenderOptions options) =>
    options.sourceMap is String ||
    (isTruthy(options.sourceMap) && options.outFile != null);

/// Creates a [JSError] with the given fields added to it so it acts like a Node
/// Sass error.
JSError _newRenderError(String message,
    {String formatted, int line, int column, String file, int status}) {
  var error = new JSError(message);
  if (formatted != null) setProperty(error, 'formatted', formatted);
  if (line != null) setProperty(error, 'line', line);
  if (column != null) setProperty(error, 'column', column);
  if (file != null) setProperty(error, 'file', file);
  if (status != null) setProperty(error, 'status', status);
  return error;
}
