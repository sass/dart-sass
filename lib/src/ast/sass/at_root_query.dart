// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';

import '../../logger.dart';
import '../../parse/at_root_query.dart';
import '../css.dart';

/// A query for the `@at-root` rule.
class AtRootQuery {
  /// The default at-root query, which excludes only style rules.
  static const defaultQuery = AtRootQuery._default();

  /// Whether the query includes or excludes rules with the specified names.
  final bool include;

  /// The names of the rules included or excluded by this query.
  ///
  /// There are two special names. "all" indicates that all rules are included
  /// or excluded, and "rule" indicates style rules are included or excluded.
  final Set<String> names;

  /// Whether this includes or excludes *all* rules.
  final bool _all;

  /// Whether this includes or excludes style rules.
  final bool _rule;

  /// Whether this excludes style rules.
  ///
  /// Note that this takes [include] into account.
  bool get excludesStyleRules => (_all || _rule) != include;

  AtRootQuery(this.include, Set<String> names)
      : names = names,
        _all = names.contains("all"),
        _rule = names.contains("rule");

  /// The default at-root query, used in [default].
  const AtRootQuery._default()
      : include = false,
        names = const UnmodifiableSetView.empty(),
        _all = false,
        _rule = true;

  /// Parses an at-root query from [contents].
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory AtRootQuery.parse(String contents, {Object url, Logger logger}) =>
      AtRootQueryParser(contents, url: url, logger: logger).parse();

  /// Returns whether [this] excludes [node].
  bool excludes(CssParentNode/*!*/ node) {
    if (_all) return !include;
    if (node is CssStyleRule) return excludesStyleRules;
    if (node is CssMediaRule) return excludesName("media");
    if (node is CssSupportsRule) return excludesName("supports");
    if (node is CssAtRule) return excludesName(node.name.value.toLowerCase());
    return false;
  }

  /// Returns whether [this] excludes an at-rule with the given [name].
  bool excludesName(String name) => (_all || names.contains(name)) != include;
}
