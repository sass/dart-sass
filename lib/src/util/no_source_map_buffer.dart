// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';

import 'source_map_buffer.dart';

/// A [SourceMapBuffer] that doesn't actually build a source map.
class NoSourceMapBuffer implements SourceMapBuffer {
  /// The buffer that contains the text of the target file.
  final _buffer = StringBuffer();

  @override
  bool get isEmpty => _buffer.isEmpty;

  @override
  bool get isNotEmpty => _buffer.isNotEmpty;

  @override
  int get length => _buffer.length;

  @override
  T forSpan<T>(SourceSpan span, T Function() callback) => callback();

  @override
  void write(Object? object) => _buffer.write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = ""]) =>
      _buffer.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _buffer.writeCharCode(charCode);

  @override
  void writeln([Object? object = ""]) => _buffer.writeln(object);

  @override
  String toString() => _buffer.toString();

  @override
  void clear() =>
      throw UnsupportedError("SourceMapBuffer.clear() is not supported.");

  @override
  SingleMapping buildSourceMap({String? prefix}) => throw UnsupportedError(
        "NoSourceMapBuffer.buildSourceMap() is not supported.",
      );
}
