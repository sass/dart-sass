// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';

import 'source_map_buffer.dart';

/// A [SourceMapBuffer] that doesn't actually build a source map.
class NoSourceMapBuffer implements SourceMapBuffer {
  /// The buffer that contains the text of the target file.
  final _buffer = new StringBuffer();

  bool get isEmpty => _buffer.isEmpty;
  bool get isNotEmpty => _buffer.isNotEmpty;
  int get length => _buffer.length;
  Map<String, SourceFile> get sourceFiles => const {};

  T forSpan<T>(SourceSpan span, T callback()) => callback();
  void write(Object object) => _buffer.write(object);
  void writeAll(Iterable objects, [String separator = ""]) =>
      _buffer.writeAll(objects, separator);
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);
  void writeln([Object object = ""]) => _buffer.writeln(object);
  String toString() => _buffer.toString();

  void clear() =>
      throw new UnsupportedError("SourceMapBuffer.clear() is not supported.");

  SingleMapping buildSourceMap({String prefix}) => throw new UnsupportedError(
      "NoSourceMapBuffer.buildSourceMap() is not supported.");
}
