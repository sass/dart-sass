// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:collection';

import '../ast/css.dart';
import '../ast/node.dart';
import '../callable.dart';
import '../exception.dart';
import '../extend/extender.dart';
import '../module.dart';
import '../utils.dart';
import '../value.dart';

/// A module provided by Sass, available under the special `sass:` URL space.
class BuiltInModule<T extends AsyncCallable> implements Module<T> {
  final Uri url;
  final Map<String, T> functions;

  List<Module<T>> get upstream => const [];
  Map<String, Value> get variables => const {};
  Map<String, AstNode> get variableNodes => const {};
  Map<String, T> get mixins => const {};
  Extender get extender => Extender.empty;
  CssStylesheet get css => CssStylesheet.empty(url: url);
  bool get transitivelyContainsCss => false;
  bool get transitivelyContainsExtensions => false;

  BuiltInModule(String name, Iterable<T> functions)
      : url = Uri(scheme: "sass", path: name),
        functions = UnmodifiableMapView(normalizedMap(
            {for (var function in functions) function.name: function}));

  void setVariable(String name, Value value, AstNode nodeWithSpan) {
    throw SassScriptException("Undefined variable.");
  }

  Module<T> cloneCss() => this;
}
