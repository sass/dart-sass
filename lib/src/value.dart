// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:sass/sass.dart' as sass;
import 'package:sass_embedded/src/embedded_sass.pb.dart';

import 'dispatcher.dart';
import 'function_registry.dart';
import 'host_callable.dart';
import 'utils.dart';

/// Converts [value] to its protocol buffer representation.
///
/// The [functions] tracks the IDs of first-class functions so that the host can
/// pass them back to the compiler.
Value protofyValue(FunctionRegistry functions, sass.Value value) {
  var result = Value();
  if (value is sass.SassString) {
    result.string = Value_String()
      ..text = value.text
      ..quoted = value.hasQuotes;
  } else if (value is sass.SassNumber) {
    var number = Value_Number()..value = value.value * 1.0;
    number.numerators.addAll(value.numeratorUnits);
    number.denominators.addAll(value.denominatorUnits);
    result.number = number;
  } else if (value is sass.SassColor) {
    // TODO(nweiz): If the color is represented as HSL internally, this coerces
    // it to RGB. Is it worth providing some visibility into its internal
    // representation so we can serialize without converting?
    result.rgbColor = Value_RgbColor()
      ..red = value.red
      ..green = value.green
      ..blue = value.blue
      ..alpha = value.alpha * 1.0;
  } else if (value is sass.SassList) {
    var list = Value_List()
      ..separator = _protofySeparator(value.separator)
      ..hasBrackets = value.hasBrackets
      ..contents.addAll(
          [for (var element in value.asList) protofyValue(functions, element)]);
    result.list = list;
  } else if (value is sass.SassMap) {
    var map = Value_Map();
    value.contents.forEach((key, value) {
      map.entries.add(Value_Map_Entry()
        ..key = protofyValue(functions, key)
        ..value = protofyValue(functions, value));
    });
    result.map = map;
  } else if (value is sass.SassFunction) {
    result.compilerFunction = functions.protofy(value);
  } else if (value == sass.sassTrue) {
    result.singleton = Value_Singleton.TRUE;
  } else if (value == sass.sassFalse) {
    result.singleton = Value_Singleton.FALSE;
  } else if (value == sass.sassNull) {
    result.singleton = Value_Singleton.NULL;
  } else {
    throw "Unknown Value $value";
  }
  return result;
}

/// Converts [separator] to its protocol buffer representation.
Value_List_Separator _protofySeparator(sass.ListSeparator separator) {
  switch (separator) {
    case sass.ListSeparator.comma:
      return Value_List_Separator.COMMA;
    case sass.ListSeparator.space:
      return Value_List_Separator.SPACE;
    case sass.ListSeparator.undecided:
      return Value_List_Separator.UNDECIDED;
    default:
      throw "Unknown ListSeparator $separator";
  }
}

/// Converts [value] to its Sass representation.
///
/// The [functions] tracks the IDs of first-class functions so that they can be
/// deserialized to their original references.
sass.Value deprotofyValue(Dispatcher dispatcher, FunctionRegistry functions,
    int compilationId, Value value) {
  // Curry recursive calls to this function so we don't have to keep repeating
  // ourselves.
  var deprotofy = (Value value) =>
      deprotofyValue(dispatcher, functions, compilationId, value);

  switch (value.whichValue()) {
    case Value_Value.string:
      return value.string.text.isEmpty
          ? sass.SassString.empty(quotes: value.string.quoted)
          : sass.SassString(value.string.text, quotes: value.string.quoted);

    case Value_Value.number:
      return sass.SassNumber.withUnits(value.number.value,
          numeratorUnits: value.number.numerators,
          denominatorUnits: value.number.denominators);

    case Value_Value.rgbColor:
      return sass.SassColor.rgb(
          _checkInRange('RgbColor.red', value.rgbColor.red, 0, 255),
          _checkInRange('RgbColor.green', value.rgbColor.green, 0, 255),
          _checkInRange('RgbColor.blue', value.rgbColor.blue, 0, 255),
          _checkInRange('RgbColor.alpha', value.rgbColor.alpha, 0, 1));

    case Value_Value.hslColor:
      return sass.SassColor.hsl(
          value.hslColor.hue,
          _checkInRange(
              'HslColor.saturation', value.hslColor.saturation, 0, 100),
          _checkInRange('HslColor.lightness', value.hslColor.lightness, 0, 100),
          _checkInRange('HslColor.alpha', value.hslColor.alpha, 0, 1));

    case Value_Value.list:
      var separator = _deprotofySeparator(value.list.separator);
      if (value.list.contents.isEmpty) {
        return sass.SassList.empty(
            separator: separator, brackets: value.list.hasBrackets);
      }

      var length = value.list.contents.length;
      if (separator == sass.ListSeparator.undecided && length > 1) {
        throw paramsError(
            "List $value can't have an undecided separator because it has "
            "$length elements");
      }

      return sass.SassList([
        for (var element in value.list.contents) deprotofy(element)
      ], separator, brackets: value.list.hasBrackets);

    case Value_Value.map:
      return value.map.entries.isEmpty
          ? const sass.SassMap.empty()
          : sass.SassMap({
              for (var entry in value.map.entries)
                deprotofy(entry.key): deprotofy(entry.value)
            });

    case Value_Value.compilerFunction:
      var id = value.compilerFunction.id;
      var function = functions[id];
      if (function == null) {
        throw paramsError(
            "CompilerFunction.id $id doesn't match any known functions");
      }

      return function;

    case Value_Value.hostFunction:
      return sass.SassFunction(hostCallable(
          dispatcher, functions, compilationId, value.hostFunction.signature,
          id: value.hostFunction.id));

    case Value_Value.singleton:
      switch (value.singleton) {
        case Value_Singleton.TRUE:
          return sass.sassTrue;
        case Value_Singleton.FALSE:
          return sass.sassFalse;
        case Value_Singleton.NULL:
          return sass.sassNull;
        default:
          throw "Unknown Value.singleton ${value.singleton}";
      }
      // dart-lang/sdk#39304
      throw "Unreachable"; // ignore: dead_code

    case Value_Value.notSet:
      throw mandatoryError("Value.value");
  }

  // dart-lang/sdk#38790
  throw "Unknown Value.value $value.";
}

/// Converts [separator] to its Sass representation.
sass.ListSeparator _deprotofySeparator(Value_List_Separator separator) {
  switch (separator) {
    case Value_List_Separator.COMMA:
      return sass.ListSeparator.comma;
    case Value_List_Separator.SPACE:
      return sass.ListSeparator.space;
    case Value_List_Separator.UNDECIDED:
      return sass.ListSeparator.undecided;
    default:
      throw "Unknown separator $separator";
  }
}

/// Throws a parameter error if [value] isn't between [lower] and [upper], both
/// inclusive.
///
/// Returns [value] if it is within the range.
T _checkInRange<T extends num>(String field, T value, num lower, num upper) {
  if (value < lower) {
    throw paramsError(
        '$field must be greater than or equal to $lower, was $value');
  } else if (value > upper) {
    throw paramsError(
        '$field must be less than or equal to $upper, was $value');
  } else {
    return value;
  }
}
