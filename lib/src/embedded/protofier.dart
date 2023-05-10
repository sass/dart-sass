// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../value.dart';
import 'dispatcher.dart';
import 'embedded_sass.pb.dart' as proto;
import 'embedded_sass.pb.dart' hide Value, ListSeparator, CalculationOperator;
import 'function_registry.dart';
import 'host_callable.dart';
import 'utils.dart';

/// A class that converts Sass [Value] objects into [Value] protobufs.
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
  final _argumentLists = <SassArgumentList>[];

  /// Creates a [Protofier] that's valid within the scope of a single custom
  /// function call.
  ///
  /// The [functions] tracks the IDs of first-class functions so that the host
  /// can pass them back to the compiler.
  Protofier(this._dispatcher, this._functions, this._compilationId);

  /// Converts [value] to its protocol buffer representation.
  proto.Value protofy(Value value) {
    var result = proto.Value();
    if (value is SassString) {
      result.string = Value_String()
        ..text = value.text
        ..quoted = value.hasQuotes;
    } else if (value is SassNumber) {
      result.number = _protofyNumber(value);
    } else if (value is SassColor) {
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
    } else if (value is SassArgumentList) {
      _argumentLists.add(value);
      var argList = Value_ArgumentList()
        ..id = _argumentLists.length
        ..separator = _protofySeparator(value.separator)
        ..contents.addAll([for (var element in value.asList) protofy(element)]);
      value.keywordsWithoutMarking.forEach((key, value) {
        argList.keywords[key] = protofy(value);
      });

      result.argumentList = argList;
    } else if (value is SassList) {
      result.list = Value_List()
        ..separator = _protofySeparator(value.separator)
        ..hasBrackets = value.hasBrackets
        ..contents.addAll([for (var element in value.asList) protofy(element)]);
    } else if (value is SassMap) {
      var map = Value_Map();
      value.contents.forEach((key, value) {
        map.entries.add(Value_Map_Entry()
          ..key = protofy(key)
          ..value = protofy(value));
      });
      result.map = map;
    } else if (value is SassCalculation) {
      result.calculation = _protofyCalculation(value);
    } else if (value is SassFunction) {
      result.compilerFunction = _functions.protofy(value);
    } else if (value == sassTrue) {
      result.singleton = SingletonValue.TRUE;
    } else if (value == sassFalse) {
      result.singleton = SingletonValue.FALSE;
    } else if (value == sassNull) {
      result.singleton = SingletonValue.NULL;
    } else {
      throw "Unknown Value $value";
    }
    return result;
  }

  /// Converts [number] to its protocol buffer representation.
  Value_Number _protofyNumber(SassNumber number) {
    var value = Value_Number()..value = number.value * 1.0;
    value.numerators.addAll(number.numeratorUnits);
    value.denominators.addAll(number.denominatorUnits);
    return value;
  }

  /// Converts [separator] to its protocol buffer representation.
  proto.ListSeparator _protofySeparator(ListSeparator separator) {
    switch (separator) {
      case ListSeparator.comma:
        return proto.ListSeparator.COMMA;
      case ListSeparator.space:
        return proto.ListSeparator.SPACE;
      case ListSeparator.slash:
        return proto.ListSeparator.SLASH;
      case ListSeparator.undecided:
        return proto.ListSeparator.UNDECIDED;
      default:
        throw "Unknown ListSeparator $separator";
    }
  }

  /// Converts [calculation] to its protocol buffer representation.
  Value_Calculation _protofyCalculation(SassCalculation calculation) =>
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
    if (value is SassNumber) {
      result.number = _protofyNumber(value);
    } else if (value is SassCalculation) {
      result.calculation = _protofyCalculation(value);
    } else if (value is SassString) {
      result.string = value.text;
    } else if (value is CalculationOperation) {
      result.operation = Value_Calculation_CalculationOperation()
        ..operator = _protofyCalculationOperator(value.operator)
        ..left = _protofyCalculationValue(value.left)
        ..right = _protofyCalculationValue(value.right);
    } else if (value is CalculationInterpolation) {
      result.interpolation = value.value;
    } else {
      throw "Unknown calculation value $value";
    }
    return result;
  }

  /// Converts [operator] to its protocol buffer representation.
  proto.CalculationOperator _protofyCalculationOperator(
      CalculationOperator operator) {
    switch (operator) {
      case CalculationOperator.plus:
        return proto.CalculationOperator.PLUS;
      case CalculationOperator.minus:
        return proto.CalculationOperator.MINUS;
      case CalculationOperator.times:
        return proto.CalculationOperator.TIMES;
      case CalculationOperator.dividedBy:
        return proto.CalculationOperator.DIVIDE;
      default:
        throw "Unknown CalculationOperator $operator";
    }
  }

  /// Converts [response]'s return value to its Sass representation.
  Value deprotofyResponse(InboundMessage_FunctionCallResponse response) {
    for (var id in response.accessedArgumentLists) {
      // Mark the `keywords` field as accessed.
      _argumentListForId(id).keywords;
    }

    return _deprotofy(response.success);
  }

  /// Converts [value] to its Sass representation.
  Value _deprotofy(proto.Value value) {
    try {
      switch (value.whichValue()) {
        case Value_Value.string:
          return value.string.text.isEmpty
              ? SassString.empty(quotes: value.string.quoted)
              : SassString(value.string.text, quotes: value.string.quoted);

        case Value_Value.number:
          return _deprotofyNumber(value.number);

        case Value_Value.rgbColor:
          return SassColor.rgb(value.rgbColor.red, value.rgbColor.green,
              value.rgbColor.blue, value.rgbColor.alpha);

        case Value_Value.hslColor:
          return SassColor.hsl(value.hslColor.hue, value.hslColor.saturation,
              value.hslColor.lightness, value.hslColor.alpha);

        case Value_Value.hwbColor:
          return SassColor.hwb(value.hwbColor.hue, value.hwbColor.whiteness,
              value.hwbColor.blackness, value.hwbColor.alpha);

        case Value_Value.argumentList:
          if (value.argumentList.id != 0) {
            return _argumentListForId(value.argumentList.id);
          }

          var separator = _deprotofySeparator(value.argumentList.separator);
          var length = value.argumentList.contents.length;
          if (separator == ListSeparator.undecided && length > 1) {
            throw paramsError(
                "List $value can't have an undecided separator because it has "
                "$length elements");
          }

          return SassArgumentList([
            for (var element in value.argumentList.contents) _deprotofy(element)
          ], {
            for (var entry in value.argumentList.keywords.entries)
              entry.key: _deprotofy(entry.value)
          }, separator);

        case Value_Value.list:
          var separator = _deprotofySeparator(value.list.separator);
          if (value.list.contents.isEmpty) {
            return SassList.empty(
                separator: separator, brackets: value.list.hasBrackets);
          }

          var length = value.list.contents.length;
          if (separator == ListSeparator.undecided && length > 1) {
            throw paramsError(
                "List $value can't have an undecided separator because it has "
                "$length elements");
          }

          return SassList([
            for (var element in value.list.contents) _deprotofy(element)
          ], separator, brackets: value.list.hasBrackets);

        case Value_Value.map:
          return value.map.entries.isEmpty
              ? const SassMap.empty()
              : SassMap({
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
          return SassFunction(hostCallable(_dispatcher, _functions,
              _compilationId, value.hostFunction.signature,
              id: value.hostFunction.id));

        case Value_Value.calculation:
          return _deprotofyCalculation(value.calculation);

        case Value_Value.singleton:
          switch (value.singleton) {
            case SingletonValue.TRUE:
              return sassTrue;
            case SingletonValue.FALSE:
              return sassFalse;
            case SingletonValue.NULL:
              return sassNull;
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
  SassNumber _deprotofyNumber(Value_Number number) =>
      SassNumber.withUnits(number.value,
          numeratorUnits: number.numerators,
          denominatorUnits: number.denominators);

  /// Returns the argument list in [_argumentLists] that corresponds to [id].
  SassArgumentList _argumentListForId(int id) {
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
  ListSeparator _deprotofySeparator(proto.ListSeparator separator) {
    switch (separator) {
      case proto.ListSeparator.COMMA:
        return ListSeparator.comma;
      case proto.ListSeparator.SPACE:
        return ListSeparator.space;
      case proto.ListSeparator.SLASH:
        return ListSeparator.slash;
      case proto.ListSeparator.UNDECIDED:
        return ListSeparator.undecided;
      default:
        throw "Unknown separator $separator";
    }
  }

  /// Converts [calculation] to its Sass representation.
  Value _deprotofyCalculation(Value_Calculation calculation) {
    if (calculation.name == "calc") {
      if (calculation.arguments.length != 1) {
        throw paramsError(
            "Value.Calculation.arguments must have exactly one argument for "
            "calc().");
      }

      return SassCalculation.calc(
          _deprotofyCalculationValue(calculation.arguments[0]));
    } else if (calculation.name == "clamp") {
      if (calculation.arguments.length != 3) {
        throw paramsError(
            "Value.Calculation.arguments must have exactly 3 arguments for "
            "clamp().");
      }

      return SassCalculation.clamp(
          _deprotofyCalculationValue(calculation.arguments[0]),
          _deprotofyCalculationValue(calculation.arguments[1]),
          _deprotofyCalculationValue(calculation.arguments[2]));
    } else if (calculation.name == "min") {
      if (calculation.arguments.isEmpty) {
        throw paramsError(
            "Value.Calculation.arguments must have at least 1 argument for "
            "min().");
      }

      return SassCalculation.min(
          calculation.arguments.map(_deprotofyCalculationValue));
    } else if (calculation.name == "max") {
      if (calculation.arguments.isEmpty) {
        throw paramsError(
            "Value.Calculation.arguments must have at least 1 argument for "
            "max().");
      }

      return SassCalculation.max(
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
        return SassString(value.string, quotes: false);

      case Value_Calculation_CalculationValue_Value.operation:
        return SassCalculation.operate(
            _deprotofyCalculationOperator(value.operation.operator),
            _deprotofyCalculationValue(value.operation.left),
            _deprotofyCalculationValue(value.operation.right));

      case Value_Calculation_CalculationValue_Value.interpolation:
        return CalculationInterpolation(value.interpolation);

      case Value_Calculation_CalculationValue_Value.notSet:
        throw mandatoryError("Value.Calculation.value");
    }
  }

  /// Converts [operator] to its Sass representation.
  CalculationOperator _deprotofyCalculationOperator(
      proto.CalculationOperator operator) {
    switch (operator) {
      case proto.CalculationOperator.PLUS:
        return CalculationOperator.plus;
      case proto.CalculationOperator.MINUS:
        return CalculationOperator.minus;
      case proto.CalculationOperator.TIMES:
        return CalculationOperator.times;
      case proto.CalculationOperator.DIVIDE:
        return CalculationOperator.dividedBy;
      default:
        throw "Unknown CalculationOperator $operator";
    }
  }
}
