// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../visitor/interface/statement.dart';
import 'node.dart';

/// A statement in a Sass syntax tree.
abstract class Statement implements SassNode {
  /// Calls the appropriate visit method on [visitor].
  T accept<T>(StatementVisitor<T> visitor);
}
