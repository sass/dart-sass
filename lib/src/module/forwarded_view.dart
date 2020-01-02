// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/css.dart';
import '../ast/node.dart';
import '../ast/sass.dart';
import '../callable.dart';
import '../exception.dart';
import '../extend/extender.dart';
import '../module.dart';
import '../util/limited_map_view.dart';
import '../util/prefixed_map_view.dart';
import '../value.dart';

/// A [Module] that exposes members according to a [ForwardRule].
class ForwardedModuleView<T extends AsyncCallable> implements Module<T> {
  /// The wrapped module.
  final Module<T> _inner;

  /// The rule that determines how this module's members should be exposed.
  final ForwardRule _rule;

  Uri get url => _inner.url;
  List<Module<T>> get upstream => _inner.upstream;
  Extender get extender => _inner.extender;
  CssStylesheet get css => _inner.css;
  bool get transitivelyContainsCss => _inner.transitivelyContainsCss;
  bool get transitivelyContainsExtensions =>
      _inner.transitivelyContainsExtensions;

  final Map<String, Value> variables;
  final Map<String, AstNode> variableNodes;
  final Map<String, T> functions;
  final Map<String, T> mixins;

  ForwardedModuleView(this._inner, this._rule)
      : variables = _forwardedMap(_inner.variables, _rule.prefix,
            _rule.shownVariables, _rule.hiddenVariables),
        variableNodes = _inner.variableNodes == null
            ? null
            : _forwardedMap(_inner.variableNodes, _rule.prefix,
                _rule.shownVariables, _rule.hiddenVariables),
        functions = _forwardedMap(_inner.functions, _rule.prefix,
            _rule.shownMixinsAndFunctions, _rule.hiddenMixinsAndFunctions),
        mixins = _forwardedMap(_inner.mixins, _rule.prefix,
            _rule.shownMixinsAndFunctions, _rule.hiddenMixinsAndFunctions);

  /// Wraps [map] so that it only shows members allowed by [blocklist] or
  /// [safelist], with the given [prefix], if given.
  ///
  /// Only one of [blocklist] or [safelist] may be non-`null`.
  static Map<String, V> _forwardedMap<V>(Map<String, V> map, String prefix,
      Set<String> safelist, Set<String> blocklist) {
    assert(safelist == null || blocklist == null);
    if (prefix == null &&
        safelist == null &&
        (blocklist == null || blocklist.isEmpty)) {
      return map;
    }

    if (prefix != null) {
      map = PrefixedMapView(map, prefix);
    }

    if (safelist != null) {
      map = LimitedMapView.safelist(map, safelist);
    } else if (blocklist != null && blocklist.isNotEmpty) {
      map = LimitedMapView.blocklist(map, blocklist);
    }

    return map;
  }

  void setVariable(String name, Value value, AstNode nodeWithSpan) {
    if (_rule.shownVariables != null && !_rule.shownVariables.contains(name)) {
      throw SassScriptException("Undefined variable.");
    } else if (_rule.hiddenVariables != null &&
        _rule.hiddenVariables.contains(name)) {
      throw SassScriptException("Undefined variable.");
    }

    if (_rule.prefix != null) {
      if (!name.startsWith(_rule.prefix)) {
        throw SassScriptException("Undefined variable.");
      }

      name = name.substring(_rule.prefix.length);
    }

    return _inner.setVariable(name, value, nodeWithSpan);
  }

  Module<T> cloneCss() => ForwardedModuleView(_inner.cloneCss(), _rule);
}
