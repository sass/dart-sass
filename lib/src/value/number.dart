// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math';

import 'package:meta/meta.dart';
import 'package:tuple/tuple.dart';

import '../exception.dart';
import '../util/number.dart';
import '../utils.dart';
import '../value.dart';
import '../visitor/interface/value.dart';
import 'external/value.dart' as ext;

/// A nested map containing unit conversion rates.
///
/// `1unit1 * _conversions[unit1][unit2] = 1unit2`.
const _conversions = {
  // Length
  "in": {
    "in": 1,
    "cm": 1 / 2.54,
    "pc": 1 / 6,
    "mm": 1 / 25.4,
    "q": 1 / 101.6,
    "pt": 1 / 72,
    "px": 1 / 96,
  },
  "cm": {
    "in": 2.54,
    "cm": 1,
    "pc": 2.54 / 6,
    "mm": 1 / 10,
    "q": 1 / 40,
    "pt": 2.54 / 72,
    "px": 2.54 / 96,
  },
  "pc": {
    "in": 6,
    "cm": 6 / 2.54,
    "pc": 1,
    "mm": 6 / 25.4,
    "q": 6 / 101.6,
    "pt": 1 / 12,
    "px": 1 / 16,
  },
  "mm": {
    "in": 25.4,
    "cm": 10,
    "pc": 25.4 / 6,
    "mm": 1,
    "q": 1 / 4,
    "pt": 25.4 / 72,
    "px": 25.4 / 96,
  },
  "q": {
    "in": 101.6,
    "cm": 40,
    "pc": 101.6 / 6,
    "mm": 4,
    "q": 1,
    "pt": 101.6 / 72,
    "px": 101.6 / 96,
  },
  "pt": {
    "in": 72,
    "cm": 72 / 2.54,
    "pc": 12,
    "mm": 72 / 25.4,
    "q": 72 / 101.6,
    "pt": 1,
    "px": 3 / 4,
  },
  "px": {
    "in": 96,
    "cm": 96 / 2.54,
    "pc": 16,
    "mm": 96 / 25.4,
    "q": 96 / 101.6,
    "pt": 4 / 3,
    "px": 1,
  },

  // Rotation
  "deg": {
    "deg": 1,
    "grad": 9 / 10,
    "rad": 180 / pi,
    "turn": 360,
  },
  "grad": {
    "deg": 10 / 9,
    "grad": 1,
    "rad": 200 / pi,
    "turn": 400,
  },
  "rad": {
    "deg": pi / 180,
    "grad": pi / 200,
    "rad": 1,
    "turn": 2 * pi,
  },
  "turn": {
    "deg": 1 / 360,
    "grad": 1 / 400,
    "rad": 1 / (2 * pi),
    "turn": 1,
  },

  // Time
  "s": {
    "s": 1,
    "ms": 1 / 1000,
  },
  "ms": {
    "s": 1000,
    "ms": 1,
  },

  // Frequency
  "Hz": {"Hz": 1, "kHz": 1000},
  "kHz": {"Hz": 1 / 1000, "kHz": 1},

  // Pixel density
  "dpi": {
    "dpi": 1,
    "dpcm": 2.54,
    "dppx": 96,
  },
  "dpcm": {
    "dpi": 1 / 2.54,
    "dpcm": 1,
    "dppx": 96 / 2.54,
  },
  "dppx": {
    "dpi": 1 / 96,
    "dpcm": 2.54 / 96,
    "dppx": 1,
  },
};

/// A map from human-readable names of unit types to the units that fall into
/// those types.
const _unitsByType = {
  "length": ["in", "cm", "pc", "mm", "q", "pt", "px"],
  "angle": ["deg", "grad", "rad", "turn"],
  "time": ["s", "ms"],
  "frequency": ["Hz", "kHz"],
  "pixel density": ["dpi", "dpcm", "dppx"]
};

/// A map from units to the human-readable names of those unit types.
final _typesByUnit = {
  for (var entry in _unitsByType.entries)
    for (var unit in entry.value) unit: entry.key
};

// TODO(nweiz): If it's faster, add subclasses specifically for unitless numbers
// and numbers with only a single numerator unit. These should be opaque to
// users of SassNumber.

class SassNumber extends Value implements ext.SassNumber {
  static const precision = ext.SassNumber.precision;

  final num value;

  final List<String> numeratorUnits;

  final List<String> denominatorUnits;

  /// The representation of this number as two slash-separated numbers, if it
  /// has one.
  final Tuple2<SassNumber, SassNumber> asSlash;

  bool get hasUnits => numeratorUnits.isNotEmpty || denominatorUnits.isNotEmpty;

  bool get isInt => fuzzyIsInt(value);

  int get asInt => fuzzyAsInt(value);

  /// Returns a human readable string representation of this number's units.
  String get unitString =>
      hasUnits ? _unitString(numeratorUnits, denominatorUnits) : '';

  SassNumber(num value, [String unit])
      : this.withUnits(value, numeratorUnits: unit == null ? null : [unit]);

  SassNumber.withUnits(this.value,
      {Iterable<String> numeratorUnits, Iterable<String> denominatorUnits})
      : numeratorUnits = numeratorUnits == null
            ? const []
            : List.unmodifiable(numeratorUnits),
        denominatorUnits = denominatorUnits == null
            ? const []
            : List.unmodifiable(denominatorUnits),
        asSlash = null;

  SassNumber._(this.value, this.numeratorUnits, this.denominatorUnits,
      [this.asSlash]);

  T accept<T>(ValueVisitor<T> visitor) => visitor.visitNumber(this);

  /// Returns a copy of [this] without [asSlash] set.
  SassNumber withoutSlash() {
    if (asSlash == null) return this;
    return SassNumber._(value, numeratorUnits, denominatorUnits);
  }

  /// Returns a copy of [this] with [this.asSlash] set to a tuple containing
  /// [numerator] and [denominator].
  SassNumber withSlash(SassNumber numerator, SassNumber denominator) =>
      SassNumber._(value, numeratorUnits, denominatorUnits,
          Tuple2(numerator, denominator));

  SassNumber assertNumber([String name]) => this;

  int assertInt([String name]) {
    var integer = fuzzyAsInt(value);
    if (integer != null) return integer;
    throw _exception("$this is not an int.", name);
  }

  num valueInRange(num min, num max, [String name]) {
    var result = fuzzyCheckRange(value, min, max);
    if (result != null) return result;
    throw _exception(
        "Expected $this to be within $min$unitString and $max$unitString.",
        name);
  }

  bool hasUnit(String unit) =>
      numeratorUnits.length == 1 &&
      denominatorUnits.isEmpty &&
      numeratorUnits.first == unit;

  bool compatibleWithUnit(String unit) {
    if (denominatorUnits.isNotEmpty) return false;
    if (numeratorUnits.isEmpty) return true;
    return numeratorUnits.length == 1 &&
        _conversionFactor(numeratorUnits.first, unit) != null;
  }

  void assertUnit(String unit, [String name]) {
    if (hasUnit(unit)) return;
    throw _exception('Expected $this to have unit "$unit".', name);
  }

  void assertNoUnits([String name]) {
    if (!hasUnits) return;
    throw _exception('Expected $this to have no units.', name);
  }

  SassNumber coerceToMatch(ext.SassNumber other,
          [String name, String otherName]) =>
      SassNumber.withUnits(coerceValueToMatch(other, name, otherName),
          numeratorUnits: other.numeratorUnits,
          denominatorUnits: other.denominatorUnits);

  num coerceValueToMatch(ext.SassNumber other,
          [String name, String otherName]) =>
      _coerceOrConvertValue(other.numeratorUnits, other.denominatorUnits,
          coerceUnitless: true, name: name, other: other, otherName: otherName);

  SassNumber convertToMatch(ext.SassNumber other,
          [String name, String otherName]) =>
      SassNumber.withUnits(convertValueToMatch(other, name, otherName),
          numeratorUnits: other.numeratorUnits,
          denominatorUnits: other.denominatorUnits);

  num convertValueToMatch(ext.SassNumber other,
          [String name, String otherName]) =>
      _coerceOrConvertValue(other.numeratorUnits, other.denominatorUnits,
          coerceUnitless: false,
          name: name,
          other: other,
          otherName: otherName);

  SassNumber coerce(List<String> newNumerators, List<String> newDenominators,
          [String name]) =>
      SassNumber.withUnits(coerceValue(newNumerators, newDenominators, name),
          numeratorUnits: newNumerators, denominatorUnits: newDenominators);

  num coerceValue(List<String> newNumerators, List<String> newDenominators,
          [String name]) =>
      _coerceOrConvertValue(newNumerators, newDenominators,
          coerceUnitless: true, name: name);

  num coerceValueToUnit(String unit, [String name]) =>
      coerceValue([unit], [], name);

  @deprecated
  num valueInUnits(List<String> newNumerators, List<String> newDenominators,
          [String name]) =>
      coerceValue(newNumerators, newDenominators, name);

  /// Converts [value] to [newNumerators] and [newDenominators].
  ///
  /// If [coerceUnitless] is `true`, this considers unitless numbers convertable
  /// to and from any unit. Otherwise, it will throw a [SassScriptException] for
  /// such a conversion.
  ///
  /// If [other] is passed, it should be the number from which [newNumerators]
  /// and [newDenominators] are derived. The [name] and [otherName] are the Sass
  /// function parameter names of [this] and [other], respectively, used for
  /// error reporting.
  num _coerceOrConvertValue(
      List<String> newNumerators, List<String> newDenominators,
      {@required bool coerceUnitless,
      String name,
      ext.SassNumber other,
      String otherName}) {
    assert(
        other == null ||
            (listEquals(other.numeratorUnits, newNumerators) &&
                listEquals(other.denominatorUnits, newDenominators)),
        "Expected $other to have units "
        "${_unitString(newNumerators, newDenominators)}.");

    if (listEquals(numeratorUnits, newNumerators) &&
        listEquals(denominatorUnits, newDenominators)) {
      return this.value;
    }

    var otherHasUnits = newNumerators.isNotEmpty || newDenominators.isNotEmpty;
    if (coerceUnitless && (!hasUnits || !otherHasUnits)) return this.value;

    SassScriptException _compatibilityException() {
      if (other != null) {
        var message = StringBuffer("$this and");
        if (otherName != null) message.write(" \$$otherName:");
        message.write(" $other have incompatible units");
        if (!hasUnits || !otherHasUnits) {
          message.write(" (one has units and the other doesn't)");
        }
        return _exception("$message.", name);
      } else if (!otherHasUnits) {
        return _exception("Expected $this to have no units.", name);
      } else {
        if (newNumerators.length == 1 && newDenominators.isEmpty) {
          var type = _typesByUnit[newNumerators.first];
          if (type != null) {
            // If we're converting to a unit of a named type, use that type name
            // and make it clear exactly which units are convertible.
            return _exception(
                "Expected $this to have ${a(type)} unit "
                "(${_unitsByType[type].join(', ')}).",
                name);
          }
        }

        var unit =
            pluralize('unit', newNumerators.length + newDenominators.length);
        return _exception(
            "Expected $this to have $unit "
            "${_unitString(newNumerators, newDenominators)}.",
            name);
      }
    }

    var value = this.value;
    var oldNumerators = numeratorUnits.toList();
    for (var newNumerator in newNumerators) {
      removeFirstWhere<String>(oldNumerators, (oldNumerator) {
        var factor = _conversionFactor(newNumerator, oldNumerator);
        if (factor == null) return false;
        value *= factor;
        return true;
      }, orElse: () => throw _compatibilityException());
    }

    var oldDenominators = denominatorUnits.toList();
    for (var newDenominator in newDenominators) {
      removeFirstWhere<String>(oldDenominators, (oldDenominator) {
        var factor = _conversionFactor(newDenominator, oldDenominator);
        if (factor == null) return false;
        value /= factor;
        return true;
      }, orElse: () => throw _compatibilityException());
    }

    if (oldNumerators.isNotEmpty || oldDenominators.isNotEmpty) {
      throw _compatibilityException();
    }

    return value;
  }

  /// Returns whether this number can be compared to [other].
  ///
  /// Two numbers can be compared if they have compatible units, or if either
  /// number has no units.
  bool isComparableTo(SassNumber other) {
    if (!hasUnits || !other.hasUnits) return true;
    try {
      greaterThan(other);
      return true;
    } on SassScriptException {
      return false;
    }
  }

  SassBoolean greaterThan(Value other) {
    if (other is SassNumber) {
      return SassBoolean(_coerceUnits(other, fuzzyGreaterThan));
    }
    throw SassScriptException('Undefined operation "$this > $other".');
  }

  SassBoolean greaterThanOrEquals(Value other) {
    if (other is SassNumber) {
      return SassBoolean(_coerceUnits(other, fuzzyGreaterThanOrEquals));
    }
    throw SassScriptException('Undefined operation "$this >= $other".');
  }

  SassBoolean lessThan(Value other) {
    if (other is SassNumber) {
      return SassBoolean(_coerceUnits(other, fuzzyLessThan));
    }
    throw SassScriptException('Undefined operation "$this < $other".');
  }

  SassBoolean lessThanOrEquals(Value other) {
    if (other is SassNumber) {
      return SassBoolean(_coerceUnits(other, fuzzyLessThanOrEquals));
    }
    throw SassScriptException('Undefined operation "$this <= $other".');
  }

  Value modulo(Value other) {
    if (other is SassNumber) {
      return _coerceNumber(other, (num1, num2) {
        if (num2 > 0) return num1 % num2;
        if (num2 == 0) return double.nan;

        // Dart has different mod-negative semantics than Ruby, and thus than
        // Sass.
        var result = num1 % num2;
        return result == 0 ? 0 : result + num2;
      });
    }
    throw SassScriptException('Undefined operation "$this % $other".');
  }

  Value plus(Value other) {
    if (other is SassNumber) {
      return _coerceNumber(other, (num1, num2) => num1 + num2);
    }
    if (other is! SassColor) return super.plus(other);
    throw SassScriptException('Undefined operation "$this + $other".');
  }

  Value minus(Value other) {
    if (other is SassNumber) {
      return _coerceNumber(other, (num1, num2) => num1 - num2);
    }
    if (other is! SassColor) return super.minus(other);
    throw SassScriptException('Undefined operation "$this - $other".');
  }

  Value times(Value other) {
    if (other is SassNumber) {
      return _multiplyUnits(value * other.value, numeratorUnits,
          denominatorUnits, other.numeratorUnits, other.denominatorUnits);
    }
    throw SassScriptException('Undefined operation "$this * $other".');
  }

  Value dividedBy(Value other) {
    if (other is SassNumber) {
      return _multiplyUnits(value / other.value, numeratorUnits,
          denominatorUnits, other.denominatorUnits, other.numeratorUnits);
    }
    return super.dividedBy(other);
  }

  Value unaryPlus() => this;

  Value unaryMinus() => SassNumber.withUnits(-value,
      numeratorUnits: numeratorUnits, denominatorUnits: denominatorUnits);

  /// Converts [other]'s value to be compatible with this number's, calls
  /// [operation] with the resulting numbers, and wraps the result in a
  /// [SassNumber].
  ///
  /// Throws a [SassScriptException] if the two numbers' units are incompatible.
  SassNumber _coerceNumber(
      SassNumber other, num operation(num num1, num num2)) {
    var result = _coerceUnits(other, operation);
    return SassNumber.withUnits(result,
        numeratorUnits: hasUnits ? numeratorUnits : other.numeratorUnits,
        denominatorUnits: hasUnits ? denominatorUnits : other.denominatorUnits);
  }

  /// Converts [other]'s value to be compatible with this number's, and calls
  /// [operation] with the resulting numbers.
  ///
  /// Throws a [SassScriptException] if the two numbers' units are incompatible.
  T _coerceUnits<T>(SassNumber other, T operation(num num1, num num2)) {
    num num1;
    num num2;
    if (hasUnits) {
      num1 = value;
      try {
        num2 = other.coerceValueToMatch(this);
      } on SassScriptException {
        // If the conversion fails, re-run it in the other direction. This will
        // generate an error message that prints [this] before [other], which is
        // more readable.
        coerceValueToMatch(other);
        rethrow; // This should be unreachable.
      }
    } else {
      num1 = coerceValueToMatch(other);
      num2 = other.value;
    }

    return operation(num1, num2);
  }

  /// Returns a new number that's equivalent to `value numerators1/denominators1
  /// * 1 numerators2/denominators2`.
  SassNumber _multiplyUnits(
      num value,
      List<String> numerators1,
      List<String> denominators1,
      List<String> numerators2,
      List<String> denominators2) {
    // Short-circuit without allocating any new unit lists if possible.
    if (numerators1.isEmpty) {
      if (denominators2.isEmpty &&
          !_areAnyConvertible(denominators1, numerators2)) {
        return SassNumber.withUnits(value,
            numeratorUnits: numerators2, denominatorUnits: denominators1);
      } else if (denominators1.isEmpty) {
        return SassNumber.withUnits(value,
            numeratorUnits: numerators2, denominatorUnits: denominators2);
      }
    } else if (numerators2.isEmpty) {
      if (denominators2.isEmpty) {
        return SassNumber.withUnits(value,
            numeratorUnits: numerators1, denominatorUnits: denominators2);
      } else if (denominators1.isEmpty &&
          !_areAnyConvertible(numerators1, denominators2)) {
        return SassNumber.withUnits(value,
            numeratorUnits: numerators1, denominatorUnits: denominators2);
      }
    }

    var newNumerators = <String>[];
    var mutableDenominators2 = denominators2.toList();
    for (var numerator in numerators1) {
      removeFirstWhere<String>(mutableDenominators2, (denominator) {
        var factor = _conversionFactor(numerator, denominator);
        if (factor == null) return false;
        value /= factor;
        return true;
      }, orElse: () {
        newNumerators.add(numerator);
        return null;
      });
    }

    var mutableDenominators1 = denominators1.toList();
    for (var numerator in numerators2) {
      removeFirstWhere<String>(mutableDenominators1, (denominator) {
        var factor = _conversionFactor(numerator, denominator);
        if (factor == null) return false;
        value /= factor;
        return true;
      }, orElse: () {
        newNumerators.add(numerator);
        return null;
      });
    }

    return SassNumber.withUnits(value,
        numeratorUnits: newNumerators,
        denominatorUnits: mutableDenominators1..addAll(mutableDenominators2));
  }

  /// Returns whether there exists a unit in [units1] that can be converted to a
  /// unit in [units2].
  bool _areAnyConvertible(List<String> units1, List<String> units2) {
    return units1.any((unit1) {
      if (!_isConvertable(unit1)) return units2.contains(unit1);
      var innerMap = _conversions[unit1];
      return units2.any(innerMap.containsKey);
    });
  }

  /// Returns whether [unit] can be converted to or from any other units.
  bool _isConvertable(String unit) => _conversions.containsKey(unit);

  /// Returns the number of [unit1]s per [unit2].
  ///
  /// Equivalently, `1unit1 * _conversionFactor(unit1, unit2) = 1unit2`.
  num _conversionFactor(String unit1, String unit2) {
    if (unit1 == unit2) return 1;
    var innerMap = _conversions[unit1];
    if (innerMap == null) return null;
    return innerMap[unit2];
  }

  /// Returns a human-readable string representation of [numerators] and
  /// [denominators].
  String _unitString(List<String> numerators, List<String> denominators) {
    if (numerators.isEmpty) {
      if (denominators.isEmpty) return "no units";
      if (denominators.length == 1) return denominators.single + "^-1";
      return "(${denominators.join('*')})^-1";
    }

    if (denominators.isEmpty) return numerators.join("*");

    return "${numerators.join("*")}/${denominators.join("*")}";
  }

  bool operator ==(Object other) {
    if (other is SassNumber) {
      if (numeratorUnits.length != other.numeratorUnits.length ||
          denominatorUnits.length != other.denominatorUnits.length) {
        return false;
      }
      if (!hasUnits) return fuzzyEquals(value, other.value);

      if (!listEquals(_canonicalizeUnitList(numeratorUnits),
              _canonicalizeUnitList(other.numeratorUnits)) ||
          !listEquals(_canonicalizeUnitList(denominatorUnits),
              _canonicalizeUnitList(other.denominatorUnits))) {
        return false;
      }

      return fuzzyEquals(
          value *
              _canonicalMultiplier(numeratorUnits) /
              _canonicalMultiplier(denominatorUnits),
          other.value *
              _canonicalMultiplier(other.numeratorUnits) /
              _canonicalMultiplier(other.denominatorUnits));
    } else {
      return false;
    }
  }

  int get hashCode => fuzzyHashCode(value *
      _canonicalMultiplier(numeratorUnits) /
      _canonicalMultiplier(denominatorUnits));

  /// Converts a unit list (such as [numeratorUnits]) into an equivalent list in
  /// a canonical form, to make it easier to check whether two numbers have
  /// compatible units.
  List<String> _canonicalizeUnitList(List<String> units) {
    if (units.isEmpty) return units;
    if (units.length == 1) {
      var type = _typesByUnit[units.first];
      return type == null ? units : [_unitsByType[type].first];
    }

    return units.map((unit) {
      var type = _typesByUnit[unit];
      return type == null ? unit : _unitsByType[type].first;
    }).toList()
      ..sort();
  }

  /// Returns a multiplier that encapsulates unit equivalence in [units].
  ///
  /// That is, if `X units1 == Y units2`, `X * _canonicalMultiplier(units1) == Y
  /// * _canonicalMultiplier(units2)`.
  num _canonicalMultiplier(List<String> units) =>
      units.fold(1, (multiplier, unit) {
        var innerMap = _conversions[unit];
        return innerMap == null
            ? multiplier
            : multiplier / innerMap.values.first;
      });

  /// Throws a [SassScriptException] with the given [message].
  SassScriptException _exception(String message, [String name]) =>
      SassScriptException(name == null ? message : "\$$name: $message");
}
