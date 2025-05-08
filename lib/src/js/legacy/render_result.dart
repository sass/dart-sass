// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';
import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:node_interop/node_interop.dart';
import 'package:path/path.dart' as p;

import '../../compile_result.dart';
import 'render_options.dart';

extension type RenderResult._wrap(JSObject _) implements JSObject {
  external JSUint8Array get css;
  external JSUint8Array? get map;
  external RenderResultStats get stats;

  external RenderResult._({
    required JSUint8Array css,
    JSUint8Array? map,
    required RenderResultStats stats,
  });

  factory RenderResult(
    RenderOptions options,
    CompileResult result,
    DateTime start,
  ) {
    var end = DateTime.now();

    var css = result.css;
    JSUint8Array? sourceMapBytes;
    if (options.enableSourceMaps) {
      var sourceMapOption = options.sourceMap;
      var sourceMapPath = sourceMapOption.isA<JSString>()
          ? (sourceMapOption as JSString).toDart
          : options.outFile! + '.map';
      var sourceMapDir = p.dirname(sourceMapPath);

      var sourceMap = result.sourceMap!;
      sourceMap.sourceRoot = options.sourceMapRoot;
      var outFile = options.outFile;
      if (outFile == null) {
        sourceMap.targetUrl = switch (options.file) {
          var file? => p.toUri(p.setExtension(file, '.css')).toString(),
          _ => sourceMap.targetUrl = 'stdin.css',
        };
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
        includeSourceContents: options.sourceMapContents,
      );
      sourceMapBytes = Buffer.fromString(jsonEncode(json), 'utf8');

      if (!options.omitSourceMapUrl) {
        var url = options.sourceMapEmbed
            ? Uri.dataFromBytes(sourceMapBytes.toDart,
                mimeType: "application/json")
            : p.toUri(
                outFile == null
                    ? sourceMapPath
                    : p.relative(sourceMapPath, from: p.dirname(outFile)),
              );
        var escapedUrl = url.toString().replaceAll("*/", '%2A/');
        css += "\n\n/*# sourceMappingURL=$escapedUrl */";
      }
    }

    return RenderResult._(
      css: Buffer.fromString(css, 'utf8'),
      map: sourceMapBytes ?? undefined,
      stats: RenderResultStats(
        entry: options.rawFile ?? 'data',
        start: start.millisecondsSinceEpoch,
        end: end.millisecondsSinceEpoch,
        duration: end.difference(start).inMilliseconds,
        includedFiles: [
          for (var url in result.loadedUrls)
            url.scheme == 'file' ? p.fromUri(url) : url.toString(),
        ].toJS,
      ),
    );
  }
}

extension type RenderResultStats._(JSObject _) implements JSObject {
  external String get entry;
  external int get start;
  external int get end;
  external int get duration;
  external JSArray<JSString> get includedFiles;

  external RenderResultStats({
    required String entry,
    required int start,
    required int end,
    required int duration,
    required JSArray<JSString> includedFiles,
  });
}
