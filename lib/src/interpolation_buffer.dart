// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import 'ast/sass.dart';

/// A buffer that iteratively builds up an [Interpolation].
///
/// Add text using [write] and related methods, and [Expression]s using [add].
/// Once that's done, call [interpolation] to build the result.
class InterpolationBuffer implements StringSink {
  /// The buffer that accumulates plain text.
  final _text = new StringBuffer();

  /// The contents of the [Interpolation] so far.
  ///
  /// This contains [String]s and [Expression]s.
  final _contents = [];

  /// Returns whether this buffer has no contents.
  bool get isEmpty => _contents.isEmpty && _text.isEmpty;

  /// Returns the substring of the buffer string after the last interpolation.
  String get trailingString => _text.toString();

  /// Empties this buffer.
  void clear() {
    _contents.clear();
    _text.clear();
  }

  void write(Object obj) => _text.write(obj);
  void writeAll(Iterable<Object> objects, [String separator = '']) =>
      _text.writeAll(objects, separator);
  void writeCharCode(int character) => _text.writeCharCode(character);
  void writeln([Object obj = '']) => _text.writeln(obj);

  /// Adds [expression] to this buffer.
  void add(Expression expression) {
    _flushText();
    _contents.add(expression);
  }

  /// Adds the contents of [interpolation] to this buffer.
  void addInterpolation(Interpolation interpolation) {
    if (interpolation.contents.isEmpty) return;

    Iterable toAdd = interpolation.contents;
    var first = interpolation.contents.first;
    if (first is String) {
      _text.write(first);
      toAdd = interpolation.contents.skip(1);
    }

    _flushText();
    _contents.addAll(toAdd);
    if (_contents.last is String) _text.write(_contents.removeLast());
  }

  /// Flushes [_text] to [_contents] if necessary.
  void _flushText() {
    if (_text.isEmpty) return;
    _contents.add(_text.toString());
    _text.clear();
  }

  /// Creates an [Interpolation] with the given [span] from the contents of this
  /// buffer.
  Interpolation interpolation(FileSpan span) {
    var contents = _contents.toList();
    if (_text.isNotEmpty) contents.add(_text.toString());
    return new Interpolation(contents, span);
  }

  String toString() {
    var buffer = new StringBuffer();
    for (var element in _contents) {
      if (element is String) {
        buffer.write(element);
      } else {
        buffer.write("#{");
        buffer.write(element);
        buffer.writeCharCode($rbrace);
      }
    }
    buffer.write(_text);
    return buffer.toString();
  }
}
