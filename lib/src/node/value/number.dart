// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../value.dart';
import '../../util/nullable.dart';
import '../immutable.dart';
import '../reflection.dart';

/// The JavaScript `SassNumber` class.
final JSClass numberClass = () {
  var jsClass = createJSClass('sass.SassNumber', (Object self, num value,
      [Object? unitOrOptions]) {
    if (unitOrOptions is String) return SassNumber(value, unitOrOptions);

    var options = unitOrOptions as _ConstructorOptions?;
    return SassNumber.withUnits(value,
        numeratorUnits:
            options?.numeratorUnits.andThen(jsToDartList)?.cast<String>(),
        denominatorUnits:
            options?.denominatorUnits.andThen(jsToDartList)?.cast<String>());
  });

  jsClass.defineGetters({
    'value': (SassNumber self) => self.value,
    'isInt': (SassNumber self) => self.isInt,
    'asInt': (SassNumber self) => self.asInt,
    'numeratorUnits': (SassNumber self) => ImmutableList(self.numeratorUnits),
    'denominatorUnits': (SassNumber self) =>
        ImmutableList(self.denominatorUnits),
    'hasUnits': (SassNumber self) => self.hasUnits,
  });

  jsClass.defineMethods({
    'assertInt': (SassNumber self, [String? name]) => self.assertInt(name),
    'assertInRange': (SassNumber self, num min, num max, [String? name]) =>
        self.valueInRange(min, max, name),
    'assertNoUnits': (SassNumber self, [String? name]) =>
        self.assertNoUnits(name),
    'assertUnit': (SassNumber self, String unit, [String? name]) =>
        self.assertUnit(unit, name),
    'hasUnit': (SassNumber self, String unit) => self.hasUnit(unit),
    'compatibleWithUnit': (SassNumber self, String unit) =>
        self.hasUnits && self.compatibleWithUnit(unit),
    'convert': (SassNumber self, Object numeratorUnits, Object denominatorUnits,
            [String? name]) =>
        self.convert(jsToDartList(numeratorUnits).cast<String>(),
            jsToDartList(denominatorUnits).cast<String>(), name),
    'convertToMatch': (SassNumber self, SassNumber other,
            [String? name, String? otherName]) =>
        self.convertToMatch(other, name, otherName),
    'convertValue': (SassNumber self, Object numeratorUnits,
            Object denominatorUnits, [String? name]) =>
        self.convertValue(jsToDartList(numeratorUnits).cast<String>(),
            jsToDartList(denominatorUnits).cast<String>(), name),
    'convertValueToMatch': (SassNumber self, SassNumber other,
            [String? name, String? otherName]) =>
        self.convertValueToMatch(other, name, otherName),
    'coerce': (SassNumber self, Object numeratorUnits, Object denominatorUnits,
            [String? name]) =>
        self.coerce(jsToDartList(numeratorUnits).cast<String>(),
            jsToDartList(denominatorUnits).cast<String>(), name),
    'coerceToMatch': (SassNumber self, SassNumber other,
            [String? name, String? otherName]) =>
        self.coerceToMatch(other, name, otherName),
    'coerceValue': (SassNumber self, Object numeratorUnits,
            Object denominatorUnits, [String? name]) =>
        self.coerceValue(jsToDartList(numeratorUnits).cast<String>(),
            jsToDartList(denominatorUnits).cast<String>(), name),
    'coerceValueToMatch': (SassNumber self, SassNumber other,
            [String? name, String? otherName]) =>
        self.coerceValueToMatch(other, name, otherName),
  });

  // Our concrete number types are actually subclasses of [SassNumber], so we
  // have to go up one in the superclass chain to inject [jsClass].
  getJSClass(SassNumber(0)).superclass.injectSuperclass(jsClass);

  return jsClass;
}();

@JS()
@anonymous
class _ConstructorOptions {
  external Object? get numeratorUnits;
  external Object? get denominatorUnits;
}
