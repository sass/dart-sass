// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// An attribute selector.
///
/// This selects for elements with the given attribute, and optionally with a
/// value matching certain conditions as well.
///
/// {@category AST}
final class AttributeSelector extends SimpleSelector {
  /// The name of the attribute being selected for.
  final QualifiedName name;

  /// The operator that defines the semantics of [value].
  ///
  /// If this is `null`, this matches any element with the given property,
  /// regardless of this value. It's `null` if and only if [value] is `null`.
  final AttributeOperator? op;

  /// An assertion about the value of [name].
  ///
  /// The precise semantics of this string are defined by [op].
  ///
  /// If this is `null`, this matches any element with the given property,
  /// regardless of this value. It's `null` if and only if [op] is `null`.
  final String? value;

  /// The modifier which indicates how the attribute selector should be
  /// processed.
  ///
  /// See for example [case-sensitivity][] modifiers.
  ///
  /// [case-sensitivity]: https://www.w3.org/TR/selectors-4/#attribute-case
  ///
  /// If [op] is `null`, this is always `null` as well.
  final String? modifier;

  /// Creates an attribute selector that matches any element with a property of
  /// the given name.
  AttributeSelector(this.name, FileSpan span)
      : op = null,
        value = null,
        modifier = null,
        super(span);

  /// Creates an attribute selector that matches an element with a property
  /// named [name], whose value matches [value] based on the semantics of [op].
  AttributeSelector.withOperator(
    this.name,
    this.op,
    this.value,
    FileSpan span, {
    this.modifier,
  }) : super(span);

  T accept<T>(SelectorVisitor<T> visitor) =>
      visitor.visitAttributeSelector(this);

  bool operator ==(Object other) =>
      other is AttributeSelector &&
      other.name == name &&
      other.op == op &&
      other.value == value &&
      other.modifier == modifier;

  int get hashCode =>
      name.hashCode ^ op.hashCode ^ value.hashCode ^ modifier.hashCode;
}

/// An operator that defines the semantics of an [AttributeSelector].
enum AttributeOperator {
  /// The attribute value exactly equals the given value.
  equal('='),

  /// The attribute value is a whitespace-separated list of words, one of which
  /// is the given value.
  include('~='),

  /// The attribute value is either exactly the given value, or starts with the
  /// given value followed by a dash.
  dash('|='),

  /// The attribute value begins with the given value.
  prefix('^='),

  /// The attribute value ends with the given value.
  suffix('\$='),

  /// The attribute value contains the given value.
  substring('*=');

  /// The operator's token text.
  final String _text;

  const AttributeOperator(this._text);

  String toString() => _text;
}
