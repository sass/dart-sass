// Copyright 2020 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:tuple/tuple.dart';

import '../../value.dart';
import '../number.dart';

/// A specialized subclass of [SassNumber] for numbers that are not
/// [UnitlessSassNumber]s or [SingleUnitSassNumber]s.
@sealed
class ComplexSassNumber extends SassNumber {
  final List<String> numeratorUnits;

  final List<String> denominatorUnits;

  bool get hasUnits => true;

  ComplexSassNumber(num value, Iterable<String> numeratorUnits,
      Iterable<String> denominatorUnits)
      : this._(value, List.unmodifiable(numeratorUnits),
            List.unmodifiable(denominatorUnits));

  ComplexSassNumber._(num value, this.numeratorUnits, this.denominatorUnits,
      [Tuple2<SassNumber, SassNumber>? asSlash])
      : super.protected(value, asSlash) {
    assert(numeratorUnits.length > 1 || denominatorUnits.isNotEmpty);
  }

  bool hasUnit(String unit) => false;

  bool compatibleWithUnit(String unit) => false;

  SassNumber withValue(num value) =>
      ComplexSassNumber._(value, numeratorUnits, denominatorUnits);

  SassNumber withSlash(SassNumber numerator, SassNumber denominator) =>
      ComplexSassNumber._(value, numeratorUnits, denominatorUnits,
          Tuple2(numerator, denominator));
}
