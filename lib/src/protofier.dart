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
      var number = Value_Number()..value = value.value * 1.0;
      number.numerators.addAll(value.numeratorUnits);
      number.denominators.addAll(value.denominatorUnits);
      result.number = number;
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
          return sass.SassNumber.withUnits(value.number.value,
              numeratorUnits: value.number.numerators,
              denominatorUnits: value.number.denominators);

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
}
