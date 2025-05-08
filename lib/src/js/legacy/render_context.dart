// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:path/path.dart' as p;

import '../../io.dart';
import '../../value/number.dart';
import 'render_options.dart';

extension type RenderContext._wrap(JSObject _) implements JSObject {
  external RenderContextOptions get options;
  external bool? get fromImport;

  external RenderContext._({
    required RenderContextOptions options,
    bool? fromImport,
  });

  factory RenderContext(RenderContextOptions options,
      {bool fromImport = false}) {
    var context = RenderContext._(options: options, fromImport: fromImport);
    context.options.context = context;
    return context;
  }
}

extension type RenderContextOptions._wrap(JSObject _) implements JSObject {
  external String? get file;
  external String? get data;
  external String get includePaths;
  external int get precision;
  external int get style;
  external int get indentType;
  external int get indentWidth;
  external String get linefeed;
  external RenderContext get context;
  external set context(RenderContext value);
  external RenderContextResult get result;

  external RenderContextOptions._({
    String? file,
    String? data,
    required String includePaths,
    required int precision,
    required int style,
    required int indentType,
    required int indentWidth,
    required String linefeed,
    required RenderContextResult result,
  });

  factory RenderContextOptions(RenderOptions options, DateTime start) {
    return RenderContextOptions._(
      file: options.file,
      data: options.data,
      includePaths: ([p.current, ...?options.includePaths?.toDart])
          .join(isWindows ? ';' : ':'),
      precision: SassNumber.precision,
      style: 1,
      indentType: options.useSpaces ? 0 : 1,
      indentWidth: options.indentWidth ?? 2,
      linefeed: options.lineFeed.text,
      result: RenderContextResult._(
        stats: RenderContextResultStats._(
          start: start.millisecondsSinceEpoch,
          entry: options.rawFile ?? 'data',
        ),
      ),
    );
  }
}

extension type RenderContextResult._wrap(JSObject _) implements JSObject {
  external RenderContextResultStats get stats;

  external RenderContextResult._({
    required RenderContextResultStats stats,
  });
}

extension type RenderContextResultStats._wrap(JSObject _) implements JSObject {
  external int get start;
  external String get entry;

  external RenderContextResultStats._({
    required int start,
    required String entry,
  });
}
