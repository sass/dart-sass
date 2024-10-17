// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:collection/collection.dart';

import '../../exception.dart';
import '../../interpolation_map.dart';
import '../../parse/at_root_query.dart';
import '../css.dart';

/// A query for the `@at-root` rule.
///
/// @nodoc
final class AtRootQuery {
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

  AtRootQuery(this.names, {required this.include})
      : _all = names.contains("all"),
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
  /// If passed, [interpolationMap] maps the text of [contents] back to the
  /// original location of the selector in the source file.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory AtRootQuery.parse(String contents,
          {Object? url, InterpolationMap? interpolationMap}) =>
      AtRootQueryParser(contents, url: url).parse();

  /// Returns whether `this` excludes [node].
  ///
  /// @nodoc
  @internal
  bool excludes(CssParentNode node) {
    if (_all) return !include;
    return switch (node) {
      CssStyleRule() => excludesStyleRules,
      CssMediaRule() => excludesName("media"),
      CssSupportsRule() => excludesName("supports"),
      CssAtRule() => excludesName(node.name.value.toLowerCase()),
      _ => false
    };
  }

  /// Returns whether `this` excludes an at-rule with the given [name].
  bool excludesName(String name) => (_all || names.contains(name)) != include;
}
