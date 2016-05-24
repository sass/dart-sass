// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import 'ast/expression/interpolation.dart';
import 'ast/expression.dart';

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
    if (_text.isNotEmpty) {
      _contents.add(_text.toString());
      _text.clear();
    }
    _contents.add(expression);
  }

  InterpolationExpression interpolation([SourceSpan span]) {
    var contents = _contents.toList();
    if (_text.isNotEmpty) contents.add(_text.toString());
    return new InterpolationExpression(contents, span: span);
  }
}
