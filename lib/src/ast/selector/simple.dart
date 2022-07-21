// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../../exception.dart';
import '../../logger.dart';
import '../../parse/selector.dart';
import '../selector.dart';

/// Names of pseudo-classes that take selectors as arguments, and that are
/// subselectors of the union of their arguments.
///
/// For example, `.foo` is a superselector of `:matches(.foo)`.
final _subselectorPseudos = {
  'is',
  'matches',
  'where',
  'any',
  'nth-child',
  'nth-last-child'
};

/// An abstract superclass for simple selectors.
///
/// {@category Selector}
abstract class SimpleSelector extends Selector {
  /// The minimum possible specificity that this selector can have.
  ///
  /// Pseudo selectors that contain selectors, like `:not()` and `:matches()`,
  /// can have a range of possible specificities.
  ///
  /// Specificity is represented in base 1000. The spec says this should be
  /// "sufficiently high"; it's extremely unlikely that any single selector
  /// sequence will contain 1000 simple selectors.
  int get minSpecificity => 1000;

  /// The maximum possible specificity that this selector can have.
  ///
  /// Pseudo selectors that contain selectors, like `:not()` and `:matches()`,
  /// can have a range of possible specificities.
  int get maxSpecificity => minSpecificity;

  SimpleSelector();

  /// Parses a simple selector from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  /// [allowParent] controls whether a [ParentSelector] is allowed in this
  /// selector.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory SimpleSelector.parse(String contents,
          {Object? url, Logger? logger, bool allowParent = true}) =>
      SelectorParser(contents,
              url: url, logger: logger, allowParent: allowParent)
          .parseSimpleSelector();

  /// Returns a new [SimpleSelector] based on [this], as though it had been
  /// written with [suffix] at the end.
  ///
  /// Assumes [suffix] is a valid identifier suffix. If this wouldn't produce a
  /// valid [SimpleSelector], throws a [SassScriptException].
  ///
  /// @nodoc
  @internal
  SimpleSelector addSuffix(String suffix) =>
      throw SassScriptException('Invalid parent selector "$this"');

  /// Returns the components of a [CompoundSelector] that matches only elements
  /// matched by both this and [compound].
  ///
  /// By default, this just returns a copy of [compound] with this selector
  /// added to the end, or returns the original array if this selector already
  /// exists in it.
  ///
  /// Returns `null` if unification is impossible—for example, if there are
  /// multiple ID selectors.
  ///
  /// @nodoc
  @internal
  List<SimpleSelector>? unify(List<SimpleSelector> compound) {
    if (compound.length == 1) {
      var other = compound.first;
      if (other is UniversalSelector ||
          (other is PseudoSelector && (other.isHost || other.isHostContext))) {
        return other.unify([this]);
      }
    }
    if (compound.contains(this)) return compound;

    var result = <SimpleSelector>[];
    var addedThis = false;
    for (var simple in compound) {
      // Make sure pseudo selectors always come last.
      if (!addedThis && simple is PseudoSelector) {
        result.add(this);
        addedThis = true;
      }
      result.add(simple);
    }
    if (!addedThis) result.add(this);

    return result;
  }

  /// Whether this is a superselector of [other].
  ///
  /// That is, whether this matches every element that [other] matches, as well
  /// as possibly additional elements.
  bool isSuperselector(SimpleSelector other) {
    if (this == other) return true;
    if (other is PseudoSelector && other.isClass) {
      var list = other.selector;
      if (list != null && _subselectorPseudos.contains(other.normalizedName)) {
        return list.components.every((complex) =>
            complex.components.isNotEmpty &&
            complex.components.last.selector.components
                .any((simple) => isSuperselector(simple)));
      }
    }
    return false;
  }
}
