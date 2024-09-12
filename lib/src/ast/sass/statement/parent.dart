// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';

import '../import/dynamic.dart';
import '../statement.dart';
import 'function_rule.dart';
import 'import_rule.dart';
import 'mixin_rule.dart';
import 'variable_declaration.dart';

/// A [Statement] that can have child statements.
///
/// This has a generic parameter so that its subclasses can choose whether or
/// not their children lists are nullable.
///
/// {@category AST}
abstract base class ParentStatement<T extends List<Statement>?>
    extends Statement {
  /// The child statements of this statement.
  final T children;

  /// Whether any of [children] is a variable, function, or mixin declaration,
  /// or a dynamic import rule.
  ///
  /// @nodoc
  @internal
  final bool hasDeclarations;

  ParentStatement(this.children)
      : hasDeclarations = children?.any((child) => switch (child) {
                  VariableDeclaration() ||
                  FunctionRule() ||
                  MixinRule() =>
                    true,
                  ImportRule(:var imports) =>
                    imports.any((import) => import is DynamicImport),
                  _ => false,
                }) ??
            false;
}
