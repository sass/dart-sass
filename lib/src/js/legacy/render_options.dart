// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import '../../util/nullable.dart';
import '../hybrid/node_importer.dart';
import '../logger.dart';
import '../shared_options.dart';

@anonymous
extension type RenderOptions._(SharedOptions _) implements SharedOptions {
  external String? get file;
  external String? get data;

  @JS('importer')
  external JSObject? get _importer;

  @JS('pkgImporter')
  external JSNodePackageImporter? get _pkgImporter;

  /// Creates a synchronous [ImportCache] that wraps the package importer, if
  /// the options define one.
  ImportCache? get pkgImporterCache => _pkgImporter.andThen((importer) => ImportCache.only([importer.toDart])),

  /// Creates an [AsyncImportCache] that wraps the package importer, if the
  /// options define one.
  ImportCache? get pkgImporterAsyncCache => _pkgImporter.andThen((importer) => AsyncImportCache.only([importer.toDart])),

  @JS('functions')
  external JSRecord<JSFunction>? get _functions;

  external JSArray<String>? get includePaths;
  external bool? get indentedSyntax;
  external bool? get omitSourceMapUrl;
  external String? get outFile;

  @JS('outputStyle')
  external String? get _outputStyle;
  OutputStyle get outputStyle => switch (_outputStyle) {
      null || 'expanded' => OutputStyle.expanded,
      'compressed' => OutputStyle.compressed,
      _ => JSError.throwLikeJS(JSError('Unknown output style "$_outputStyle".')),
    };

  external String? get indentType;

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
  external bool? get sourceMapContents;
  external bool? get sourceMapEmbed;
  external String? get sourceMapRoot;

/// Whether these options enable source maps.
bool get enableSourceMaps =>
    sourceMap is String ||
    (options.sourceMap.isTruthy && options.outFile != null);

  external factory RenderOptions();

  /// Returns the [NodeImporter] that handles imports according to these
  /// options.
  NodeImporter importer(DateTime start) => NodeImporter(importers.isNotEmpty ? RenderContextOptions(this, start) : JSObject(), List<String>.from(includePaths ?? []), switch (_importer) {
    null => <JSFunction>[],
    JSArray importers => importers.toDart.cast<JSFunction>(),
    var importer => [importer as JSFunction],
  });

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
  for (var (signature, callback) of functions.pairs) {
    var context = RenderContext(RenderContextOptions(options, start));

    if (!asynch) {
      result.add(
        Callable.fromSignature(
          signature.trimLeft(),
          (arguments) => 
            wrapJSExceptions(
              () => callback.callAsFunctionVarArgs(
                context,
                [for (var argument in arguments) argument.toJSLegacy],
              ) as JSLegacyValue,
            ).toDart,
          requireParens: false,
        ),
      );
    } else {
      result.add(
        AsyncCallable.fromSignature(signature.trimLeft(), (arguments) async {
          var completer = Completer<JSLegacyValue>();
          var jsArguments = [
            for (var argument in arguments) argument.toJSLegacy,
            ((JSLegacyValue result) => completer.complete(result)).toJS,
          ];
          var result = wrapJSExceptions(
            () => callback.callAsFunctionVarArgs(context, jsArguments) as JSLegacyValue,
          );
          return (
            result.isUndefined ? await completer.future : result,
          ).toDart;
        }, requireParens: false),
      );
    }
  }
  return result;
}
}
