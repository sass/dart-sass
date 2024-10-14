// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../util/map.dart';
import '../util/nullable.dart';
import '../value.dart';
import 'compilation_dispatcher.dart';
import 'embedded_sass.pb.dart' as proto;
import 'embedded_sass.pb.dart' hide Value, ListSeparator, CalculationOperator;
import 'host_callable.dart';
import 'opaque_registry.dart';
import 'utils.dart';

/// A class that converts Sass [Value] objects into [Value] protobufs.
///
/// A given [Protofier] instance is valid only within the scope of a single
/// custom function call.
final class Protofier {
  /// The dispatcher, for invoking deprotofied [Value_HostFunction]s.
  final CompilationDispatcher _dispatcher;

  /// The IDs of first-class functions.
  final OpaqueRegistry<SassFunction> _functions;

  /// The IDs of first-class mixins.
  final OpaqueRegistry<SassMixin> _mixins;

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
  ///
  /// Similarly, the [mixins] tracks the IDs of first-class mixins so that the
  /// host can pass them back to the compiler.
  Protofier(this._dispatcher, this._functions, this._mixins);

  /// Converts [value] to its protocol buffer representation.
  proto.Value protofy(Value value) {
    var result = proto.Value();
    switch (value) {
      case SassString():
        result.string = Value_String()
          ..text = value.text
          ..quoted = value.hasQuotes;
      case SassNumber():
        result.number = _protofyNumber(value);
      case SassColor():
        result.color = Value_Color(
            space: value.space.name,
            channel1: value.channel0OrNull,
            channel2: value.channel1OrNull,
            channel3: value.channel2OrNull,
            alpha: value.alphaOrNull);
      case SassArgumentList():
        _argumentLists.add(value);
        result.argumentList = Value_ArgumentList()
          ..id = _argumentLists.length
          ..separator = _protofySeparator(value.separator)
          ..keywords.addAll({
            for (var (key, value) in value.keywordsWithoutMarking.pairs)
              key: protofy(value)
          })
          ..contents.addAll(value.asList.map(protofy));
      case SassList():
        result.list = Value_List()
          ..separator = _protofySeparator(value.separator)
          ..hasBrackets = value.hasBrackets
          ..contents.addAll(value.asList.map(protofy));
      case SassMap():
        result.map = Value_Map();
        for (var (key, value) in value.contents.pairs) {
          result.map.entries.add(Value_Map_Entry()
            ..key = protofy(key)
            ..value = protofy(value));
        }
      case SassCalculation():
        result.calculation = _protofyCalculation(value);
      case SassFunction():
        result.compilerFunction =
            Value_CompilerFunction(id: _functions.getId(value));
      case SassMixin():
        result.compilerMixin = Value_CompilerMixin(id: _mixins.getId(value));
      case sassTrue:
        result.singleton = SingletonValue.TRUE;
      case sassFalse:
        result.singleton = SingletonValue.FALSE;
      case sassNull:
        result.singleton = SingletonValue.NULL;
      case _:
        throw "Unknown Value $value";
    }
    return result;
  }

  /// Converts [number] to its protocol buffer representation.
  Value_Number _protofyNumber(SassNumber number) => Value_Number()
    ..value = number.value * 1.0
    ..numerators.addAll(number.numeratorUnits)
    ..denominators.addAll(number.denominatorUnits);

  /// Converts [separator] to its protocol buffer representation.
  proto.ListSeparator _protofySeparator(ListSeparator separator) =>
      switch (separator) {
        ListSeparator.comma => proto.ListSeparator.COMMA,
        ListSeparator.space => proto.ListSeparator.SPACE,
        ListSeparator.slash => proto.ListSeparator.SLASH,
        ListSeparator.undecided => proto.ListSeparator.UNDECIDED
      };

  /// Converts [calculation] to its protocol buffer representation.
  Value_Calculation _protofyCalculation(SassCalculation calculation) =>
      Value_Calculation()
        ..name = calculation.name
        ..arguments.addAll(calculation.arguments.map(_protofyCalculationValue));

  /// Converts a calculation value that appears within a `SassCalculation` to
  /// its protocol buffer representation.
  Value_Calculation_CalculationValue _protofyCalculationValue(Object value) {
    var result = Value_Calculation_CalculationValue();
    switch (value) {
      case SassNumber():
        result.number = _protofyNumber(value);
      case SassCalculation():
        result.calculation = _protofyCalculation(value);
      case SassString():
        result.string = value.text;
      case CalculationOperation():
        result.operation = Value_Calculation_CalculationOperation()
          ..operator = _protofyCalculationOperator(value.operator)
          ..left = _protofyCalculationValue(value.left)
          ..right = _protofyCalculationValue(value.right);
      case _:
        throw "Unknown calculation value $value";
    }
    return result;
  }

  /// Converts [operator] to its protocol buffer representation.
  proto.CalculationOperator _protofyCalculationOperator(
          CalculationOperator operator) =>
      switch (operator) {
        CalculationOperator.plus => proto.CalculationOperator.PLUS,
        CalculationOperator.minus => proto.CalculationOperator.MINUS,
        CalculationOperator.times => proto.CalculationOperator.TIMES,
        CalculationOperator.dividedBy => proto.CalculationOperator.DIVIDE
      };

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

        case Value_Value.color:
          var space = ColorSpace.fromName(value.color.space);
          var channel1 =
              value.color.hasChannel1() ? value.color.channel1 : null;
          var channel2 =
              value.color.hasChannel2() ? value.color.channel2 : null;
          var channel3 =
              value.color.hasChannel3() ? value.color.channel3 : null;
          var alpha = value.color.hasAlpha() ? value.color.alpha : null;
          switch (space) {
            case ColorSpace.rgb:
              return SassColor.rgb(channel1, channel2, channel3, alpha);

            case ColorSpace.hsl:
              return SassColor.hsl(channel1, channel2, channel3, alpha);

            case ColorSpace.hwb:
              return SassColor.hwb(channel1, channel2, channel3, alpha);

            case ColorSpace.lab:
              return SassColor.lab(channel1, channel2, channel3, alpha);
            case ColorSpace.oklab:
              return SassColor.oklab(channel1, channel2, channel3, alpha);

            case ColorSpace.lch:
              return SassColor.lch(channel1, channel2, channel3, alpha);
            case ColorSpace.oklch:
              return SassColor.oklch(channel1, channel2, channel3, alpha);

            case ColorSpace.srgb:
              return SassColor.srgb(channel1, channel2, channel3, alpha);
            case ColorSpace.srgbLinear:
              return SassColor.srgbLinear(channel1, channel2, channel3, alpha);
            case ColorSpace.displayP3:
              return SassColor.displayP3(channel1, channel2, channel3, alpha);
            case ColorSpace.a98Rgb:
              return SassColor.a98Rgb(channel1, channel2, channel3, alpha);
            case ColorSpace.prophotoRgb:
              return SassColor.prophotoRgb(channel1, channel2, channel3, alpha);
            case ColorSpace.rec2020:
              return SassColor.rec2020(channel1, channel2, channel3, alpha);

            case ColorSpace.xyzD50:
              return SassColor.xyzD50(channel1, channel2, channel3, alpha);
            case ColorSpace.xyzD65:
              return SassColor.xyzD65(channel1, channel2, channel3, alpha);

            default:
              throw "Unreachable";
          }

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

          return SassArgumentList(
              value.argumentList.contents.map(_deprotofy),
              {
                for (var (name, value) in value.argumentList.keywords.pairs)
                  name: _deprotofy(value)
              },
              separator);

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

          return SassList(value.list.contents.map(_deprotofy), separator,
              brackets: value.list.hasBrackets);

        case Value_Value.map:
          return value.map.entries.isEmpty
              ? const SassMap.empty()
              : SassMap({
                  for (var Value_Map_Entry(:key, :value) in value.map.entries)
                    _deprotofy(key): _deprotofy(value)
                });

        case Value_Value.compilerFunction:
          var id = value.compilerFunction.id;
          if (_functions[id] case var function?) return function;
          throw paramsError(
              "CompilerFunction.id $id doesn't match any known functions");

        case Value_Value.hostFunction:
          return SassFunction(hostCallable(
              _dispatcher, _functions, _mixins, value.hostFunction.signature,
              id: value.hostFunction.id));

        case Value_Value.compilerMixin:
          var id = value.compilerMixin.id;
          if (_mixins[id] case var mixin?) return mixin;
          throw paramsError(
              "CompilerMixin.id $id doesn't match any known mixins");

        case Value_Value.calculation:
          return _deprotofyCalculation(value.calculation);

        case Value_Value.singleton:
          return switch (value.singleton) {
            SingletonValue.TRUE => sassTrue,
            SingletonValue.FALSE => sassFalse,
            SingletonValue.NULL => sassNull,
            _ => throw "Unknown Value.singleton ${value.singleton}"
          };

        case Value_Value.notSet:
          throw mandatoryError("Value.value");
      }
    } on RangeError catch (error) {
      var name = error.name;
      if (name == null || error.start == null || error.end == null) {
        throw paramsError(error.toString());
      }

      if (value.whichValue() == Value_Value.color) {
        name = 'Color.$name';
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
  ListSeparator _deprotofySeparator(proto.ListSeparator separator) =>
      switch (separator) {
        proto.ListSeparator.COMMA => ListSeparator.comma,
        proto.ListSeparator.SPACE => ListSeparator.space,
        proto.ListSeparator.SLASH => ListSeparator.slash,
        proto.ListSeparator.UNDECIDED => ListSeparator.undecided,
        _ => throw "Unknown ListSeparator $separator",
      };

  /// Converts [calculation] to its Sass representation.
  Value _deprotofyCalculation(Value_Calculation calculation) =>
      switch (calculation) {
        Value_Calculation(name: "calc", arguments: [var arg]) =>
          SassCalculation.calc(_deprotofyCalculationValue(arg)),
        Value_Calculation(name: "calc") => throw paramsError(
            "Value.Calculation.arguments must have exactly one argument for "
            "calc()."),
        Value_Calculation(
          name: "clamp",
          arguments: [var arg1, ...var rest] && List(length: < 4)
        ) =>
          SassCalculation.clamp(
              _deprotofyCalculationValue(arg1),
              rest.elementAtOrNull(0).andThen(_deprotofyCalculationValue),
              rest.elementAtOrNull(1).andThen(_deprotofyCalculationValue)),
        Value_Calculation(name: "clamp") => throw paramsError(
            "Value.Calculation.arguments must have 1 to 3 arguments for "
            "clamp()."),
        Value_Calculation(name: "min" || "max", arguments: []) =>
          throw paramsError(
              "Value.Calculation.arguments must have at least 1 argument for "
              "${calculation.name}()."),
        Value_Calculation(name: "min", :var arguments) =>
          SassCalculation.min(arguments.map(_deprotofyCalculationValue)),
        Value_Calculation(name: "max", :var arguments) =>
          SassCalculation.max(arguments.map(_deprotofyCalculationValue)),
        _ => throw paramsError(
            'Value.Calculation.name "${calculation.name}" is not a recognized '
            'calculation type.')
      };

  /// Converts [value] to its Sass representation.
  Object _deprotofyCalculationValue(Value_Calculation_CalculationValue value) =>
      switch (value.whichValue()) {
        Value_Calculation_CalculationValue_Value.number =>
          _deprotofyNumber(value.number),
        Value_Calculation_CalculationValue_Value.calculation =>
          _deprotofyCalculation(value.calculation),
        Value_Calculation_CalculationValue_Value.string =>
          SassString(value.string, quotes: false),
        Value_Calculation_CalculationValue_Value.operation =>
          SassCalculation.operate(
              _deprotofyCalculationOperator(value.operation.operator),
              _deprotofyCalculationValue(value.operation.left),
              _deprotofyCalculationValue(value.operation.right)),
        Value_Calculation_CalculationValue_Value.interpolation =>
          SassString('(${value.interpolation})', quotes: false),
        Value_Calculation_CalculationValue_Value.notSet =>
          throw mandatoryError("Value.Calculation.value")
      };

  /// Converts [operator] to its Sass representation.
  CalculationOperator _deprotofyCalculationOperator(
          proto.CalculationOperator operator) =>
      switch (operator) {
        proto.CalculationOperator.PLUS => CalculationOperator.plus,
        proto.CalculationOperator.MINUS => CalculationOperator.minus,
        proto.CalculationOperator.TIMES => CalculationOperator.times,
        proto.CalculationOperator.DIVIDE => CalculationOperator.dividedBy,
        _ => throw "Unknown CalculationOperator $operator"
      };
}
