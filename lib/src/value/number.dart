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
import 'number/complex.dart';
import 'number/single_unit.dart';
import 'number/unitless.dart';

/// A nested map containing unit conversion rates.
///
/// `1unit1 * _conversions[unit2][unit1] = 1unit2`.
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

/// A map from human-readable names of unit types to the convertable units that
/// fall into those types.
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

/// Returns the number of [unit1]s per [unit2].
///
/// Equivalently, `1unit2 * conversionFactor(unit1, unit2) = 1unit1`.
///
/// @nodoc
@internal
num? conversionFactor(String unit1, String unit2) {
  if (unit1 == unit2) return 1;
  var innerMap = _conversions[unit1];
  if (innerMap == null) return null;
  return innerMap[unit2];
}

/// A SassScript number.
///
/// Numbers can have units. Although there's no literal syntax for it, numbers
/// support scientific-style numerator and denominator units (for example,
/// `miles/hour`). These are expected to be resolved before being emitted to
/// CSS.
///
/// {@category Value}
@sealed
abstract class SassNumber extends Value {
  /// The number of distinct digits that are emitted when converting a number to
  /// CSS.
  static const precision = 10;

  // We don't use public fields because they'd be overridden by the getters of
  // the same name in the JS API.

  /// The value of this number.
  ///
  /// Note that due to details of floating-point arithmetic, this may be a
  /// [double] even if [this] represents an int from Sass's perspective. Use
  /// [isInt] to determine whether this is an integer, [asInt] to get its
  /// integer value, or [assertInt] to do both at once.
  num get value => _value;
  final num _value;

  /// The cached hash code for this number, if it's been computed.
  ///
  /// @nodoc
  @protected
  int? hashCache;

  /// This number's numerator units.
  List<String> get numeratorUnits;

  /// This number's denominator units.
  List<String> get denominatorUnits;

  /// Whether [this] has any units.
  ///
  /// If a function expects a number to have no units, it should use
  /// [assertNoUnits]. If it expects the number to have a particular unit, it
  /// should use [assertUnit].
  bool get hasUnits;

  /// The representation of this number as two slash-separated numbers, if it
  /// has one.
  ///
  /// @nodoc
  @internal
  final Tuple2<SassNumber, SassNumber>? asSlash;

  /// Whether [this] is an integer, according to [fuzzyEquals].
  ///
  /// The [int] value can be accessed using [asInt] or [assertInt]. Note that
  /// this may return `false` for very large doubles even though they may be
  /// mathematically integers, because not all platforms have a valid
  /// representation for integers that large.
  bool get isInt => fuzzyIsInt(value);

  /// If [this] is an integer according to [isInt], returns [value] as an [int].
  ///
  /// Otherwise, returns `null`.
  int? get asInt => fuzzyAsInt(value);

  /// Returns a human readable string representation of this number's units.
  String get unitString =>
      hasUnits ? _unitString(numeratorUnits, denominatorUnits) : '';

  /// Creates a number, optionally with a single numerator unit.
  ///
  /// This matches the numbers that can be written as literals.
  /// [SassNumber.withUnits] can be used to construct more complex units.
  factory SassNumber(num value, [String? unit]) => unit == null
      ? UnitlessSassNumber(value)
      : SingleUnitSassNumber(value, unit);

  /// Creates a number with full [numeratorUnits] and [denominatorUnits].
  factory SassNumber.withUnits(num value,
      {List<String>? numeratorUnits, List<String>? denominatorUnits}) {
    if (denominatorUnits == null || denominatorUnits.isEmpty) {
      if (numeratorUnits == null || numeratorUnits.isEmpty) {
        return UnitlessSassNumber(value);
      } else if (numeratorUnits.length == 1) {
        return SingleUnitSassNumber(value, numeratorUnits[0]);
      } else {
        return ComplexSassNumber(
            value, List.unmodifiable(numeratorUnits), const []);
      }
    } else if (numeratorUnits == null || numeratorUnits.isEmpty) {
      return ComplexSassNumber(
          value, const [], List.unmodifiable(denominatorUnits));
    } else {
      var numerators = numeratorUnits.toList();
      var unsimplifiedDenominators = denominatorUnits.toList();

      var denominators = <String>[];
      for (var denominator in unsimplifiedDenominators) {
        var simplifiedAway = false;
        for (var i = 0; i < numerators.length; i++) {
          var factor = conversionFactor(denominator, numerators[i]);
          if (factor == null) continue;
          value *= factor;
          numerators.removeAt(i);
          simplifiedAway = true;
          break;
        }
        if (!simplifiedAway) denominators.add(denominator);
      }

      if (denominatorUnits.isEmpty) {
        if (numeratorUnits.isEmpty) {
          return UnitlessSassNumber(value);
        } else if (numeratorUnits.length == 1) {
          return SingleUnitSassNumber(value, numeratorUnits.single);
        }
      }

      return ComplexSassNumber(value, List.unmodifiable(numerators),
          List.unmodifiable(denominators));
    }
  }

  /// @nodoc
  @protected
  SassNumber.protected(this._value, this.asSlash);

  T accept<T>(ValueVisitor<T> visitor) => visitor.visitNumber(this);

  /// Returns a number with the same units as [this] but with [value] as its
  /// value.
  ///
  /// @nodoc
  @protected
  SassNumber withValue(num value);

  /// Returns a copy of [this] without [asSlash] set.
  ///
  /// @nodoc
  @internal
  SassNumber withoutSlash() => asSlash == null ? this : withValue(value);

  /// Returns a copy of [this] with [asSlash] set to a tuple containing
  /// [numerator] and [denominator].
  ///
  /// @nodoc
  @internal
  SassNumber withSlash(SassNumber numerator, SassNumber denominator);

  SassNumber assertNumber([String? name]) => this;

  /// Returns [value] as an [int], if it's an integer value according to
  /// [isInt].
  ///
  /// Throws a [SassScriptException] if [value] isn't an integer. If this came
  /// from a function argument, [name] is the argument name (without the `$`).
  /// It's used for error reporting.
  int assertInt([String? name]) {
    var integer = fuzzyAsInt(value);
    if (integer != null) return integer;
    throw _exception("$this is not an int.", name);
  }

  /// If [value] is between [min] and [max], returns it.
  ///
  /// If [value] is [fuzzyEquals] to [min] or [max], it's clamped to the
  /// appropriate value. Otherwise, this throws a [SassScriptException]. If this
  /// came from a function argument, [name] is the argument name (without the
  /// `$`). It's used for error reporting.
  num valueInRange(num min, num max, [String? name]) {
    var result = fuzzyCheckRange(value, min, max);
    if (result != null) return result;
    throw _exception(
        "Expected $this to be within $min$unitString and $max$unitString.",
        name);
  }

  /// Returns whether [this] has [unit] as its only unit (and as a numerator).
  bool hasUnit(String unit);

  /// Returns whether [this] has units that are compatible with [other].
  ///
  /// Unlike [isComparableTo], unitless numbers are only considered compatible
  /// with other unitless numbers.
  bool hasCompatibleUnits(SassNumber other) {
    if (numeratorUnits.length != other.numeratorUnits.length) return false;
    if (denominatorUnits.length != other.denominatorUnits.length) return false;
    return isComparableTo(other);
  }

  /// Returns whether [this] has units that are possibly-compatible with
  /// [other], as defined by the Sass spec.
  @internal
  bool hasPossiblyCompatibleUnits(SassNumber other);

  /// Returns whether [this] can be coerced to the given [unit].
  ///
  /// This always returns `true` for a unitless number.
  bool compatibleWithUnit(String unit);

  /// Throws a [SassScriptException] unless [this] has [unit] as its only unit
  /// (and as a numerator).
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  void assertUnit(String unit, [String? name]) {
    if (hasUnit(unit)) return;
    throw _exception('Expected $this to have unit "$unit".', name);
  }

  /// Throws a [SassScriptException] unless [this] has no units.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  void assertNoUnits([String? name]) {
    if (!hasUnits) return;
    throw _exception('Expected $this to have no units.', name);
  }

  /// Returns a copy of this number, converted to the units represented by
  /// [newNumerators] and [newDenominators].
  ///
  /// Note that [convertValue] is generally more efficient if the value is going
  /// to be accessed directly.
  ///
  /// Throws a [SassScriptException] if this number's units aren't compatible
  /// with [other]'s units, or if either number is unitless but the other is
  /// not.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassNumber convert(List<String> newNumerators, List<String> newDenominators,
          [String? name]) =>
      SassNumber.withUnits(convertValue(newNumerators, newDenominators, name),
          numeratorUnits: newNumerators, denominatorUnits: newDenominators);

  /// Returns [value], converted to the units represented by [newNumerators] and
  /// [newDenominators].
  ///
  /// Throws a [SassScriptException] if this number's units aren't compatible
  /// with [other]'s units, or if either number is unitless but the other is
  /// not.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  num convertValue(List<String> newNumerators, List<String> newDenominators,
          [String? name]) =>
      _coerceOrConvertValue(newNumerators, newDenominators,
          coerceUnitless: false, name: name);

  /// Returns a copy of this number, converted to the same units as [other].
  ///
  /// Note that [convertValueToMatch] is generally more efficient if the value
  /// is going to be accessed directly.
  ///
  /// Throws a [SassScriptException] if this number's units aren't compatible
  /// with [other]'s units, or if either number is unitless but the other is
  /// not.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`) and [otherName] is the argument name for [other]. These
  /// are used for error reporting.
  SassNumber convertToMatch(SassNumber other,
          [String? name, String? otherName]) =>
      SassNumber.withUnits(convertValueToMatch(other, name, otherName),
          numeratorUnits: other.numeratorUnits,
          denominatorUnits: other.denominatorUnits);

  /// Returns [value], converted to the same units as [other].
  ///
  /// Throws a [SassScriptException] if this number's units aren't compatible
  /// with [other]'s units, or if either number is unitless but the other is
  /// not.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`) and [otherName] is the argument name for [other]. These
  /// are used for error reporting.
  num convertValueToMatch(SassNumber other,
          [String? name, String? otherName]) =>
      _coerceOrConvertValue(other.numeratorUnits, other.denominatorUnits,
          coerceUnitless: false,
          name: name,
          other: other,
          otherName: otherName);

  /// Returns a copy of this number, converted to the units represented by
  /// [newNumerators] and [newDenominators].
  ///
  /// This does *not* throw an error if this number is unitless and
  /// [newNumerators]/[newDenominators] are not empty, or vice versa. Instead,
  /// it treats all unitless numbers as convertible to and from all units
  /// without changing the value.
  ///
  /// Note that [coerceValue] is generally more efficient if the value is going
  /// to be accessed directly.
  ///
  /// Throws a [SassScriptException] if this number's units aren't compatible
  /// with [newNumerators] and [newDenominators].
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  SassNumber coerce(List<String> newNumerators, List<String> newDenominators,
          [String? name]) =>
      SassNumber.withUnits(coerceValue(newNumerators, newDenominators, name),
          numeratorUnits: newNumerators, denominatorUnits: newDenominators);

  /// Returns [value], converted to the units represented by [newNumerators] and
  /// [newDenominators].
  ///
  /// This does *not* throw an error if this number is unitless and
  /// [newNumerators]/[newDenominators] are not empty, or vice versa. Instead,
  /// it treats all unitless numbers as convertible to and from all units
  /// without changing the value.
  ///
  /// Throws a [SassScriptException] if this number's units aren't compatible
  /// with [newNumerators] and [newDenominators].
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for error reporting.
  num coerceValue(List<String> newNumerators, List<String> newDenominators,
          [String? name]) =>
      _coerceOrConvertValue(newNumerators, newDenominators,
          coerceUnitless: true, name: name);

  /// A shorthand for [coerceValue] with only one numerator unit.
  num coerceValueToUnit(String unit, [String? name]) =>
      coerceValue([unit], [], name);

  /// Returns a copy of this number, converted to the same units as [other].
  ///
  /// Unlike [convertToMatch], this does *not* throw an error if this number is
  /// unitless and [other] is not, or vice versa. Instead, it treats all
  /// unitless numbers as convertible to and from all units without changing the
  /// value.
  ///
  /// Note that [coerceValueToMatch] is generally more efficient if the value is
  /// going to be accessed directly.
  ///
  /// Throws a [SassScriptException] if this number's units aren't compatible
  /// with [other]'s units.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`) and [otherName] is the argument name for [other]. These
  /// are used for error reporting.
  SassNumber coerceToMatch(SassNumber other,
          [String? name, String? otherName]) =>
      SassNumber.withUnits(coerceValueToMatch(other, name, otherName),
          numeratorUnits: other.numeratorUnits,
          denominatorUnits: other.denominatorUnits);

  /// Returns [value], converted to the same units as [other].
  ///
  /// Unlike [convertValueToMatch], this does *not* throw an error if this
  /// number is unitless and [other] is not, or vice versa. Instead, it treats
  /// all unitless numbers as convertible to and from all units without changing
  /// the value.
  ///
  /// Throws a [SassScriptException] if this number's units aren't compatible
  /// with [other]'s units.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`) and [otherName] is the argument name for [other]. These
  /// are used for error reporting.
  num coerceValueToMatch(SassNumber other, [String? name, String? otherName]) =>
      _coerceOrConvertValue(other.numeratorUnits, other.denominatorUnits,
          coerceUnitless: true, name: name, other: other, otherName: otherName);

  /// This has been renamed [coerceValue] for consistency with [coerceToMatch],
  /// [coerceValueToMatch], [convertToMatch], and [convertValueToMatch].
  @Deprecated("Use coerceValue instead.")
  num valueInUnits(List<String> newNumerators, List<String> newDenominators,
          [String? name]) =>
      coerceValue(newNumerators, newDenominators, name);

  /// Converts [value] to [newNumerators] and [newDenominators].
  ///
  /// If [coerceUnitless] is `true`, this considers unitless numbers convertible
  /// to and from any unit. Otherwise, it will throw a [SassScriptException] for
  /// such a conversion.
  ///
  /// If [other] is passed, it should be the number from which [newNumerators]
  /// and [newDenominators] are derived. The [name] and [otherName] are the Sass
  /// function parameter names of [this] and [other], respectively, used for
  /// error reporting.
  num _coerceOrConvertValue(
      List<String> newNumerators, List<String> newDenominators,
      {required bool coerceUnitless,
      String? name,
      SassNumber? other,
      String? otherName}) {
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
                "(${_unitsByType[type]!.join(', ')}).",
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
        var factor = conversionFactor(newNumerator, oldNumerator);
        if (factor == null) return false;
        value *= factor;
        return true;
      }, orElse: () => throw _compatibilityException());
    }

    var oldDenominators = denominatorUnits.toList();
    for (var newDenominator in newDenominators) {
      removeFirstWhere<String>(oldDenominators, (oldDenominator) {
        var factor = conversionFactor(newDenominator, oldDenominator);
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
  ///
  /// @nodoc
  @internal
  bool isComparableTo(SassNumber other) {
    if (!hasUnits || !other.hasUnits) return true;
    try {
      greaterThan(other);
      return true;
    } on SassScriptException {
      return false;
    }
  }

  /// @nodoc
  @internal
  SassBoolean greaterThan(Value other) {
    if (other is SassNumber) {
      return SassBoolean(_coerceUnits(other, fuzzyGreaterThan));
    }
    throw SassScriptException('Undefined operation "$this > $other".');
  }

  /// @nodoc
  @internal
  SassBoolean greaterThanOrEquals(Value other) {
    if (other is SassNumber) {
      return SassBoolean(_coerceUnits(other, fuzzyGreaterThanOrEquals));
    }
    throw SassScriptException('Undefined operation "$this >= $other".');
  }

  /// @nodoc
  @internal
  SassBoolean lessThan(Value other) {
    if (other is SassNumber) {
      return SassBoolean(_coerceUnits(other, fuzzyLessThan));
    }
    throw SassScriptException('Undefined operation "$this < $other".');
  }

  /// @nodoc
  @internal
  SassBoolean lessThanOrEquals(Value other) {
    if (other is SassNumber) {
      return SassBoolean(_coerceUnits(other, fuzzyLessThanOrEquals));
    }
    throw SassScriptException('Undefined operation "$this <= $other".');
  }

  /// @nodoc
  @internal
  Value modulo(Value other) {
    if (other is SassNumber) {
      return withValue(_coerceUnits(other, moduloLikeSass));
    }
    throw SassScriptException('Undefined operation "$this % $other".');
  }

  /// Return [num1] modulo [num2], using Sass's modulo semantics, which it
  /// inherited from Ruby and which differ from Dart's.
  ///
  /// @nodoc
  @internal
  num moduloLikeSass(num num1, num num2) {
    if (num2 > 0) return num1 % num2;
    if (num2 == 0) return double.nan;

    // Dart has different mod-negative semantics than Ruby, and thus than
    // Sass.
    var result = num1 % num2;
    return result == 0 ? 0 : result + num2;
  }

  /// @nodoc
  @internal
  Value plus(Value other) {
    if (other is SassNumber) {
      return withValue(_coerceUnits(other, (num1, num2) => num1 + num2));
    }
    if (other is! SassColor) return super.plus(other);
    throw SassScriptException('Undefined operation "$this + $other".');
  }

  /// @nodoc
  @internal
  Value minus(Value other) {
    if (other is SassNumber) {
      return withValue(_coerceUnits(other, (num1, num2) => num1 - num2));
    }
    if (other is! SassColor) return super.minus(other);
    throw SassScriptException('Undefined operation "$this - $other".');
  }

  /// @nodoc
  @internal
  Value times(Value other) {
    if (other is SassNumber) {
      if (!other.hasUnits) return withValue(value * other.value);
      return multiplyUnits(
          value * other.value, other.numeratorUnits, other.denominatorUnits);
    }
    throw SassScriptException('Undefined operation "$this * $other".');
  }

  /// @nodoc
  @internal
  Value dividedBy(Value other) {
    if (other is SassNumber) {
      if (!other.hasUnits) return withValue(value / other.value);
      return multiplyUnits(
          value / other.value, other.denominatorUnits, other.numeratorUnits);
    }
    return super.dividedBy(other);
  }

  /// @nodoc
  @internal
  Value unaryPlus() => this;

  /// Converts [other]'s value to be compatible with this number's, and calls
  /// [operation] with the resulting numbers.
  ///
  /// Throws a [SassScriptException] if the two numbers' units are incompatible.
  ///
  /// @nodoc
  @protected
  T _coerceUnits<T>(SassNumber other, T operation(num num1, num num2)) {
    try {
      return operation(value, other.coerceValueToMatch(this));
    } on SassScriptException {
      // If the conversion fails, re-run it in the other direction. This will
      // generate an error message that prints [this] before [other], which is
      // more readable.
      coerceValueToMatch(other);
      rethrow; // This should be unreachable.
    }
  }

  /// Returns a new number that's equivalent to `value
  /// this.numeratorUnits/this.denominatorUnits * 1
  /// otherNumerators/otherDenominators`.
  ///
  /// @nodoc
  @protected
  SassNumber multiplyUnits(
      num value, List<String> otherNumerators, List<String> otherDenominators) {
    // Short-circuit without allocating any new unit lists if possible.
    if (numeratorUnits.isEmpty) {
      if (otherDenominators.isEmpty &&
          !_areAnyConvertible(denominatorUnits, otherNumerators)) {
        return SassNumber.withUnits(value,
            numeratorUnits: otherNumerators,
            denominatorUnits: denominatorUnits);
      } else if (denominatorUnits.isEmpty) {
        return SassNumber.withUnits(value,
            numeratorUnits: otherNumerators,
            denominatorUnits: otherDenominators);
      }
    } else if (otherNumerators.isEmpty) {
      if (otherDenominators.isEmpty) {
        return SassNumber.withUnits(value,
            numeratorUnits: numeratorUnits,
            denominatorUnits: otherDenominators);
      } else if (denominatorUnits.isEmpty &&
          !_areAnyConvertible(numeratorUnits, otherDenominators)) {
        return SassNumber.withUnits(value,
            numeratorUnits: numeratorUnits,
            denominatorUnits: otherDenominators);
      }
    }

    var newNumerators = <String>[];
    var mutableOtherDenominators = otherDenominators.toList();
    for (var numerator in numeratorUnits) {
      removeFirstWhere<String>(mutableOtherDenominators, (denominator) {
        var factor = conversionFactor(numerator, denominator);
        if (factor == null) return false;
        value /= factor;
        return true;
      }, orElse: () => newNumerators.add(numerator));
    }

    var mutableDenominatorUnits = denominatorUnits.toList();
    for (var numerator in otherNumerators) {
      removeFirstWhere<String>(mutableDenominatorUnits, (denominator) {
        var factor = conversionFactor(numerator, denominator);
        if (factor == null) return false;
        value /= factor;
        return true;
      }, orElse: () => newNumerators.add(numerator));
    }

    return SassNumber.withUnits(value,
        numeratorUnits: newNumerators,
        denominatorUnits: mutableDenominatorUnits
          ..addAll(mutableOtherDenominators));
  }

  /// Returns whether there exists a unit in [units1] that can be converted to a
  /// unit in [units2].
  bool _areAnyConvertible(List<String> units1, List<String> units2) {
    return units1.any((unit1) {
      var innerMap = _conversions[unit1];
      if (innerMap == null) return units2.contains(unit1);
      return units2.any(innerMap.containsKey);
    });
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

  int get hashCode => hashCache ??= fuzzyHashCode(value *
      _canonicalMultiplier(numeratorUnits) /
      _canonicalMultiplier(denominatorUnits));

  /// Converts a unit list (such as [numeratorUnits]) into an equivalent list in
  /// a canonical form, to make it easier to check whether two numbers have
  /// compatible units.
  List<String> _canonicalizeUnitList(List<String> units) {
    if (units.isEmpty) return units;
    if (units.length == 1) {
      var type = _typesByUnit[units.first];
      return type == null ? units : [_unitsByType[type]!.first];
    }

    return units.map((unit) {
      var type = _typesByUnit[unit];
      return type == null ? unit : _unitsByType[type]!.first;
    }).toList()
      ..sort();
  }

  /// Returns a multiplier that encapsulates unit equivalence in [units].
  ///
  /// That is, if `X units1 == Y units2`, `X * _canonicalMultiplier(units1) == Y
  /// * _canonicalMultiplier(units2)`.
  num _canonicalMultiplier(List<String> units) => units.fold(
      1, (multiplier, unit) => multiplier * canonicalMultiplierForUnit(unit));

  /// Returns a multiplier that encapsulates unit equivalence with [unit].
  ///
  /// That is, if `X unit1 == Y unit2`, `X * canonicalMultiplierForUnit(unit1)
  /// == Y * canonicalMultiplierForUnit(unit2)`.
  ///
  /// @nodoc
  @protected
  num canonicalMultiplierForUnit(String unit) {
    var innerMap = _conversions[unit];
    return innerMap == null ? 1 : 1 / innerMap.values.first;
  }

  /// Throws a [SassScriptException] with the given [message].
  SassScriptException _exception(String message, [String? name]) =>
      SassScriptException(name == null ? message : "\$$name: $message");
}
