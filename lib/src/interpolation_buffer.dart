// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'ast/sass/expression.dart';
import 'ast/sass/statement.dart';

class InterpolationBuffer implements StringSink {
  final _text = new StringBuffer();

  final _contents = [];

  bool get isEmpty => _contents.isEmpty && _text.isEmpty;

  void clear() {
    _contents.clear();
    _text.clear();
  }

  void write(Object obj) => _text.write(obj);
  void writeAll(Iterable<Object> objects, [String separator = '']) =>
      _text.writeAll(objects, separator);
  void writeCharCode(int character) => _text.writeCharCode(character);
  void writeln([Object obj = '']) => _text.writeln(obj);

  void add(Expression expression) {
    _flushText();
    _contents.add(expression);
  }

  void addInterpolation(Interpolation expression) {
    if (expression.contents.isEmpty) return;

    var toAdd = expression.contents;
    var first = expression.contents.first;
    if (first is String) {
      _text.write(first);
      toAdd = expression.contents.skip(1);
    }

    _flushText();
    _contents.addAll(toAdd);
    if (_contents.last is String) _text.write(_contents.removeLast());
  }

  void _flushText() {
    if (_text.isEmpty) return;
    _contents.add(_text.toString());
    _text.clear();
  }

  Interpolation interpolation([FileSpan span]) {
    var contents = _contents.toList();
    if (_text.isNotEmpty) contents.add(_text.toString());
    return new Interpolation(contents, span: span);
  }

  String toString() => "${_contents.join('')}$_text";
}
