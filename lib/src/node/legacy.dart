// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:js_util';
import 'dart:typed_data';

import 'package:js/js.dart';
import 'package:node_interop/js.dart';
import 'package:path/path.dart' as p;
import 'package:tuple/tuple.dart';

import '../ast/sass.dart';
import '../callable.dart';
import '../compile.dart';
import '../compile_result.dart';
import '../exception.dart';
import '../importer/legacy_node.dart';
import '../io.dart';
import '../logger.dart';
import '../logger/node_to_dart.dart';
import '../parse/scss.dart';
import '../syntax.dart';
import '../util/nullable.dart';
import '../utils.dart';
import '../value.dart';
import '../visitor/serialize.dart';
import 'function.dart';
import 'legacy/render_context.dart';
import 'legacy/render_options.dart';
import 'legacy/render_result.dart';
import 'legacy/value.dart';
import 'utils.dart';

/// Converts Sass to CSS.
///
/// This attempts to match the [node-sass `render()` API][render] as closely as
/// possible.
///
/// [render]: https://github.com/sass/node-sass#options
void render(
    RenderOptions options, void callback(Object? error, RenderResult? result)) {
  var fiber = options.fiber;
  if (fiber != null) {
    fiber.call(allowInterop(() {
      try {
        callback(null, renderSync(options));
      } catch (error) {
        callback(error, null);
      }
      return null;
    })).run();
  } else {
    _renderAsync(options).then((result) {
      callback(null, result);
    }, onError: (Object error, StackTrace stackTrace) {
      if (error is SassException) {
        callback(_wrapException(error, stackTrace), null);
      } else {
        callback(
            _newRenderError(error.toString(), getTrace(error) ?? stackTrace,
                status: 3),
            null);
      }
    });
  }
}

/// Converts Sass to CSS asynchronously.
Future<RenderResult> _renderAsync(RenderOptions options) async {
  var start = DateTime.now();
  CompileResult result;

  var data = options.data;
  var file = options.file.andThen(p.absolute);
  if (data != null) {
    result = await compileStringAsync(data,
        nodeImporter: _parseImporter(options, start),
        functions: _parseFunctions(options, start, asynch: true),
        syntax: isTruthy(options.indentedSyntax) ? Syntax.sass : null,
        style: _parseOutputStyle(options.outputStyle),
        useSpaces: options.indentType != 'tab',
        indentWidth: _parseIndentWidth(options.indentWidth),
        lineFeed: _parseLineFeed(options.linefeed),
        url: file == null ? 'stdin' : p.toUri(file).toString(),
        quietDeps: options.quietDeps ?? false,
        verbose: options.verbose ?? false,
        charset: options.charset ?? true,
        sourceMap: _enableSourceMaps(options),
        logger: NodeToDartLogger(
            options.logger, Logger.stderr(color: hasTerminal)));
  } else if (file != null) {
    result = await compileAsync(file,
        nodeImporter: _parseImporter(options, start),
        functions: _parseFunctions(options, start, asynch: true),
        syntax: isTruthy(options.indentedSyntax) ? Syntax.sass : null,
        style: _parseOutputStyle(options.outputStyle),
        useSpaces: options.indentType != 'tab',
        indentWidth: _parseIndentWidth(options.indentWidth),
        lineFeed: _parseLineFeed(options.linefeed),
        quietDeps: options.quietDeps ?? false,
        verbose: options.verbose ?? false,
        charset: options.charset ?? true,
        sourceMap: _enableSourceMaps(options),
        logger: NodeToDartLogger(
            options.logger, Logger.stderr(color: hasTerminal)));
  } else {
    throw ArgumentError("Either options.data or options.file must be set.");
  }

  return _newRenderResult(options, result, start);
}

/// Converts Sass to CSS.
///
/// This attempts to match the [node-sass `renderSync()` API][render] as closely
/// as possible.
///
/// [render]: https://github.com/sass/node-sass#options
RenderResult renderSync(RenderOptions options) {
  try {
    var start = DateTime.now();
    CompileResult result;

    var data = options.data;
    var file = options.file.andThen(p.absolute);
    if (data != null) {
      result = compileString(data,
          nodeImporter: _parseImporter(options, start),
          functions: _parseFunctions(options, start).cast(),
          syntax: isTruthy(options.indentedSyntax) ? Syntax.sass : null,
          style: _parseOutputStyle(options.outputStyle),
          useSpaces: options.indentType != 'tab',
          indentWidth: _parseIndentWidth(options.indentWidth),
          lineFeed: _parseLineFeed(options.linefeed),
          url: file == null ? 'stdin' : p.toUri(file).toString(),
          quietDeps: options.quietDeps ?? false,
          verbose: options.verbose ?? false,
          charset: options.charset ?? true,
          sourceMap: _enableSourceMaps(options),
          logger: NodeToDartLogger(
              options.logger, Logger.stderr(color: hasTerminal)));
    } else if (file != null) {
      result = compile(file,
          nodeImporter: _parseImporter(options, start),
          functions: _parseFunctions(options, start).cast(),
          syntax: isTruthy(options.indentedSyntax) ? Syntax.sass : null,
          style: _parseOutputStyle(options.outputStyle),
          useSpaces: options.indentType != 'tab',
          indentWidth: _parseIndentWidth(options.indentWidth),
          lineFeed: _parseLineFeed(options.linefeed),
          quietDeps: options.quietDeps ?? false,
          verbose: options.verbose ?? false,
          charset: options.charset ?? true,
          sourceMap: _enableSourceMaps(options),
          logger: NodeToDartLogger(
              options.logger, Logger.stderr(color: hasTerminal)));
    } else {
      throw ArgumentError("Either options.data or options.file must be set.");
    }

    return _newRenderResult(options, result, start);
  } on SassException catch (error, stackTrace) {
    jsThrow(_wrapException(error, stackTrace));
  } catch (error, stackTrace) {
    jsThrow(_newRenderError(error.toString(), getTrace(error) ?? stackTrace,
        status: 3));
  }
}

/// Converts an exception to a [JsError].
JsError _wrapException(Object exception, StackTrace stackTrace) {
  if (exception is SassException) {
    String file;
    var url = exception.span.sourceUrl;
    if (url == null) {
      file = 'stdin';
    } else if (url.scheme == 'file') {
      file = p.fromUri(url);
    } else {
      file = url.toString();
    }

    return _newRenderError(exception.toString().replaceFirst("Error: ", ""),
        getTrace(exception) ?? stackTrace,
        line: exception.span.start.line + 1,
        column: exception.span.start.column + 1,
        file: file,
        status: 1);
  } else {
    var error = JsError(exception.toString());
    attachJsStack(error, getTrace(exception) ?? stackTrace);
    return error;
  }
}

/// Parses `functions` from [RenderOptions] into a list of [Callable]s or
/// [AsyncCallable]s.
///
/// This is typed to always return [AsyncCallable], but in practice it will
/// return a `List<Callable>` if [asynch] is `false`.
List<AsyncCallable> _parseFunctions(RenderOptions options, DateTime start,
    {bool asynch = false}) {
  var functions = options.functions;
  if (functions == null) return const [];

  var result = <AsyncCallable>[];
  jsForEach(functions, (signature, callback) {
    Tuple2<String, ArgumentDeclaration> tuple;
    try {
      tuple = ScssParser(signature).parseSignature();
    } on SassFormatException catch (error, stackTrace) {
      throwWithTrace(
          SassFormatException(
              'Invalid signature "$signature": ${error.message}', error.span),
          stackTrace);
    }

    var context = RenderContext(options: _contextOptions(options, start));
    context.options.context = context;

    var fiber = options.fiber;
    if (fiber != null) {
      result.add(BuiltInCallable.parsed(tuple.item1, tuple.item2, (arguments) {
        var currentFiber = fiber.current;
        var jsArguments = [
          ...arguments.map(wrapValue),
          allowInterop(([Object? result]) {
            // Schedule a microtask so we don't try to resume the running fiber
            // if [importer] calls `done()` synchronously.
            scheduleMicrotask(() => currentFiber.run(result));
          })
        ];
        var result = (callback as JSFunction).apply(context, jsArguments);
        return unwrapValue(isUndefined(result)
            // Run `fiber.yield()` in runZoned() so that Dart resets the current
            // zone once it's done. Otherwise, interweaving fibers can leave
            // `Zone.current` in an inconsistent state.
            ? runZoned(() => fiber.yield())
            : result);
      }));
    } else if (!asynch) {
      result.add(BuiltInCallable.parsed(
          tuple.item1,
          tuple.item2,
          (arguments) => unwrapValue((callback as JSFunction)
              .apply(context, arguments.map(wrapValue).toList()))));
    } else {
      result.add(AsyncBuiltInCallable.parsed(tuple.item1, tuple.item2,
          (arguments) async {
        var completer = Completer<Object?>();
        var jsArguments = [
          ...arguments.map(wrapValue),
          allowInterop(([Object? result]) => completer.complete(result))
        ];
        var result = (callback as JSFunction).apply(context, jsArguments);
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
  } else if (options.importer is List<Object?>) {
    importers = (options.importer as List<Object?>).cast();
  } else {
    importers = [options.importer as JSFunction];
  }

  var contextOptions =
      importers.isNotEmpty ? _contextOptions(options, start) : Object();

  var fiber = options.fiber;
  if (fiber != null) {
    importers = importers.map((importer) {
      return allowInteropCaptureThis(
          (Object thisArg, String url, String previous, [Object? _]) {
        var currentFiber = fiber.current;
        var result = call3(importer, thisArg, url, previous,
            allowInterop((Object result) {
          // Schedule a microtask so we don't try to resume the running fiber if
          // [importer] calls `done()` synchronously.
          scheduleMicrotask(() => currentFiber.run(result));
        }));

        // Run `fiber.yield()` in runZoned() so that Dart resets the current
        // zone once it's done. Otherwise, interweaving fibers can leave
        // `Zone.current` in an inconsistent state.
        if (isUndefined(result)) return runZoned(() => fiber.yield());
        return result;
      }) as JSFunction;
    }).toList();
  }

  var includePaths = List<String>.from(options.includePaths ?? []);
  return NodeImporter(contextOptions, includePaths, importers);
}

/// Creates the [RenderContextOptions] for the `this` context in which custom
/// functions and importers will be evaluated.
RenderContextOptions _contextOptions(RenderOptions options, DateTime start) {
  var includePaths = List<String>.from(options.includePaths ?? []);
  return RenderContextOptions(
      file: options.file,
      data: options.data,
      includePaths: ([p.current, ...includePaths]).join(isWindows ? ';' : ':'),
      precision: SassNumber.precision,
      style: 1,
      indentType: options.indentType == 'tab' ? 1 : 0,
      indentWidth: _parseIndentWidth(options.indentWidth) ?? 2,
      linefeed: _parseLineFeed(options.linefeed).text,
      result: RenderContextResult(
          stats: RenderContextResultStats(
              start: start.millisecondsSinceEpoch,
              entry: options.file ?? 'data')));
}

/// Parse [style] into an [OutputStyle].
OutputStyle _parseOutputStyle(String? style) {
  if (style == null || style == 'expanded') return OutputStyle.expanded;
  if (style == 'compressed') return OutputStyle.compressed;
  throw ArgumentError('Unsupported output style "$style".');
}

/// Parses the indentation width into an [int].
int? _parseIndentWidth(Object? width) {
  if (width == null) return null;
  return width is int ? width : int.parse(width.toString());
}

/// Parses the name of a line feed type into a [LineFeed].
LineFeed _parseLineFeed(String? str) {
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
  var end = DateTime.now();

  var css = result.css;
  Uint8List? sourceMapBytes;
  if (_enableSourceMaps(options)) {
    var sourceMapOption = options.sourceMap;
    var sourceMapPath =
        sourceMapOption is String ? sourceMapOption : options.outFile! + '.map';
    var sourceMapDir = p.dirname(sourceMapPath);

    var sourceMap = result.sourceMap!;
    sourceMap.sourceRoot = options.sourceMapRoot;
    var outFile = options.outFile;
    if (outFile == null) {
      var file = options.file;
      if (file == null) {
        sourceMap.targetUrl = 'stdin.css';
      } else {
        sourceMap.targetUrl = p.toUri(p.setExtension(file, '.css')).toString();
      }
    } else {
      sourceMap.targetUrl =
          p.toUri(p.relative(outFile, from: sourceMapDir)).toString();
    }

    var sourceMapDirUrl = p.toUri(sourceMapDir).toString();
    for (var i = 0; i < sourceMap.urls.length; i++) {
      var source = sourceMap.urls[i];
      if (source == "stdin") continue;

      // URLs handled by Node importers that directly return file contents are
      // preserved in their original (usually relative) form. They may or may
      // not be intended as `file:` URLs, but there's nothing we can do about it
      // either way so we keep them as-is.
      if (p.url.isRelative(source) || p.url.isRootRelative(source)) continue;
      sourceMap.urls[i] = p.url.relative(source, from: sourceMapDirUrl);
    }

    var json = sourceMap.toJson(
        includeSourceContents: isTruthy(options.sourceMapContents));
    sourceMapBytes = utf8Encode(jsonEncode(json));

    if (!isTruthy(options.omitSourceMapUrl)) {
      var url = isTruthy(options.sourceMapEmbed)
          ? Uri.dataFromBytes(sourceMapBytes, mimeType: "application/json")
          : p.toUri(outFile == null
              ? sourceMapPath
              : p.relative(sourceMapPath, from: p.dirname(outFile)));
      css += "\n\n/*# sourceMappingURL=$url */";
    }
  }

  return RenderResult(
      css: utf8Encode(css),
      map: sourceMapBytes,
      stats: RenderResultStats(
          entry: options.file ?? 'data',
          start: start.millisecondsSinceEpoch,
          end: end.millisecondsSinceEpoch,
          duration: end.difference(start).inMilliseconds,
          includedFiles: [
            for (var url in result.loadedUrls)
              if (url.scheme == 'file') p.fromUri(url) else url.toString()
          ]));
}

/// Returns whether source maps are enabled by [options].
bool _enableSourceMaps(RenderOptions options) =>
    options.sourceMap is String ||
    (isTruthy(options.sourceMap) && options.outFile != null);

/// Creates a [JsError] with the given fields added to it so it acts like a Node
/// Sass error.
JsError _newRenderError(String message, StackTrace stackTrace,
    {int? line, int? column, String? file, int? status}) {
  var error = JsError(message);
  setProperty(error, 'formatted', 'Error: $message');
  if (line != null) setProperty(error, 'line', line);
  if (column != null) setProperty(error, 'column', column);
  if (file != null) setProperty(error, 'file', file);
  if (status != null) setProperty(error, 'status', status);
  attachJsStack(error, stackTrace);
  return error;
}
