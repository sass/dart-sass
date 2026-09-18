// Copyright 2026 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../callable.dart';
import '../exception.dart';
import '../module.dart';
import '../visitor/interface/value.dart';
import '../value.dart';

/// A SassScript module reference.
///
/// A module reference allows SassScript to reflect on and interact with
/// modules.
///
/// {@category Value}
final class SassModule extends Value {
  /// The wrapped module.
  ///
  /// Note that this is typed as containing [AsyncCallable]s so that it will
  /// work with both synchronous and asynchronous evaluate visitors, but in
  /// practice the synchronous evaluate visitor will crash if this isn't a
  /// `Module<Callable>`.
  ///
  /// @nodoc
  @internal
  final Module<AsyncCallable> module;

  /// The unique compile context for tracking if this [SassModule] belongs to the
  /// current compilation or not.
  final Object? _compileContext;

  new(this.module) : _compileContext = null;

  @internal
  new withCompileContext(this.module, this._compileContext);

  /// @nodoc
  @override
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitModule(this);

  @override
  SassModule assertModule([String? name]) => this;

  /// Asserts that this SassModule belongs to [compileContext] and returns it.
  ///
  /// It's checked before interacting with a `SassModule` to prevent sharing of
  /// `SassModule`s across different compilations.
  @internal
  SassModule assertCompileContext(Object compileContext) {
    if (_compileContext != null && _compileContext != compileContext) {
      throw SassScriptException(
        "$this does not belong to current compilation.",
      );
    }

    return this;
  }

  /// @nodoc
  @override
  Value plus(Value other) =>
      throw SassScriptException('Undefined operation "$this + $other".');

  /// @nodoc
  @override
  Value minus(Value other) =>
      throw SassScriptException('Undefined operation "$this - $other".');

  /// @nodoc
  @override
  Value dividedBy(Value other) =>
      throw SassScriptException('Undefined operation "$this / $other".');

  /// @nodoc
  @override
  Value unaryPlus() =>
      throw SassScriptException('Undefined operation "+$this".');

  /// @nodoc
  @override
  Value unaryMinus() =>
      throw SassScriptException('Undefined operation "-($this)".');

  /// @nodoc
  @override
  Value unaryDivide() =>
      throw SassScriptException('Undefined operation "/$this".');

  @override
  bool operator ==(Object other) =>
      other is SassModule &&
      _compileContext == other._compileContext &&
      module == other.module;

  @override
  int get hashCode => module.hashCode;
}
