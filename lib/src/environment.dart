// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_environment.dart.
// See tool/synchronize.dart for details.
//
// Checksum: 302f38bd0b4f860d17374a959a0cd6ea16ae1dd1

import 'package:source_span/source_span.dart';

import 'ast/sass.dart';
import 'callable.dart';
import 'functions.dart';
import 'value.dart';
import 'utils.dart';

/// The lexical environment in which Sass is executed.
///
/// This tracks lexically-scoped information, such as variables, functions, and
/// mixins.
class Environment {
  /// A list of variables defined at each lexical scope level.
  ///
  /// Each scope maps the names of declared variables to their values. These
  /// maps are *normalized*, meaning that they treat hyphens and underscores in
  /// its keys interchangeably.
  ///
  /// The first element is the global scope, and each successive element is
  /// deeper in the tree.
  final List<Map<String, Value>> _variables;

  /// The spans where each variable in [_variables] was defined.
  ///
  /// This is `null` if source mapping is disabled.
  final List<Map<String, FileSpan>> _variableSpans;

  /// A map of variable names to their indices in [_variables].
  ///
  /// This map is *normalized*, meaning that it treats hyphens and underscores
  /// in its keys interchangeably.
  ///
  /// This map is filled in as-needed, and may not be complete.
  final Map<String, int> _variableIndices;

  /// A list of functions defined at each lexical scope level.
  ///
  /// Each scope maps the names of declared functions to their values. These
  /// maps are *normalized*, meaning that they treat hyphens and underscores in
  /// its keys interchangeably.
  ///
  /// The first element is the global scope, and each successive element is
  /// deeper in the tree.
  final List<Map<String, Callable>> _functions;

  /// A map of function names to their indices in [_functions].
  ///
  /// This map is *normalized*, meaning that it treats hyphens and underscores
  /// in its keys interchangeably.
  ///
  /// This map is filled in as-needed, and may not be complete.
  final Map<String, int> _functionIndices;

  /// A list of mixins defined at each lexical scope level.
  ///
  /// Each scope maps the names of declared mixins to their values. These
  /// maps are *normalized*, meaning that they treat hyphens and underscores in
  /// its keys interchangeably.
  ///
  /// The first element is the global scope, and each successive element is
  /// deeper in the tree.
  final List<Map<String, Callable>> _mixins;

  /// A map of mixin names to their indices in [_mixins].
  ///
  /// This map is *normalized*, meaning that it treats hyphens and underscores
  /// in its keys interchangeably.
  ///
  /// This map is filled in as-needed, and may not be complete.
  final Map<String, int> _mixinIndices;

  /// The content block passed to the lexically-enclosing mixin, or `null` if this is not
  /// in a mixin, or if no content block was passed.
  List<Statement> get contentBlock => _contentBlock;
  List<Statement> _contentBlock;

  /// The environment in which [_contentBlock] should be executed.
  Environment get contentEnvironment => _contentEnvironment;
  Environment _contentEnvironment;

  /// Whether the environment is lexically within a mixin.
  bool get inMixin => _inMixin;
  var _inMixin = false;

  /// Whether the environment is currently in a global or semi-global scope.
  ///
  /// A semi-global scope can assign to global variables, but it doesn't declare
  /// them by default.
  var _inSemiGlobalScope = true;

  /// The name of the last variable that was accessed.
  ///
  /// This is cached to speed up repeated references to the same variable, as
  /// well as references to the last variable's [FileSpan].
  String _lastVariableName;

  /// The index in [_variables] of the last variable that was accessed.
  int _lastVariableIndex;

  /// Creates an [Environment].
  ///
  /// If [sourceMap] is `true`, this tracks variables' source locations
  Environment({bool sourceMap: false})
      : _variables = [normalizedMap()],
        _variableSpans = sourceMap ? [normalizedMap()] : null,
        _variableIndices = normalizedMap(),
        _functions = [normalizedMap()],
        _functionIndices = normalizedMap(),
        _mixins = [normalizedMap()],
        _mixinIndices = normalizedMap() {
    coreFunctions.forEach(setFunction);
  }

  Environment._(this._variables, this._variableSpans, this._functions,
      this._mixins, this._contentBlock, this._contentEnvironment)
      // Lazily fill in the indices rather than eagerly copying them from the
      // existing environment in closure() because the copying took a lot of
      // time and was rarely helpful. This saves a bunch of time on Susy's
      // tests.
      : _variableIndices = normalizedMap(),
        _functionIndices = normalizedMap(),
        _mixinIndices = normalizedMap();

  /// Creates a closure based on this environment.
  ///
  /// Any scope changes in this environment will not affect the closure.
  /// However, any new declarations or assignments in scopes that are visible
  /// when the closure was created will be reflected.
  Environment closure() => new Environment._(
      _variables.toList(),
      _variableSpans?.toList(),
      _functions.toList(),
      _mixins.toList(),
      _contentBlock,
      _contentEnvironment);

  /// Returns the value of the variable named [name], or `null` if no such
  /// variable is declared.
  Value getVariable(String name) {
    if (_lastVariableName == name) return _variables[_lastVariableIndex][name];

    var index = _variableIndices[name];
    if (index != null) {
      _lastVariableName = name;
      _lastVariableIndex = index;
      return _variables[index][name];
    }

    index = _variableIndex(name);
    if (index == null) return null;

    _lastVariableName = name;
    _lastVariableIndex = index;
    _variableIndices[name] = index;
    return _variables[index][name];
  }

  /// Returns the source span for the variable named [name], or `null` if no
  /// such variable is declared.
  FileSpan getVariableSpan(String name) {
    if (_lastVariableName == name) {
      return _variableSpans[_lastVariableIndex][name];
    }

    var index = _variableIndices[name];
    if (index != null) {
      _lastVariableName = name;
      _lastVariableIndex = index;
      return _variableSpans[index][name];
    }

    index = _variableIndex(name);
    if (index == null) return null;

    _lastVariableName = name;
    _lastVariableIndex = index;
    _variableIndices[name] = index;
    return _variableSpans[index][name];
  }

  /// Returns whether a variable named [name] exists.
  bool variableExists(String name) => getVariable(name) != null;

  /// Returns whether a global variable named [name] exists.
  bool globalVariableExists(String name) => _variables.first.containsKey(name);

  /// Returns the index of the last map in [_variables] that has a [name] key,
  /// or `null` if none exists.
  int _variableIndex(String name) {
    for (var i = _variables.length - 1; i >= 0; i--) {
      if (_variables[i].containsKey(name)) return i;
    }
    return null;
  }

  /// Sets the variable named [name] to [value], associated with the given [span].
  ///
  /// If [global] is `true`, this sets the variable at the top-level scope.
  /// Otherwise, if the variable was already defined, it'll set it in the
  /// previous scope. If it's undefined, it'll set it in the current scope.
  void setVariable(String name, Value value, FileSpan span,
      {bool global: false}) {
    if (global || _variables.length == 1) {
      // Don't set the index if there's already a variable with the given name,
      // since local accesses should still return the local variable.
      _variableIndices.putIfAbsent(name, () {
        _lastVariableName = name;
        _lastVariableIndex = 0;
        return 0;
      });

      _variables.first[name] = value;
      if (_variableSpans != null) _variableSpans.first[name] = span;
      return;
    }

    var index = _lastVariableName == name
        ? _lastVariableIndex
        : _variableIndices.putIfAbsent(
            name, () => _variableIndex(name) ?? _variables.length - 1);
    if (!_inSemiGlobalScope && index == 0) {
      index = _variables.length - 1;
      _variableIndices[name] = index;
    }

    _lastVariableName = name;
    _lastVariableIndex = index;
    _variables[index][name] = value;
    if (_variableSpans != null) _variableSpans[index][name] = span;
  }

  /// Sets the variable named [name] to [value] in the current scope, associated with the given [span].
  ///
  /// Unlike [setVariable], this will declare the variable in the current scope
  /// even if a declaration already exists in an outer scope.
  void setLocalVariable(String name, Value value, FileSpan span) {
    var index = _variables.length - 1;
    _lastVariableName = name;
    _lastVariableIndex = index;
    _variableIndices[name] = index;
    _variables[index][name] = value;
    if (_variableSpans != null) _variableSpans[index][name] = span;
  }

  /// Returns the value of the function named [name], or `null` if no such
  /// function is declared.
  Callable getFunction(String name) {
    var index = _functionIndices[name];
    if (index != null) return _functions[index][name];

    index = _functionIndex(name);
    if (index == null) return null;

    _functionIndices[name] = index;
    return _functions[index][name];
  }

  /// Returns the index of the last map in [_functions] that has a [name] key,
  /// or `null` if none exists.
  int _functionIndex(String name) {
    for (var i = _functions.length - 1; i >= 0; i--) {
      if (_functions[i].containsKey(name)) return i;
    }
    return null;
  }

  /// Returns whether a function named [name] exists.
  bool functionExists(String name) => getFunction(name) != null;

  /// Sets the variable named [name] to [value] in the current scope.
  void setFunction(Callable callable) {
    var index = _functions.length - 1;
    _functionIndices[callable.name] = index;
    _functions[index][callable.name] = callable;
  }

  /// Returns the value of the mixin named [name], or `null` if no such mixin is
  /// declared.
  Callable getMixin(String name) {
    var index = _mixinIndices[name];
    if (index != null) return _mixins[index][name];

    index = _mixinIndex(name);
    if (index == null) return null;

    _mixinIndices[name] = index;
    return _mixins[index][name];
  }

  /// Returns the index of the last map in [_mixins] that has a [name] key, or
  /// `null` if none exists.
  int _mixinIndex(String name) {
    for (var i = _mixins.length - 1; i >= 0; i--) {
      if (_mixins[i].containsKey(name)) return i;
    }
    return null;
  }

  /// Returns whether a mixin named [name] exists.
  bool mixinExists(String name) => getMixin(name) != null;

  /// Sets the variable named [name] to [value] in the current scope.
  void setMixin(Callable callable) {
    var index = _mixins.length - 1;
    _mixinIndices[callable.name] = index;
    _mixins[index][callable.name] = callable;
  }

  /// Sets [block] and [environment] as [contentBlock] and [contentEnvironment],
  /// respectively, for the duration of [callback].
  void withContent(
      List<Statement> block, Environment environment, void callback()) {
    var oldBlock = _contentBlock;
    var oldEnvironment = _contentEnvironment;
    _contentBlock = block;
    _contentEnvironment = environment;
    callback();
    _contentBlock = oldBlock;
    _contentEnvironment = oldEnvironment;
  }

  /// Sets [inMixin] to `true` for the duration of [callback].
  void asMixin(void callback()) {
    var oldInMixin = _inMixin;
    _inMixin = true;
    callback();
    _inMixin = oldInMixin;
  }

  /// Runs [callback] in a new scope.
  ///
  /// Variables, functions, and mixins declared in a given scope are
  /// inaccessible outside of it. If [semiGlobal] is passed, this scope can
  /// assign to global variables without a `!global` declaration.
  ///
  /// If [when] is false, this doesn't create a new scope and instead just
  /// executes [callback] and returns its result.
  T scope<T>(T callback(), {bool semiGlobal: false, bool when: true}) {
    if (!when) {
      // We still have to track semi-globalness so that
      //
      //     div {
      //       @if ... {
      //         $x: y;
      //       }
      //     }
      //
      // doesn't assign to the global scope.
      var wasInSemiGlobalScope = _inSemiGlobalScope;
      _inSemiGlobalScope = semiGlobal;
      try {
        return callback();
      } finally {
        _inSemiGlobalScope = wasInSemiGlobalScope;
      }
    }

    semiGlobal = semiGlobal && _inSemiGlobalScope;
    var wasInSemiGlobalScope = _inSemiGlobalScope;
    _inSemiGlobalScope = semiGlobal;

    _variables.add(normalizedMap());
    _variableSpans?.add(normalizedMap());
    _functions.add(normalizedMap());
    _mixins.add(normalizedMap());
    try {
      return callback();
    } finally {
      _inSemiGlobalScope = wasInSemiGlobalScope;
      _lastVariableName = null;
      _lastVariableIndex = null;
      for (var name in _variables.removeLast().keys) {
        _variableIndices.remove(name);
      }
      for (var name in _functions.removeLast().keys) {
        _functionIndices.remove(name);
      }
      for (var name in _mixins.removeLast().keys) {
        _mixinIndices.remove(name);
      }
    }
  }
}
