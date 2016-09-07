// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../../css.dart';
import '../interpolation.dart';
import '../statement.dart';

class AtRootRule implements Statement {
  final Interpolation query;

  final List<Statement> children;

  final FileSpan span;

  AtRootRule(Iterable<Statement> children, this.span, {this.query})
      : children = new List.from(children);

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitAtRootRule(this);

  String toString() {
    var buffer = new StringBuffer("@at-root ");
    if (query != null) buffer.write("$query ");
    return "$buffer {${children.join(' ')}}";
  }
}

class AtRootQuery {
  static const defaultQuery = const AtRootQuery._default();

  final bool include;

  final Set<String> names;

  bool get excludesMedia => _all ? !include : _excludesName("media");

  bool get excludesRule => (_all || _rule) != include;

  final bool _all;

  final bool _rule;

  AtRootQuery(this.include, Set<String> names)
      : names = names,
        _all = names.contains("all"),
        _rule = names.contains("rule");

  const AtRootQuery._default()
      : include = false,
        names = const UnmodifiableSetView.empty(),
        _all = false,
        _rule = true;

  bool excludes(CssParentNode node) {
    if (_all) return !include;
    if (_rule && node is CssStyleRule) return !include;
    return _excludesName(_nameFor(node));
  }

  bool _excludesName(String name) => names.contains(name) != include;

  String _nameFor(CssParentNode node) {
    if (node is CssMediaRule) return "media";
    if (node is CssSupportsRule) return "supports";
    if (node is CssAtRule) return node.name.toLowerCase();
    return null;
  }
}
