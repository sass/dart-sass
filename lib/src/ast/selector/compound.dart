// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

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
class CompoundSelector extends Selector implements ComplexSelectorComponent {
  /// The components of this selector.
  ///
  /// This is never empty.
  final List<SimpleSelector> components;

  /// The minimum possible specificity that this selector can have.
  ///
  /// Pseudo selectors that contain selectors, like `:not()` and `:matches()`,
  /// can have a range of possible specificities.
  int get minSpecificity {
    if (_minSpecificity == null) _computeSpecificity();
    return _minSpecificity;
  }

  int _minSpecificity;

  /// The maximum possible specificity that this selector can have.
  ///
  /// Pseudo selectors that contain selectors, like `:not()` and `:matches()`,
  /// can have a range of possible specificities.
  int get maxSpecificity {
    if (_maxSpecificity == null) _computeSpecificity();
    return _maxSpecificity;
  }

  int _maxSpecificity;

  bool get isInvisible => components.any((component) => component.isInvisible);

  CompoundSelector(Iterable<SimpleSelector> components)
      : components = new List.unmodifiable(components) {
    if (this.components.isEmpty) {
      throw new ArgumentError("components may not be empty.");
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
          {url, Logger logger, bool allowParent: true}) =>
      new SelectorParser(contents,
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

  /// Computes [_minSpecificity] and [_maxSpecificity].
  void _computeSpecificity() {
    _minSpecificity = 0;
    _maxSpecificity = 0;
    for (var simple in components) {
      _minSpecificity += simple.minSpecificity;
      _maxSpecificity += simple.maxSpecificity;
    }
  }

  int get hashCode => listHash(components);

  bool operator ==(other) =>
      other is CompoundSelector && listEquals(components, other.components);
}
