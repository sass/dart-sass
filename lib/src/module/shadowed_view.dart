// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/css.dart';
import '../ast/node.dart';
import '../callable.dart';
import '../exception.dart';
import '../extend/extender.dart';
import '../module.dart';
import '../util/limited_map_view.dart';
import '../util/nullable.dart';
import '../utils.dart';
import '../value.dart';

/// A [Module] that only exposes members that aren't shadowed by a given
/// blocklist of member names.
class ShadowedModuleView<T extends AsyncCallable> implements Module<T> {
  /// The wrapped module.
  final Module<T> _inner;

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

  /// Returns whether this module exposes no members or CSS.
  bool get isEmpty =>
      variables.isEmpty &&
      functions.isEmpty &&
      mixins.isEmpty &&
      css.children.isEmpty;

  /// Like [ShadowedModuleView], but returns `null` if [inner] would be unchanged.
  static ShadowedModuleView<T>? ifNecessary<T extends AsyncCallable>(
          Module<T> inner,
          {Set<String>? variables,
          Set<String>? functions,
          Set<String>? mixins}) =>
      _needsBlocklist(inner.variables, variables) ||
              _needsBlocklist(inner.functions, functions) ||
              _needsBlocklist(inner.mixins, mixins)
          ? ShadowedModuleView(inner,
              variables: variables, functions: functions, mixins: mixins)
          : null;

  /// Returns a view of [inner] that doesn't include the given [variables],
  /// [functions], or [mixins].
  ShadowedModuleView(this._inner,
      {Set<String>? variables, Set<String>? functions, Set<String>? mixins})
      : variables = _shadowedMap(_inner.variables, variables),
        variableNodes =
            _inner.variableNodes.andThen((map) => _shadowedMap(map, variables)),
        functions = _shadowedMap(_inner.functions, functions),
        mixins = _shadowedMap(_inner.mixins, mixins);

  ShadowedModuleView._(this._inner, this.variables, this.variableNodes,
      this.functions, this.mixins);

  /// Returns a view of [map] with all keys in [blocklist] omitted.
  static Map<String, V> _shadowedMap<V>(
          Map<String, V> map, Set<String>? blocklist) =>
      blocklist == null || !_needsBlocklist(map, blocklist)
          ? map
          : LimitedMapView.blocklist(map, blocklist);

  /// Returns whether any of [map]'s keys are in [blocklist].
  static bool _needsBlocklist(
          Map<String, Object?> map, Set<String>? blocklist) =>
      blocklist != null && map.isNotEmpty && blocklist.any(map.containsKey);

  void setVariable(String name, Value value, AstNode? nodeWithSpan) {
    if (!variables.containsKey(name)) {
      throw SassScriptException("Undefined variable.");
    } else {
      return _inner.setVariable(name, value, nodeWithSpan);
    }
  }

  Object variableIdentity(String name) {
    assert(variables.containsKey(name));
    return _inner.variableIdentity(name);
  }

  bool operator ==(Object other) =>
      other is ShadowedModuleView &&
      _inner == other._inner &&
      iterableEquals(variables.keys, other.variables.keys) &&
      iterableEquals(functions.keys, other.functions.keys) &&
      iterableEquals(mixins.keys, other.mixins.keys);

  int get hashCode => _inner.hashCode;

  Module<T> cloneCss() => ShadowedModuleView._(
      _inner.cloneCss(), variables, variableNodes, functions, mixins);

  String toString() => "shadowed $_inner";
}
