// Copyright 2022 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';

import 'number.dart';

class FuzzyEquality implements Equality<double> {
  const FuzzyEquality();

  @override
  bool equals(double e1, double e2) => fuzzyEquals(e1, e2);

  @override
  int hash(double e1) => fuzzyHashCode(e1);

  @override
  bool isValidKey(Object? o) => o is double;
}
