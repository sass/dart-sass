// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../ast/sass.dart';
import 'recursive_statement.dart';

/// Returns a list of all [DynamicImport]s in [stylesheet].
List<DynamicImport> findImports(Stylesheet stylesheet) =>
    new _FindImportsVisitor().run(stylesheet);

/// A visitor that traverses a stylesheet and records all the [DynamicImport]s
/// it contains.
class _FindImportsVisitor extends RecursiveStatementVisitor {
  final _imports = <DynamicImport>[];

  List<DynamicImport> run(Stylesheet stylesheet) {
    visitStylesheet(stylesheet);
    return _imports;
  }

  // These can never contain imports.
  void visitEachRule(EachRule node) {}
  void visitForRule(ForRule node) {}
  void visitIfRule(IfRule node) {}
  void visitWhileRule(WhileRule node) {}
  void visitCallableDeclaration(CallableDeclaration node) {}
  void visitInterpolation(Interpolation interpolation) {}
  void visitSupportsCondition(SupportsCondition condition) {}

  void visitImportRule(ImportRule node) {
    for (var import in node.imports) {
      if (import is DynamicImport) _imports.add(import);
    }
  }
}
