// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import '../ast/css.dart';
import '../ast/node.dart';
import '../callable.dart';
import '../exception.dart';
import '../extend/extension_store.dart';
import '../module.dart';
import '../value.dart';

/// A module provided by Sass, available under the special `sass:` URL space.
final class BuiltInModule<T extends AsyncCallable> implements Module<T> {
  @override
  final Uri url;

  @override
  final Map<String, T> functions;

  @override
  final Map<String, T> mixins;

  @override
  final Map<String, Value> variables;

  @override
  List<Module<T>> get upstream => const [];

  @override
  Map<String, AstNode> get variableNodes => const {};

  @override
  ExtensionStore get extensionStore => ExtensionStore.empty;

  @override
  CssStylesheet get css => CssStylesheet.empty(url: url);

  @override
  Map<Module<T>, List<CssComment>> get preModuleComments => const {};

  @override
  bool get transitivelyContainsCss => false;

  @override
  bool get transitivelyContainsExtensions => false;

  BuiltInModule(
    String name, {
    Iterable<T>? functions,
    Iterable<T>? mixins,
    Map<String, Value>? variables,
  })  : url = Uri(scheme: "sass", path: name),
        functions = _callableMap(functions),
        mixins = _callableMap(mixins),
        variables =
            variables == null ? const {} : UnmodifiableMapView(variables);

  /// Returns a map from [callables]' names to their values.
  static Map<String, T> _callableMap<T extends AsyncCallable>(
    Iterable<T>? callables,
  ) =>
      UnmodifiableMapView(
        callables == null
            ? {}
            : UnmodifiableMapView({
                for (var callable in callables) callable.name: callable,
              }),
      );

  @override
  void setVariable(String name, Value value, AstNode nodeWithSpan) {
    if (!variables.containsKey(name)) {
      throw SassScriptException("Undefined variable.");
    }
    throw SassScriptException("Cannot modify built-in variable.");
  }

  @override
  Object variableIdentity(String name) {
    assert(variables.containsKey(name));
    return this;
  }

  @override
  bool couldHaveBeenConfigured(Set<String> _) => false;

  @override
  Module<T> cloneCss() => this;
}
