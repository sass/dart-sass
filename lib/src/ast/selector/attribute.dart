// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../selector.dart';

class AttributeSelector extends SimpleSelector {
  final NamespacedIdentifier name;

  final AttributeOperator op;

  final String value;

  final FileSpan span;

  AttributeSelector(this.name, {this.span})
      : op = null,
        value = null;

  AttributeSelector.withOperator(this.name, this.op, this.value, {this.span});

  String toString() {
    if (op == null) return name.toString();
    // TODO: if [value] isn't an identifier, quote it.
    return "[$name$op$value]";
  }
}

class AttributeOperator {
  static const equal = const AttributeOperator._("=");
  static const include = const AttributeOperator._("~=");
  static const dash = const AttributeOperator._("|=");
  static const prefix = const AttributeOperator._("^=");
  static const suffix = const AttributeOperator._("\$=");
  static const substring = const AttributeOperator._("*=");

  final String _text;

  const AttributeOperator._(this._text);

  String toString() => _text;
}
