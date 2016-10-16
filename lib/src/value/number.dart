// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import '../exception.dart';
import '../util/number.dart';
import '../utils.dart';
import '../value.dart';
import '../visitor/interface/value.dart';

/// A nested map containing unit conversion rates.
///
/// `1unit1 * _conversions[unit1][unit2] = 1unit2`.
final _conversions = {
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
    "rad": 180 / math.PI,
    "turn": 360,
  },
  "grad": {
    "deg": 10 / 9,
    "grad": 1,
    "rad": 200 / math.PI,
    "turn": 400,
  },
  "rad": {
    "deg": math.PI / 180,
    "grad": math.PI / 200,
    "rad": 1,
    "turn": 2 * math.PI,
  },
  "turn": {
    "deg": 1 / 360,
    "grad": 1 / 400,
    "rad": 1 / (2 * math.PI),
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
    "dpcm": 1 / 2.54,
    "dppx": 1 / 96,
  },
  "dpcm": {
    "dpi": 2.54,
    "dpcm": 1,
    "dppx": 2.54 / 96,
  },
  "dppx": {
    "dpi": 96,
    "dpcm": 96 / 2.54,
    "dppx": 1,
  },
};

// TODO(nweiz): If it's faster, add subclasses specifically for unitless numbers
// and numbers with only a single numerator unit. These should be opaque to
// users of SassNumber.

/// A SassScript number.
///
/// Numbers can have units. Although there's no literal syntax for it, numbers
/// support scientific-style numerator and denominator units (for example,
/// `miles/hour`). These are expected to be resolved before being emitted to
/// CSS.
class SassNumber extends Value {
  /// The number of distinct digits that are emitted when converting a number to
  /// CSS.
  static const precision = 10;

  /// The value of this number.
  final num value;

  /// This number's numerator units.
  final List<String> numeratorUnits;

  /// This number's denominator units.
  final List<String> denominatorUnits;

  /// Whether [this] has any units.
  bool get hasUnits => numeratorUnits.isNotEmpty || denominatorUnits.isNotEmpty;

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
  int get asInt => fuzzyAsInt(value);

  /// Returns a human readable string representation of this number's units.
  String get unitString =>
      hasUnits ? _unitString(numeratorUnits, denominatorUnits) : '';

  /// Returns a number, optionally with a single numerator unit.
  ///
  /// This matches the numbers that can be written as literals.
  /// [SassNumber.withUnits] can be used to construct more complex units.
  SassNumber(num value, [String unit])
      : this.withUnits(value, numeratorUnits: unit == null ? null : [unit]);

  /// Returns a number with full [numeratorUnits] and [denominatorUnits].
  SassNumber.withUnits(this.value,
      {Iterable<String> numeratorUnits, Iterable<String> denominatorUnits})
      : numeratorUnits = numeratorUnits == null
            ? const []
            : new List.unmodifiable(numeratorUnits),
        denominatorUnits = denominatorUnits == null
            ? const []
            : new List.unmodifiable(denominatorUnits);

  /*=T*/ accept/*<T>*/(ValueVisitor/*<T>*/ visitor) =>
      visitor.visitNumber(this);

  SassNumber assertNumber([String name]) => this;

  /// Returns [value] as an [int], if it's an integer value according to
  /// [isInt].
  ///
  /// Throws an [InternalException] if [value] isn't an integer. If this came
  /// from a function argument, [name] is the argument name (without the `$`).
  /// It's used for debugging.
  int assertInt([String name]) {
    var integer = fuzzyAsInt(value);
    if (integer != null) return integer;
    throw _exception("$this is not an int.", name);
  }

  /// Asserts that this is a valid Sass-style index for [list], and returns the
  /// Dart-style index.
  ///
  /// A Sass-style index is one-based, and uses negative numbers to count
  /// backwards from the end of the list.
  ///
  /// Throws an [InternalException] if this isn't an integer or if it isn't a
  /// valid index for [list]. If this came from a function argument, [name] is
  /// the argument name (without the `$`). It's used for debugging.
  int assertIndexFor(List list, [String name]) {
    var sassIndex = assertInt(name);
    if (sassIndex == 0) throw _exception("List index may not be 0.");
    if (sassIndex.abs() > list.length) {
      throw _exception(
          "Invalid index $this for a list with ${list.length} elements.");
    }

    return sassIndex < 0 ? list.length + sassIndex : sassIndex - 1;
  }

  /// If [value] is between [min] and [max], returns it.
  ///
  /// If [value] is [fuzzyEquals] to [min] or [max], it's clamped to the
  /// appropriate value. Otherwise, this throws an [InternalException]. If this
  /// came from a function argument, [name] is the argument name (without the
  /// `$`). It's used for debugging.
  num valueInRange(num min, num max, [String name]) {
    var result = fuzzyCheckRange(value, min, max);
    if (result != null) return result;
    throw _exception(
        "Expected $this to be within $min$unitString and $max$unitString.");
  }

  /// Returns whether [this] has [unit] as its only unit (and as a numerator).
  bool hasUnit(String unit) =>
      numeratorUnits.length == 1 &&
      denominatorUnits.isEmpty &&
      numeratorUnits.first == unit;

  /// Throws an [InternalException] unless [this] has [unit] as its only unit
  /// (and as a numerator).
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for debugging.
  void assertUnit(String unit, [String name]) {
    if (hasUnit(unit)) return;
    throw _exception('Expected $this to have unit "$unit".');
  }

  /// Throws an [InternalException] unless [this] has no units.
  ///
  /// If this came from a function argument, [name] is the argument name
  /// (without the `$`). It's used for debugging.
  void assertNoUnits([String name]) {
    if (!hasUnits) return;
    throw _exception('Expected $this to have no units.');
  }

  /// Returns [value], converted to the units represented by [newNumerators] and
  /// [newDenominators].
  ///
  /// Throws an [InternalException] if this number's units aren't compatible
  /// with [newNumerators] and [newDenominators].
  num valueInUnits(List<String> newNumerators, List<String> newDenominators) {
    if ((newNumerators.isEmpty && newDenominators.isEmpty) ||
        (numeratorUnits.isEmpty && denominatorUnits.isEmpty) ||
        (listEquals(numeratorUnits, newNumerators) &&
            listEquals(denominatorUnits, newDenominators))) {
      return this.value;
    }

    var value = this.value;
    var oldNumerators = numeratorUnits.toList();
    for (var newNumerator in newNumerators) {
      removeFirstWhere(oldNumerators, (oldNumerator) {
        var factor = _conversionFactor(newNumerator, oldNumerator);
        if (factor == null) return false;
        value *= factor;
        return true;
      }, orElse: () {
        throw new InternalException("Incompatible units "
            "${_unitString(this.numeratorUnits, this.denominatorUnits)} and "
            "${_unitString(newNumerators, newDenominators)}.");
      });
    }

    var oldDenominators = denominatorUnits.toList();
    for (var newDenominator in newDenominators) {
      removeFirstWhere(oldDenominators, (oldDenominator) {
        var factor = _conversionFactor(newDenominator, oldDenominator);
        if (factor == null) return false;
        value *= factor;
        return true;
      }, orElse: () {
        throw new InternalException("Incompatible units "
            "${_unitString(this.numeratorUnits, this.denominatorUnits)} and "
            "${_unitString(newNumerators, newDenominators)}.");
      });
    }

    if (oldNumerators.isNotEmpty || oldDenominators.isNotEmpty) {
      throw new InternalException("Incompatible units "
          "${_unitString(this.numeratorUnits, this.denominatorUnits)} and "
          "${_unitString(newNumerators, newDenominators)}.");
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
    } on InternalException {
      return false;
    }
  }

  SassBoolean greaterThan(Value other) {
    if (other is SassNumber) {
      return new SassBoolean(
          _coerceUnits(other, (num1, num2) => fuzzyGreaterThan(num1, num2)));
    }
    throw new InternalException('Undefined operation "$this > $other".');
  }

  SassBoolean greaterThanOrEquals(Value other) {
    if (other is SassNumber) {
      return new SassBoolean(_coerceUnits(
          other, (num1, num2) => fuzzyGreaterThanOrEquals(num1, num2)));
    }
    throw new InternalException('Undefined operation "$this >= $other".');
  }

  SassBoolean lessThan(Value other) {
    if (other is SassNumber) {
      return new SassBoolean(
          _coerceUnits(other, (num1, num2) => fuzzyLessThan(num1, num2)));
    }
    throw new InternalException('Undefined operation "$this < $other".');
  }

  SassBoolean lessThanOrEquals(Value other) {
    if (other is SassNumber) {
      return new SassBoolean(_coerceUnits(
          other, (num1, num2) => fuzzyLessThanOrEquals(num1, num2)));
    }
    throw new InternalException('Undefined operation "$this <= $other".');
  }

  Value modulo(Value other) {
    if (other is SassNumber) {
      return new SassNumber(_coerceUnits(other, (num1, num2) => num1 % num2));
    }
    throw new InternalException('Undefined operation "$this % $other".');
  }

  Value plus(Value other) {
    if (other is SassNumber) {
      return new SassNumber(_coerceUnits(other, (num1, num2) => num1 + num2));
    }
    if (other is! SassColor) return super.plus(other);
    throw new InternalException('Undefined operation "$this + $other".');
  }

  Value minus(Value other) {
    if (other is SassNumber) {
      return new SassNumber(_coerceUnits(other, (num1, num2) => num1 - num2));
    }
    if (other is! SassColor) return super.minus(other);
    throw new InternalException('Undefined operation "$this - $other".');
  }

  Value times(Value other) {
    if (other is SassNumber) {
      return _multiplyUnits(this.value * other.value, this.numeratorUnits,
          this.denominatorUnits, other.numeratorUnits, other.denominatorUnits);
    }
    throw new InternalException('Undefined operation "$this * $other".');
  }

  Value dividedBy(Value other) {
    if (other is SassNumber) {
      return _multiplyUnits(this.value / other.value, this.numeratorUnits,
          this.denominatorUnits, other.denominatorUnits, other.numeratorUnits);
    }
    if (other is! SassColor) super.dividedBy(other);
    throw new InternalException('Undefined operation "$this / $other".');
  }

  Value unaryPlus() => this;

  Value unaryMinus() => new SassNumber(-value);

  /// Converts [other]'s value to be compatible with this number's, and calls
  /// [operation] with the resulting numbers.
  ///
  /// Throws an [InternalException] if the two numbers' units are incompatible.
  /*=T*/ _coerceUnits/*<T>*/(
      SassNumber other, /*=T*/ operation(num num1, num num2)) {
    num num1;
    num num2;
    if (hasUnits) {
      num1 = this.value;
      num2 = other.valueInUnits(this.numeratorUnits, this.denominatorUnits);
    } else {
      num1 = this.valueInUnits(other.numeratorUnits, other.denominatorUnits);
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
      if (denominators1.isEmpty) {
        return new SassNumber.withUnits(value,
            numeratorUnits: numerators2, denominatorUnits: denominators2);
      } else if (denominators2.isEmpty) {
        return new SassNumber.withUnits(value,
            numeratorUnits: numerators2, denominatorUnits: denominators1);
      }
    } else if (numerators2.isEmpty) {
      if (denominators1.isEmpty) {
        return new SassNumber.withUnits(value,
            numeratorUnits: numerators1, denominatorUnits: denominators2);
      } else if (denominators2.isEmpty) {
        return new SassNumber.withUnits(value,
            numeratorUnits: numerators1, denominatorUnits: denominators2);
      }
    }

    var newNumerators = <String>[];
    var mutableDenominators2 = denominators2.toList();
    for (var numerator in numerators1) {
      if (!_isConvertable(numerator)) {
        newNumerators.add(numerator);
        continue;
      }

      removeFirstWhere(mutableDenominators2, (denominator) {
        var factor = _conversionFactor(numerator, denominator);
        if (factor == null) return false;
        value *= factor;
      }, orElse: () {
        newNumerators.add(numerator);
      });
    }

    var mutableDenominators1 = denominators1.toList();
    for (var numerator in numerators2) {
      if (!_isConvertable(numerator)) {
        newNumerators.add(numerator);
        continue;
      }

      removeFirstWhere(mutableDenominators1, (denominator) {
        var factor = _conversionFactor(numerator, denominator);
        if (factor == null) return false;
        value *= factor;
      }, orElse: () {
        newNumerators.add(numerator);
      });
    }

    return new SassNumber.withUnits(value,
        numeratorUnits: newNumerators,
        denominatorUnits: mutableDenominators1..addAll(mutableDenominators2));
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

  bool operator ==(other) =>
      other is SassNumber && fuzzyEquals(value, other.value);

  int get hashCode => fuzzyHashCode(value);

  /// Throws an [InternalException] with the given [message].
  InternalException _exception(String message, [String name]) =>
      new InternalException(name == null ? message : "\$$name: $message");
}
