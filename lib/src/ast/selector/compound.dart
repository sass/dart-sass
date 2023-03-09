// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../extend/functions.dart';
import '../../logger.dart';
import '../../parse/selector.dart';
import '../../utils.dart';
import '../../visitor/interface/selector.dart';
import '../selector.dart';

/// A compound selector.
///
/// A compound selector is composed of [SimpleSelector]s. It matches an element
/// that matches all of the component simple selectors.
///
/// {@category AST}
/// {@category Parsing}
@sealed
class CompoundSelector extends Selector {
  /// The components of this selector.
  ///
  /// This is never empty.
  final List<SimpleSelector> components;

  /// This selector's specificity.
  ///
  /// Specificity is represented in base 1000. The spec says this should be
  /// "sufficiently high"; it's extremely unlikely that any single selector
  /// sequence will contain 1000 simple selectors.
  late final int specificity =
      components.fold(0, (sum, component) => sum + component.specificity);

  /// If this compound selector is composed of a single simple selector, returns
  /// it.
  ///
  /// Otherwise, returns null.
  ///
  /// @nodoc
  @internal
  SimpleSelector? get singleSimple =>
      components.length == 1 ? components.first : null;

  CompoundSelector(Iterable<SimpleSelector> components, FileSpan span)
      : components = List.unmodifiable(components),
        super(span) {
    if (this.components.isEmpty) {
      throw ArgumentError("components may not be empty.");
    }
  }

  /// Parses a compound selector from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  /// [allowParent] controls whether a [ParentSelector] is allowed in this
  /// selector.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory CompoundSelector.parse(String contents,
          {Object? url, Logger? logger, bool allowParent = true}) =>
      SelectorParser(contents,
              url: url, logger: logger, allowParent: allowParent)
          .parseCompoundSelector();

  T accept<T>(SelectorVisitor<T> visitor) =>
      visitor.visitCompoundSelector(this);

  /// Whether this is a superselector of [other].
  ///
  /// That is, whether this matches every element that [other] matches, as well
  /// as possibly additional elements.
  bool isSuperselector(CompoundSelector other) =>
      compoundIsSuperselector(this, other);

  int get hashCode => listHash(components);

  bool operator ==(Object other) =>
      other is CompoundSelector && listEquals(components, other.components);
}
