// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// An attribute selector.
///
/// This selects for elements with the given attribute, and optionally with a
/// value matching certain conditions as well.
class AttributeSelector extends SimpleSelector {
  /// The name of the attribute being selected for.
  final QualifiedName name;

  /// The operator that defines the semantics of [value].
  ///
  /// If this is `null`, this matches any element with the given property,
  /// regardless of this value. It's `null` if and only if [value] is `null`.
  final AttributeOperator op;

  /// An assertion about the value of [name].
  ///
  /// The precise semantics of this string are defined by [op].
  ///
  /// If this is `null`, this matches any element with the given property,
  /// regardless of this value. It's `null` if and only if [op] is `null`.
  final String value;

  /// Creates an attribute selector that matches any element with a property of
  /// the given name.
  AttributeSelector(this.name)
      : op = null,
        value = null;

  /// Creates an attribute selector that matches an element with a property
  /// named [name], whose value matches [value] based on the semantics of [op].
  AttributeSelector.withOperator(this.name, this.op, this.value);

  T accept<T>(SelectorVisitor<T> visitor) =>
      visitor.visitAttributeSelector(this);

  bool operator ==(other) =>
      other is AttributeSelector &&
      other.name == name &&
      other.op == op &&
      other.value == value;

  int get hashCode => name.hashCode ^ op.hashCode ^ value.hashCode;
}

/// An operator that defines the semantics of an [AttributeSelector].
class AttributeOperator {
  /// The attribute value exactly equals the given value.
  static const equal = const AttributeOperator._("=");

  /// The attribute value is a whitespace-separated list of words, one of which
  /// is the given value.
  static const include = const AttributeOperator._("~=");

  /// The attribute value is either exactly the given value, or starts with the
  /// given value followed by a dash.
  static const dash = const AttributeOperator._("|=");

  /// The attribute value begins with the given value.
  static const prefix = const AttributeOperator._("^=");

  /// The attribute value ends with the given value.
  static const suffix = const AttributeOperator._("\$=");

  /// The attribute value contains the given value.
  static const substring = const AttributeOperator._("*=");

  /// The operator's token text.
  final String _text;

  const AttributeOperator._(this._text);

  String toString() => _text;
}
