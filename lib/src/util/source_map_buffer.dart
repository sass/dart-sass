// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:source_maps/source_maps.dart';
import 'package:source_span/source_span.dart';

import '../utils.dart';

/// A [StringBuffer] that builds a [SourceMap] for the file being written.
class SourceMapBuffer implements StringBuffer {
  /// The buffer that contains the text of the target file.
  final _buffer = new StringBuffer();

  /// The source map entries that map the source files to [_buffer].
  final _entries = <Entry>[];

  /// A map from source file URLs to the corresponding [SourceFile]s.
  ///
  /// This is of a form that can be passed to [Mapping.spanFor].
  Map<String, SourceFile> get sourceFiles => new UnmodifiableMapView(
      mapMap(_sourceFiles, key: (url, _) => url.toString()));
  final _sourceFiles = <Uri, SourceFile>{};

  /// The index of the current line in [_buffer].
  var _line = 0;

  /// The index of the current column in [_buffer].
  var _column = 0;

  /// Whether the text currently being written should be encompassed by a
  /// [SourceSpan].
  var _inSpan = false;

  /// The current location in [_buffer].
  SourceLocation get _targetLocation =>
      new SourceLocation(_buffer.length, line: _line, column: _column);

  bool get isEmpty => _buffer.isEmpty;
  bool get isNotEmpty => _buffer.isNotEmpty;
  int get length => _buffer.length;

  /// Runs [callback] and associates all text written within it with [span].
  ///
  /// Specifically, this associates the point at the beginning of the written
  /// text with [span.start] and the point at the end of the written text with
  /// [span.end].
  T forSpan<T>(FileSpan span, T callback()) {
    var wasInSpan = _inSpan;
    _inSpan = true;
    _addEntry(span.start, _targetLocation);
    try {
      return callback();
    } finally {
      // We could map [span.end] to [_targetLocation] here, but in practice
      // browsers don't care about where a span ends as long as it covers at
      // least the entity that they're looking up. Avoiding end mappings halves
      // the size of the source maps we generate.

      _inSpan = wasInSpan;
    }
  }

  /// Adds an entry to [_entries] unless it's redundant with the last entry.
  void _addEntry(FileLocation source, SourceLocation target) {
    if (_entries.isNotEmpty) {
      var entry = _entries.last;

      // Browsers don't care about the position of a value within a line, so
      // it's redundant to have two entries on the same target line that both
      // point to the same source line, even if they point to different
      // columns in that line.
      if (entry.source.line == source.line &&
          entry.target.line == target.line) {
        return;
      }

      // Since source maps are only used to look up the source from the target
      // and not vice versa, we don't need multiple mappings to the same target.
      if (entry.target.offset == target.offset) return;
    }

    _sourceFiles.putIfAbsent(source.sourceUrl, () => source.file);
    _entries.add(new Entry(source, target, null));
  }

  void clear() =>
      throw new UnsupportedError("SourceMapBuffer.clear() is not supported.");

  void write(Object object) {
    var string = object.toString();
    _buffer.write(string);

    for (var i = 0; i < string.length; i++) {
      if (string.codeUnitAt(i) == $lf) {
        _writeLine();
      } else {
        _column++;
      }
    }
  }

  void writeAll(Iterable objects, [String separator = ""]) =>
      write(objects.join(separator));

  void writeCharCode(int charCode) {
    _buffer.writeCharCode(charCode);
    if (charCode == $lf) {
      _writeLine();
    } else {
      _column++;
    }
  }

  void writeln([Object object = ""]) {
    // Special-case the common case.
    if (identical(object, "")) {
      _buffer.writeln();
      _writeLine();
      return;
    }

    var string = object.toString();
    _buffer.writeln(string);

    var newlines = countOccurrences(string, $lf) + 1;
    for (var i = 0; i < newlines; i++) {
      _writeLine();
    }
  }

  /// Records that a line has been passed.
  ///
  /// If we're in the middle of a source span, indicate that at the beginning of
  /// the new line. This is necessary because source maps consider each line
  /// separately.
  void _writeLine() {
    // Trim useless entries.
    if (_entries.last.target.line == _line &&
        _entries.last.target.column == _column) {
      _entries.removeLast();
    }

    _line++;
    _column = 0;
    if (_inSpan) {
      _entries.add(new Entry(_entries.last.source, _targetLocation, null));
    }
  }

  String toString() => _buffer.toString();

  /// Returns the source map for the file being written.
  ///
  /// If [prefix] is passed, all the entries in the source map will be moved
  /// forward by the number of characters and lines in [prefix].
  ///
  /// [SingleMapping.targetUrl] will be `null`.
  SingleMapping buildSourceMap({String prefix}) {
    if (prefix == null || prefix.isEmpty) {
      return new SingleMapping.fromEntries(_entries);
    }

    var prefixLength = prefix.length;
    var prefixLines = 0;
    var prefixColumn = 0;
    for (var i = 0; i < prefix.length; i++) {
      if (prefix.codeUnitAt(i) == $lf) {
        prefixLines++;
        prefixColumn = 0;
      } else {
        prefixColumn++;
      }
    }

    return new SingleMapping.fromEntries(_entries.map((entry) => new Entry(
        entry.source,
        new SourceLocation(entry.target.offset + prefixLength,
            line: entry.target.line + prefixLines,
            // Only adjust the column for entries that are on the same line as
            // the last chunk of the prefix.
            column: entry.target.column +
                (entry.target.line == 0 ? prefixColumn : 0)),
        entry.identifierName)));
  }
}
