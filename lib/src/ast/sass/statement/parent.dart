// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../statement.dart';

/// A [Statement] that can have child statements.
abstract class ParentStatement implements Statement {
  /// The child statements of this statement.
  final List<Statement> children;

  ParentStatement(this.children);
}
