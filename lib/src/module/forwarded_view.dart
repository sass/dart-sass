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
import '../util/nullable.dart';
import '../util/prefixed_map_view.dart';
import '../value.dart';

/// A [Module] that exposes members according to a [ForwardRule].
class ForwardedModuleView<T extends AsyncCallable> implements Module<T> {
  /// The wrapped module.
  final Module<T> _inner;

  /// The rule that determines how this module's members should be exposed.
  final ForwardRule _rule;

  Uri? get url => _inner.url;
  List<Module<T>> get upstream => _inner.upstream;
  Extender get extender => _inner.extender;
  CssStylesheet get css => _inner.css;
  bool get transitivelyContainsCss => _inner.transitivelyContainsCss;
  bool get transitivelyContainsExtensions =>
      _inner.transitivelyContainsExtensions;

  final Map<String, Value> variables;
  final Map<String, AstNode>? variableNodes;
  final Map<String, T> functions;
  final Map<String, T> mixins;

  /// Like [ForwardedModuleView], but returns `inner` as-is if it doesn't need
  /// any modification.
  static Module<T> ifNecessary<T extends AsyncCallable>(
      Module<T> inner, ForwardRule rule) {
    if (rule.prefix == null &&
            rule.shownMixinsAndFunctions == null &&
            rule.shownVariables == null &&
            rule?.hiddenMixinsAndFunctions?.isEmpty ??
        false && rule?.hiddenVariables?.isEmpty ??
        false) {
      return inner;
    } else {
      return ForwardedModuleView(inner, rule);
    }
  }

  ForwardedModuleView(this._inner, this._rule)
      : variables = _forwardedMap(_inner.variables, _rule.prefix,
            _rule.shownVariables, _rule.hiddenVariables),
        variableNodes = _inner.variableNodes.andThen((inner) => _forwardedMap(
            inner, _rule.prefix, _rule.shownVariables, _rule.hiddenVariables)),
        functions = _forwardedMap(_inner.functions, _rule.prefix,
            _rule.shownMixinsAndFunctions, _rule.hiddenMixinsAndFunctions),
        mixins = _forwardedMap(_inner.mixins, _rule.prefix,
            _rule.shownMixinsAndFunctions, _rule.hiddenMixinsAndFunctions);

  /// Wraps [map] so that it only shows members allowed by [blocklist] or
  /// [safelist], with the given [prefix], if given.
  ///
  /// Only one of [blocklist] or [safelist] may be non-`null`.
  static Map<String, V> _forwardedMap<V>(Map<String, V> map, String? prefix,
      Set<String>? safelist, Set<String>? blocklist) {
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

  void setVariable(String name, Value value, AstNode? nodeWithSpan) {
    var shownVariables = _rule.shownVariables;
    var hiddenVariables = _rule.hiddenVariables;
    if (shownVariables != null && !shownVariables.contains(name)) {
      throw SassScriptException("Undefined variable.");
    } else if (hiddenVariables != null && hiddenVariables.contains(name)) {
      throw SassScriptException("Undefined variable.");
    }

    var prefix = _rule.prefix;
    if (prefix != null) {
      if (!name.startsWith(prefix)) {
        throw SassScriptException("Undefined variable.");
      }

      name = name.substring(prefix.length);
    }

    return _inner.setVariable(name, value, nodeWithSpan);
  }

  Object variableIdentity(String name) {
    assert(variables.containsKey(name));

    var prefix = _rule.prefix;
    if (prefix != null) {
      assert(name.startsWith(prefix));
      name = name.substring(prefix.length);
    }

    return _inner.variableIdentity(name);
  }

  bool operator ==(Object other) =>
      other is ForwardedModuleView &&
      _inner == other._inner &&
      _rule == other._rule;

  int get hashCode => _inner.hashCode ^ _rule.hashCode;

  Module<T> cloneCss() => ForwardedModuleView(_inner.cloneCss(), _rule);

  String toString() => "forwarded $_inner";
}
