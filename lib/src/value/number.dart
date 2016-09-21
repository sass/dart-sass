// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import '../exception.dart';
import '../utils.dart';
import '../visitor/interface/value.dart';
import '../value.dart';

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
class SassNumber extends Value {
  static const precision = 10;

  final num value;

  final List<String> numeratorUnits;

  final List<String> denominatorUnits;

  bool get hasUnits => numeratorUnits.isNotEmpty || denominatorUnits.isNotEmpty;

  bool get isInt => value is int || fuzzyEquals(value % 1, 0.0);

  int get asInt {
    if (!isInt) throw new InternalException("$this is not an int.");
    return value.round();
  }

  String get unitString {
    if (numeratorUnits.isEmpty && denominatorUnits.isEmpty) return '';
    return _unitString(numeratorUnits, denominatorUnits);
  }

  SassNumber(num value, [String unit])
      : this.withUnits(value, numeratorUnits: unit == null ? null : [unit]);

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

  num valueInRange(num min, num max, [String name]) {
    var result = fuzzyCheckRange(value, min, max);
    if (result != null) return result;
    var message =
        "Expected $this to be within $min$unitString and $max$unitString.";
    throw new InternalException(name == null ? message : "\$$name: $message");
  }

  /// Returns whether [this] has [unit] as its only unit (and as a numerator).
  bool hasUnit(String unit) =>
      numeratorUnits.length == 1 &&
      denominatorUnits.isEmpty &&
      numeratorUnits.first == unit;

  void assertUnit(String unit, [String name]) {
    if (hasUnit(unit)) return;
    var message = 'Expected $this to have unit "$unit".';
    if (name != null) message = "\$$name: $message";
    throw new InternalException(message);
  }

  num valueInUnits(List<String> newNumerators, List<String> newDenominators) {
    if ((newNumerators.isEmpty && newDenominators.isEmpty) ||
        (numeratorUnits.isEmpty && denominatorUnits.isEmpty) ||
        (listEquals(numeratorUnits, newNumerators) &&
            listEquals(denominatorUnits, newDenominators))) {
      return this.value;
    }

    var value = this.value;
    var mutableDenominators = denominatorUnits.toList();
    for (var numerator in newNumerators) {
      removeFirstWhere(mutableDenominators, (denominator) {
        var factor = _conversionFactor(numerator, denominator);
        if (factor == null) return false;
        value *= factor;
        return true;
      }, orElse: () {
        throw new InternalException("Incompatible units "
            "${_unitString(this.numeratorUnits, this.denominatorUnits)} and "
            "${_unitString(newNumerators, newDenominators)}.");
      });
    }

    var mutableNumerators = numeratorUnits.toList();
    for (var denominator in newDenominators) {
      removeFirstWhere(mutableNumerators, (numerator) {
        var factor = _conversionFactor(denominator, numerator);
        if (factor == null) return false;
        value *= factor;
        return true;
      }, orElse: () {
        throw new InternalException("Incompatible units "
            "${_unitString(this.numeratorUnits, this.denominatorUnits)} and "
            "${_unitString(newNumerators, newDenominators)}.");
      });
    }

    return value;
  }

  SassBoolean greaterThan(Value other) {
    if (other is SassNumber) {
      return _coerceUnits(other, (num1, num2) => fuzzyGreaterThan(num1, num2));
    }
    throw new InternalException('Undefined operation "$this > $other".');
  }

  SassBoolean greaterThanOrEquals(Value other) {
    if (other is SassNumber) {
      return _coerceUnits(
          other, (num1, num2) => fuzzyGreaterThanOrEquals(num1, num2));
    }
    throw new InternalException('Undefined operation "$this >= $other".');
  }

  SassBoolean lessThan(Value other) {
    if (other is SassNumber) {
      return _coerceUnits(other, (num1, num2) => fuzzyLessThan(num1, num2));
    }
    throw new InternalException('Undefined operation "$this < $other".');
  }

  SassBoolean lessThanOrEquals(Value other) {
    if (other is SassNumber) {
      return _coerceUnits(
          other, (num1, num2) => fuzzyLessThanOrEquals(num1, num2));
    }
    throw new InternalException('Undefined operation "$this <= $other".');
  }

  Value modulo(Value other) {
    if (other is SassNumber) {
      return _coerceUnits(other, (num1, num2) => num1 % num2);
    }
    throw new InternalException('Undefined operation "$this % $other".');
  }

  Value plus(Value other) {
    if (other is SassNumber) {
      return _coerceUnits(other, (num1, num2) => num1 + num2);
    }
    if (other is! SassColor) return super.plus(other);
    throw new InternalException('Undefined operation "$this + $other".');
  }

  Value minus(Value other) {
    if (other is SassNumber) {
      return _coerceUnits(other, (num1, num2) => num1 - num2);
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

  bool _isConvertable(String unit) => _conversions.containsKey(unit);

  // Returns [unit1]s per [unit2].
  int _conversionFactor(String unit1, String unit2) {
    var innerMap = _conversions[unit1];
    if (innerMap == null) return null;
    return innerMap[unit2];
  }

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
}
