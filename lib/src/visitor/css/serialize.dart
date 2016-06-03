// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';

import '../../ast/css/node.dart';
import '../../util/character.dart';
import '../../utils.dart';
import '../../value.dart';
import '../css.dart';

String toCss(AstNode node) {
  var visitor = new _SerializeCssVisitor();
  node.accept(visitor);
  var result = visitor._buffer.toString();
  if (result.codeUnits.any((codeUnit) => codeUnit > 0x7F)) {
    result = '@charset "UTF-8";\n$result';
  }

  // TODO(nweiz): Do this in a way that's not O(n), maybe using a custom buffer
  // that's not append-only.
  return result.trim();
}

class _SerializeCssVisitor extends CssVisitor {
  final _buffer = new StringBuffer();

  var _indentation = 0;

  void visitStylesheet(CssStylesheet node) {
    for (var child in node.children) {
      child.accept(this);
      _buffer.writeln();
    }
  }

  void visitComment(CssComment node) {
    // TODO: format this at all
    _buffer.writeln(node.text);
  }

  void visitStyleRule(CssStyleRule node) {
    _writeIndentation();
    _buffer.write(node.selector.value);
    _buffer.writeCharCode($space);
    _buffer.writeCharCode($lbrace);
    _buffer.writeln();
    _indent(() {
      for (var child in node.children) {
        child.accept(this);
        _buffer.writeln();
      }
    });
    _writeIndentation();
    _buffer.writeCharCode($rbrace);

    // TODO: only add an extra newline if this is a group end
    _buffer.writeln();
  }

  void visitDeclaration(CssDeclaration node) {
    _writeIndentation();
    _buffer.write(node.name.value);
    _buffer.writeCharCode($colon);
    _buffer.writeCharCode($space);
    node.value.value.accept(this);
    _buffer.writeCharCode($semicolon);
  }

  void visitBoolean(SassBoolean value) => value.value.toString();

  void visitIdentifier(SassIdentifier value) =>
      value.text.replaceAll("\n", " ");

  void visitList(SassList value) {
    if (value.contents.isEmpty) throw "() isn't a valid CSS value";

    var separator = value.separator == ListSeparator.space ? " " : ", ";
    var first = true;
    for (var element in value.contents) {
      if (element.isBlank) continue;
      if (!first) _buffer.write(separator);
      first = false;
      element.accept(this);
    }
  }

  // TODO(nweiz): Support precision and don't support exponent notation.
  void visitNumber(SassNumber value) {
    _buffer.write(value.value.toString());
  }

  void visitString(SassString string) =>
      _buffer.write(_visitString(string.text));

  String _visitString(String string, {bool forceDoubleQuote: false}) {
    var includesSingleQuote = false;
    var includesDoubleQuote = false;
    var buffer = new StringBuffer();
    for (var i = 0; i < string.length; i++) {
      var char = string.codeUnitAt(i);
      switch (char) {
        case $single_quote:
          if (forceDoubleQuote) {
            buffer.writeCharCode($single_quote);
          } else if (includesDoubleQuote) {
            return _visitString(string, forceDoubleQuote: true);
          } else {
            includesSingleQuote = true;
            buffer.writeCharCode($single_quote);
          }
          break;

        case $double_quote:
          if (forceDoubleQuote) {
            buffer.writeCharCode($backslash);
            buffer.writeCharCode($double_quote);
          } else if (includesSingleQuote) {
            return _visitString(string, forceDoubleQuote: true);
          } else {
            includesDoubleQuote = true;
            buffer.writeCharCode($double_quote);
          }
          break;

        case $cr:
        case $lf:
        case $ff:
          buffer.writeCharCode($backslash);
          buffer.writeCharCode(hexCharFor(char));
          if (string.length == i + 1) break;

          var next = string.codeUnitAt(i + 1);
          if (isHex(next) || next == $space || next == $tab) {
            buffer.writeCharCode($space);
          }
          break;

        case $backslash:
          buffer.writeCharCode($backslash);
          buffer.writeCharCode($backslash);
          break;

        default:
          buffer.writeCharCode(char);
          break;
      }
    }

    var doubleQuote = forceDoubleQuote || !includesDoubleQuote;
    return doubleQuote ? '"$buffer"' : "'$buffer'";
  }

  num _round(num number) {
    if (number is double && (number.isInfinite || number.isNaN)) return number;
    if (almostEquals(number % 1, 0.0)) return number.round();
    return (number * 10 * SassNumber.precision).round() /
        (10 * SassNumber.precision);
  }

  void _writeIndentation() {
    for (var i = 0; i < _indentation; i++) {
      _buffer.writeCharCode($space);
      _buffer.writeCharCode($space);
    }
  }

  void _indent(void callback()) {
    _indentation++;
    callback();
    _indentation--;
  }
}
