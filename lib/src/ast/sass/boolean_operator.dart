// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// An enum for binary boolean operations.
///
/// Currently CSS only supports conjunctions (`and`) and disjunctions (`or`).
enum BooleanOperator {
  and,
  or;

  String toString() => name;
}
