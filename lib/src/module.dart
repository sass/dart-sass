// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// DO NOT EDIT. This file was generated from async_module.dart.
// See tool/synchronize.dart for details.
//
// Checksum: 5608be0fdb1bff974611b75d1bbcb364a15d4df2
//
// ignore_for_file: unused_import

import 'package:source_span/source_span.dart';

import 'ast/css.dart';
import 'ast/node.dart';
import 'callable.dart';
import 'value.dart';

/// The interface for a Sass module.
abstract class Module {
  /// The module's variables.
  Map<String, Value> get variables;

  /// The nodes where each variable in [_variables] was defined.
  ///
  /// This is `null` if source mapping is disabled.
  ///
  /// This stores [AstNode]s rather than [FileSpan]s so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  ///
  /// Implementations must ensure that this has the same keys as [variables] if
  /// it's not `null`.
  Map<String, AstNode> get variableNodes;

  /// The module's functions.
  ///
  /// Implementations must ensure that each [Callable] is stored under its own
  /// name.
  Map<String, Callable> get functions;

  /// The module's mixins.
  ///
  /// Implementations must ensure that each [Callable] is stored under its own
  /// name.
  Map<String, Callable> get mixins;

  /// The module's CSS tree.
  CssStylesheet get css;

  /// Sets the variable named [name] to [value], associated with
  /// [nodeWithSpan]'s source span.
  ///
  /// This takes an [AstNode] rather than a [FileSpan] so it can avoid calling
  /// [AstNode.span] if the span isn't required, since some nodes need to do
  /// real work to manufacture a source span.
  ///
  /// Throws a [SassScriptException] if this module doesn't define a variable
  /// named [name].
  void setVariable(String name, Value value, AstNode nodeWithSpan);
}
