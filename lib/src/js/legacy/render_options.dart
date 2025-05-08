// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';
import 'dart:async';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'package:path/path.dart' as p;

import '../../async_import_cache.dart';
import '../../callable.dart';
import '../../import_cache.dart';
import '../../importer/legacy_node.dart';
import '../../importer/node_package.dart';
import '../../syntax.dart';
import '../../util/nullable.dart';
import '../../visitor/serialize.dart';
import '../shared_options.dart';
import 'render_context.dart';
import 'value.dart';

extension type RenderOptions._(JSObject _) implements SharedOptions {
  String? get file => rawFile.andThen(p.absolute) ?? rawFile;

  @JS('file')
  external String? get rawFile;

  external String? get data;

  @JS('importer')
  external JSObject? get _importer;

  @JS('pkgImporter')
  external UnsafeDartWrapper<NodePackageImporter>? get _pkgImporter;

  /// Creates a synchronous [ImportCache] that wraps the package importer, if
  /// the options define one.
  ImportCache? get pkgImporterCache =>
      _pkgImporter.andThen((importer) => ImportCache.only([importer.toDart]));

  /// Creates an [AsyncImportCache] that wraps the package importer, if the
  /// options define one.
  AsyncImportCache? get pkgImporterAsyncCache => _pkgImporter
      .andThen((importer) => AsyncImportCache.only([importer.toDart]));

  @JS('functions')
  external JSRecord<JSFunction>? get _functions;

  external JSArray<JSString>? get includePaths;

  Syntax? get syntax => _indentedSyntax.isTruthy.toDart ? Syntax.sass : null;

  @JS('indentedSyntax')
  external JSBoolean? get _indentedSyntax;

  bool get omitSourceMapUrl => _omitSourceMapUrl.isTruthy.toDart;

  @JS('omitSourceMapUrl')
  external JSBoolean? get _omitSourceMapUrl;

  external String? get outFile;

  @JS('outputStyle')
  external String? get _outputStyle;
  OutputStyle get outputStyle => switch (_outputStyle) {
        null || 'expanded' => OutputStyle.expanded,
        'compressed' => OutputStyle.compressed,
        _ =>
          JSError.throwLikeJS(JSError('Unknown output style "$_outputStyle".')),
      };

  bool get useSpaces => _indentType != 'tab';

  @JS('indentType')
  external String? get _indentType;

  @JS('indentWidth')
  external JSAny? get _indentWidth;
  int? get indentWidth => switch (_indentWidth) {
        null => null,
        int width => width,
        var width => int.parse(width.toString()),
      };

  @JS('linefeed')
  external String? get _lineFeed;
  LineFeed get lineFeed => switch (_lineFeed) {
        'cr' => LineFeed.cr,
        'crlf' => LineFeed.crlf,
        'lfcr' => LineFeed.lfcr,
        _ => LineFeed.lf,
      };

  external JSAny? get sourceMap;
  external String? get sourceMapRoot;

  bool get sourceMapContents => _sourceMapContents.isTruthy.toDart;

  @JS('sourceMapContents')
  external JSBoolean? get _sourceMapContents;

  bool get sourceMapEmbed => _sourceMapEmbed.isTruthy.toDart;

  @JS('sourceMapEmbed')
  external JSBoolean? get _sourceMapEmbed;

  /// Whether these options enable source maps.
  bool get enableSourceMaps =>
      sourceMap is String || (sourceMap.isTruthy.toDart && outFile != null);

  factory RenderOptions() => RenderOptions._(JSObject());

  /// Returns the [NodeImporter] that handles imports according to these
  /// options.
  NodeImporter importer(DateTime start) {
    var importers = switch (_importer) {
      null => <JSFunction>[],
      JSArray importers => importers.toDart.cast<JSFunction>(),
      var importer => [importer as JSFunction],
    };
    return NodeImporter(
        importers.isNotEmpty ? RenderContextOptions(this, start) : JSObject(),
        List<String>.from(includePaths?.toDart ?? []),
        importers);
  }

  /// returns the list of [Callable]s or [AsyncCallable]s for functions defined by
  /// these options.
  ///
  /// This is typed to always return [AsyncCallable], but in practice it will
  /// return a `List<Callable>` if [asynch] is `false`.
  List<AsyncCallable> functions(
    DateTime start, {
    bool asynch = false,
  }) {
    var functions = _functions;
    if (functions == null) return const [];

    var result = <AsyncCallable>[];
    for (var (signature, callback) in functions.pairs) {
      var context = RenderContext(RenderContextOptions(this, start));

      if (!asynch) {
        result.add(
          Callable.fromSignature(
            signature.trimLeft(),
            (arguments) => (callback.callAsFunctionVarArgs(
              context,
              [for (var argument in arguments) argument.toJSLegacy],
            ) as JSLegacyValue)
                .toDart,
            requireParens: false,
          ),
        );
      } else {
        result.add(
          AsyncCallable.fromSignature(signature.trimLeft(), (arguments) async {
            var completer = Completer<JSLegacyValue>();
            var jsArguments = [
              for (var argument in arguments) argument.toJSLegacy,
              (([JSLegacyValue? result]) => result == null
                  ? completer.completeError(
                      "done() callback must be passed an argument.",
                      StackTrace.current)
                  : completer.complete(result)).toJS,
            ];

            var result = callback.callAsFunctionVarArgs(context, jsArguments)
                as JSLegacyValue?;
            return (result.isUndefined ? await completer.future : result!)
                .toDart;
          }, requireParens: false),
        );
      }
    }
    return result;
  }
}
