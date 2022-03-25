// Copyright 2020 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:tuple/tuple.dart';

import '../../value.dart';
import '../number.dart';

/// A specialized subclass of [SassNumber] for numbers that are not
/// [UnitlessSassNumber]s or [SingleUnitSassNumber]s.
///
/// {@category Value}
@sealed
class ComplexSassNumber extends SassNumber {
  // We don't use public fields because they'd be overridden by the getters of
  // the same name in the JS API.

  List<String> get numeratorUnits => _numeratorUnits;
  final List<String> _numeratorUnits;

  List<String> get denominatorUnits => _denominatorUnits;
  final List<String> _denominatorUnits;

  bool get hasUnits => true;

  ComplexSassNumber(
      num value, List<String> numeratorUnits, List<String> denominatorUnits)
      : this._(value, numeratorUnits, denominatorUnits);

  ComplexSassNumber._(num value, this._numeratorUnits, this._denominatorUnits,
      [Tuple2<SassNumber, SassNumber>? asSlash])
      : super.protected(value, asSlash) {
    assert(numeratorUnits.length > 1 || denominatorUnits.isNotEmpty);
  }

  bool hasUnit(String unit) => false;

  bool compatibleWithUnit(String unit) => false;

  @internal
  bool hasPossiblyCompatibleUnits(SassNumber other) {
    // This logic is well-defined, and we could implement it in principle.
    // However, it would be fairly complex and there's no clear need for it yet.
    throw UnimplementedError(
        "ComplexSassNumber.hasPossiblyCompatibleUnits is not implemented.");
  }

  SassNumber withValue(num value) =>
      ComplexSassNumber._(value, numeratorUnits, denominatorUnits);

  SassNumber withSlash(SassNumber numerator, SassNumber denominator) =>
      ComplexSassNumber._(value, numeratorUnits, denominatorUnits,
          Tuple2(numerator, denominator));
}
