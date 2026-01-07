// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../callable.dart';
import '../exception.dart';
import '../visitor/interface/value.dart';
import '../value.dart';

/// A SassScript function reference.
///
/// A function reference captures a function from the local environment so that
/// it may be passed between modules.
///
/// {@category Value}
final class SassFunction extends Value {
  /// The callable that this function invokes.
  ///
  /// Note that this is typed as an [AsyncCallable] so that it will work with
  /// both synchronous and asynchronous evaluate visitors, but in practice the
  /// synchronous evaluate visitor will crash if this isn't a [Callable].
  final AsyncCallable callable;

  /// The unique compile context for tracking if this [SassFunction] belongs to
  /// the current compilation or not.
  ///
  /// This is `null` for functions defined in plugins' Dart code.
  final Object? _compileContext;

  SassFunction(this.callable) : _compileContext = null;

  @internal
  SassFunction.withCompileContext(this.callable, this._compileContext);

  /// @nodoc
  @internal
  T accept<T>(ValueVisitor<T> visitor) => visitor.visitFunction(this);

  SassFunction assertFunction([String? name]) => this;

  /// Asserts that this SassFunction belongs to [compileContext] and returns it.
  ///
  /// It's checked before evaluating a SassFunction to prevent execution of
  /// SassFunction across different compilations.
  @internal
  SassFunction assertCompileContext(Object compileContext) {
    if (_compileContext != null && _compileContext != compileContext) {
      throw SassScriptException(
          "$this does not belong to current compilation.");
    }

    return this;
  }

  bool operator ==(Object other) =>
      other is SassFunction && callable == other.callable;

  int get hashCode => callable.hashCode;
}
