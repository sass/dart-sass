// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:sass_api/sass_api.dart' as sass;

import 'dispatcher.dart';
import 'embedded_sass.pb.dart';
import 'function_registry.dart';
import 'host_callable.dart';
import 'utils.dart';

/// A class that converts Sass [sass.Value] objects into [Value] protobufs.
///
/// A given [Protofier] instance is valid only within the scope of a single
/// custom function call.
class Protofier {
  /// The dispatcher, for invoking deprotofied [Value_HostFunction]s.
  final Dispatcher _dispatcher;

  /// The IDs of first-class functions.
  final FunctionRegistry _functions;

  /// The ID of the current compilation.
  final int _compilationId;

  /// Any argument lists transitively contained in [value].
  ///
  /// The IDs of the [Value_ArgumentList] protobufs are always one greater than
  /// the index of the corresponding list in this array (since 0 is reserved for
  /// argument lists created by the host).
  final _argumentLists = <sass.SassArgumentList>[];

  /// Creates a [Protofier] that's valid within the scope of a single custom
  /// function call.
  ///
  /// The [functions] tracks the IDs of first-class functions so that the host
  /// can pass them back to the compiler.
  Protofier(this._dispatcher, this._functions, this._compilationId);

  /// Converts [value] to its protocol buffer representation.
  Value protofy(sass.Value value) {
    var result = Value();
    if (value is sass.SassString) {
      result.string = Value_String()
        ..text = value.text
        ..quoted = value.hasQuotes;
    } else if (value is sass.SassNumber) {
      result.number = _protofyNumber(value);
    } else if (value is sass.SassColor) {
      if (value.hasCalculatedHsl) {
        result.hslColor = Value_HslColor()
          ..hue = value.hue * 1.0
          ..saturation = value.saturation * 1.0
          ..lightness = value.lightness * 1.0
          ..alpha = value.alpha * 1.0;
      } else {
        result.rgbColor = Value_RgbColor()
          ..red = value.red
          ..green = value.green
          ..blue = value.blue
          ..alpha = value.alpha * 1.0;
      }
    } else if (value is sass.SassArgumentList) {
      _argumentLists.add(value);
      var argList = Value_ArgumentList()
        ..id = _argumentLists.length
        ..separator = _protofySeparator(value.separator)
        ..contents.addAll([for (var element in value.asList) protofy(element)]);
      value.keywordsWithoutMarking.forEach((key, value) {
        argList.keywords[key] = protofy(value);
      });

      result.argumentList = argList;
    } else if (value is sass.SassList) {
      result.list = Value_List()
        ..separator = _protofySeparator(value.separator)
        ..hasBrackets = value.hasBrackets
        ..contents.addAll([for (var element in value.asList) protofy(element)]);
    } else if (value is sass.SassMap) {
      var map = Value_Map();
      value.contents.forEach((key, value) {
        map.entries.add(Value_Map_Entry()
          ..key = protofy(key)
          ..value = protofy(value));
      });
      result.map = map;
    } else if (value is sass.SassCalculation) {
      result.calculation = _protofyCalculation(value);
    } else if (value is sass.SassFunction) {
      result.compilerFunction = _functions.protofy(value);
    } else if (value == sass.sassTrue) {
      result.singleton = SingletonValue.TRUE;
    } else if (value == sass.sassFalse) {
      result.singleton = SingletonValue.FALSE;
    } else if (value == sass.sassNull) {
      result.singleton = SingletonValue.NULL;
    } else {
      throw "Unknown Value $value";
    }
    return result;
  }

  /// Converts [number] to its protocol buffer representation.
  Value_Number _protofyNumber(sass.SassNumber number) {
    var value = Value_Number()..value = number.value * 1.0;
    value.numerators.addAll(number.numeratorUnits);
    value.denominators.addAll(number.denominatorUnits);
    return value;
  }

  /// Converts [separator] to its protocol buffer representation.
  ListSeparator _protofySeparator(sass.ListSeparator separator) {
    switch (separator) {
      case sass.ListSeparator.comma:
        return ListSeparator.COMMA;
      case sass.ListSeparator.space:
        return ListSeparator.SPACE;
      case sass.ListSeparator.slash:
        return ListSeparator.SLASH;
      case sass.ListSeparator.undecided:
        return ListSeparator.UNDECIDED;
      default:
        throw "Unknown ListSeparator $separator";
    }
  }

  /// Converts [calculation] to its protocol buffer representation.
  Value_Calculation _protofyCalculation(sass.SassCalculation calculation) =>
      Value_Calculation()
        ..name = calculation.name
        ..arguments.addAll([
          for (var argument in calculation.arguments)
            _protofyCalculationValue(argument)
        ]);

  /// Converts a calculation value that appears within a `SassCalculation` to
  /// its protocol buffer representation.
  Value_Calculation_CalculationValue _protofyCalculationValue(Object value) {
    var result = Value_Calculation_CalculationValue();
    if (value is sass.SassNumber) {
      result.number = _protofyNumber(value);
    } else if (value is sass.SassCalculation) {
      result.calculation = _protofyCalculation(value);
    } else if (value is sass.SassString) {
      result.string = value.text;
    } else if (value is sass.CalculationOperation) {
      result.operation = Value_Calculation_CalculationOperation()
        ..operator = _protofyCalculationOperator(value.operator)
        ..left = _protofyCalculationValue(value.left)
        ..right = _protofyCalculationValue(value.right);
    } else if (value is sass.CalculationInterpolation) {
      result.interpolation = value.value;
    } else {
      throw "Unknown calculation value $value";
    }
    return result;
  }

  /// Converts [operator] to its protocol buffer representation.
  CalculationOperator _protofyCalculationOperator(
      sass.CalculationOperator operator) {
    switch (operator) {
      case sass.CalculationOperator.plus:
        return CalculationOperator.PLUS;
      case sass.CalculationOperator.minus:
        return CalculationOperator.MINUS;
      case sass.CalculationOperator.times:
        return CalculationOperator.TIMES;
      case sass.CalculationOperator.dividedBy:
        return CalculationOperator.DIVIDE;
      default:
        throw "Unknown CalculationOperator $operator";
    }
  }

  /// Converts [response]'s return value to its Sass representation.
  sass.Value deprotofyResponse(InboundMessage_FunctionCallResponse response) {
    for (var id in response.accessedArgumentLists) {
      // Mark the `keywords` field as accessed.
      _argumentListForId(id).keywords;
    }

    return _deprotofy(response.success);
  }

  /// Converts [value] to its Sass representation.
  sass.Value _deprotofy(Value value) {
    try {
      switch (value.whichValue()) {
        case Value_Value.string:
          return value.string.text.isEmpty
              ? sass.SassString.empty(quotes: value.string.quoted)
              : sass.SassString(value.string.text, quotes: value.string.quoted);

        case Value_Value.number:
          return _deprotofyNumber(value.number);

        case Value_Value.rgbColor:
          return sass.SassColor.rgb(value.rgbColor.red, value.rgbColor.green,
              value.rgbColor.blue, value.rgbColor.alpha);

        case Value_Value.hslColor:
          return sass.SassColor.hsl(
              value.hslColor.hue,
              value.hslColor.saturation,
              value.hslColor.lightness,
              value.hslColor.alpha);

        case Value_Value.hwbColor:
          return sass.SassColor.hwb(
              value.hwbColor.hue,
              value.hwbColor.whiteness,
              value.hwbColor.blackness,
              value.hwbColor.alpha);

        case Value_Value.argumentList:
          if (value.argumentList.id != 0) {
            return _argumentListForId(value.argumentList.id);
          }

          var separator = _deprotofySeparator(value.argumentList.separator);
          var length = value.argumentList.contents.length;
          if (separator == sass.ListSeparator.undecided && length > 1) {
            throw paramsError(
                "List $value can't have an undecided separator because it has "
                "$length elements");
          }

          return sass.SassArgumentList([
            for (var element in value.argumentList.contents) _deprotofy(element)
          ], {
            for (var entry in value.argumentList.keywords.entries)
              entry.key: _deprotofy(entry.value)
          }, separator);

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
            for (var element in value.list.contents) _deprotofy(element)
          ], separator, brackets: value.list.hasBrackets);

        case Value_Value.map:
          return value.map.entries.isEmpty
              ? const sass.SassMap.empty()
              : sass.SassMap({
                  for (var entry in value.map.entries)
                    _deprotofy(entry.key): _deprotofy(entry.value)
                });

        case Value_Value.compilerFunction:
          var id = value.compilerFunction.id;
          var function = _functions[id];
          if (function == null) {
            throw paramsError(
                "CompilerFunction.id $id doesn't match any known functions");
          }

          return function;

        case Value_Value.hostFunction:
          return sass.SassFunction(hostCallable(_dispatcher, _functions,
              _compilationId, value.hostFunction.signature,
              id: value.hostFunction.id));

        case Value_Value.calculation:
          return _deprotofyCalculation(value.calculation);

        case Value_Value.singleton:
          switch (value.singleton) {
            case SingletonValue.TRUE:
              return sass.sassTrue;
            case SingletonValue.FALSE:
              return sass.sassFalse;
            case SingletonValue.NULL:
              return sass.sassNull;
            default:
              throw "Unknown Value.singleton ${value.singleton}";
          }

        case Value_Value.notSet:
          throw mandatoryError("Value.value");
      }
    } on RangeError catch (error) {
      var name = error.name;
      if (name == null || error.start == null || error.end == null) {
        throw paramsError(error.toString());
      }

      if (value.whichValue() == Value_Value.rgbColor) {
        name = 'RgbColor.$name';
      } else if (value.whichValue() == Value_Value.hslColor) {
        name = 'HslColor.$name';
      }

      throw paramsError(
          '$name must be between ${error.start} and ${error.end}, was '
          '${error.invalidValue}');
    }
  }

  /// Converts [number] to its Sass representation.
  sass.SassNumber _deprotofyNumber(Value_Number number) =>
      sass.SassNumber.withUnits(number.value,
          numeratorUnits: number.numerators,
          denominatorUnits: number.denominators);

  /// Returns the argument list in [_argumentLists] that corresponds to [id].
  sass.SassArgumentList _argumentListForId(int id) {
    if (id < 1) {
      throw paramsError(
          "Value.ArgumentList.id $id can't be marked as accessed");
    } else if (id > _argumentLists.length) {
      throw paramsError(
          "Value.ArgumentList.id $id doesn't match any known argument "
          "lists");
    } else {
      return _argumentLists[id - 1];
    }
  }

  /// Converts [separator] to its Sass representation.
  sass.ListSeparator _deprotofySeparator(ListSeparator separator) {
    switch (separator) {
      case ListSeparator.COMMA:
        return sass.ListSeparator.comma;
      case ListSeparator.SPACE:
        return sass.ListSeparator.space;
      case ListSeparator.SLASH:
        return sass.ListSeparator.slash;
      case ListSeparator.UNDECIDED:
        return sass.ListSeparator.undecided;
      default:
        throw "Unknown separator $separator";
    }
  }

  /// Converts [calculation] to its Sass representation.
  sass.Value _deprotofyCalculation(Value_Calculation calculation) {
    if (calculation.name == "calc") {
      if (calculation.arguments.length != 1) {
        throw paramsError(
            "Value.Calculation.arguments must have exactly one argument for "
            "calc().");
      }

      return sass.SassCalculation.calc(
          _deprotofyCalculationValue(calculation.arguments[0]));
    } else if (calculation.name == "clamp") {
      if (calculation.arguments.length != 3) {
        throw paramsError(
            "Value.Calculation.arguments must have exactly 3 arguments for "
            "clamp().");
      }

      return sass.SassCalculation.clamp(
          _deprotofyCalculationValue(calculation.arguments[0]),
          _deprotofyCalculationValue(calculation.arguments[1]),
          _deprotofyCalculationValue(calculation.arguments[2]));
    } else if (calculation.name == "min") {
      if (calculation.arguments.isEmpty) {
        throw paramsError(
            "Value.Calculation.arguments must have at least 1 argument for "
            "min().");
      }

      return sass.SassCalculation.min(
          calculation.arguments.map(_deprotofyCalculationValue));
    } else if (calculation.name == "max") {
      if (calculation.arguments.isEmpty) {
        throw paramsError(
            "Value.Calculation.arguments must have at least 1 argument for "
            "max().");
      }

      return sass.SassCalculation.max(
          calculation.arguments.map(_deprotofyCalculationValue));
    } else {
      throw paramsError(
          'Value.Calculation.name "${calculation.name}" is not a recognized '
          'calculation type.');
    }
  }

  /// Converts [value] to its Sass representation.
  Object _deprotofyCalculationValue(Value_Calculation_CalculationValue value) {
    switch (value.whichValue()) {
      case Value_Calculation_CalculationValue_Value.number:
        return _deprotofyNumber(value.number);

      case Value_Calculation_CalculationValue_Value.calculation:
        return _deprotofyCalculation(value.calculation);

      case Value_Calculation_CalculationValue_Value.string:
        return sass.SassString(value.string, quotes: false);

      case Value_Calculation_CalculationValue_Value.operation:
        return sass.SassCalculation.operate(
            _deprotofyCalculationOperator(value.operation.operator),
            _deprotofyCalculationValue(value.operation.left),
            _deprotofyCalculationValue(value.operation.right));

      case Value_Calculation_CalculationValue_Value.interpolation:
        return sass.CalculationInterpolation(value.interpolation);

      case Value_Calculation_CalculationValue_Value.notSet:
        throw mandatoryError("Value.Calculation.value");
    }
  }

  /// Converts [operator] to its Sass representation.
  sass.CalculationOperator _deprotofyCalculationOperator(
      CalculationOperator operator) {
    switch (operator) {
      case CalculationOperator.PLUS:
        return sass.CalculationOperator.plus;
      case CalculationOperator.MINUS:
        return sass.CalculationOperator.minus;
      case CalculationOperator.TIMES:
        return sass.CalculationOperator.times;
      case CalculationOperator.DIVIDE:
        return sass.CalculationOperator.dividedBy;
      default:
        throw "Unknown CalculationOperator $operator";
    }
  }
}
