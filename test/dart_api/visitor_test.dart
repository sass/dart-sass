// Copyright 2021 Google LLC. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:sass/src/visitor/recursive_ast.dart';
import 'package:sass/src/visitor/recursive_statement.dart';

/// Test that `RecursiveAstVisitor` is not missing any implementations.
class TestAstVisitor extends RecursiveAstVisitor {}

/// Test that `RecursiveStatementVisitor` is not missing any implementations.
class TestStatementVisitor extends RecursiveStatementVisitor {}

void main() {}
