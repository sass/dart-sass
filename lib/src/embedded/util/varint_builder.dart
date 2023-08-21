// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../embedded_sass.pb.dart';
import '../utils.dart';

/// A class that builds up unsigned varints byte-by-byte.
class VarintBuilder {
  /// The maximum length in bits of the varint being parsed.
  final int _maxLength;

  /// The name of the value being parsed, used for error reporting.
  final String? _name;

  /// The value of the varint so far.
  int _value = 0;

  /// The total number of bits parsed so far.
  int _bits = 0;

  /// Whether we've finished parsing the varint.
  var _done = false;

  /// Creates a builder with [maxLength] as the maximum number of bits allowed
  /// for the integer.
  ///
  /// If [name] is passed, it's used in error reporting.
  VarintBuilder(this._maxLength, [this._name]);

  /// Parses [byte] as a continuation of the varint.
  ///
  /// If this byte completes the varint, returns the parsed int. Otherwise,
  /// returns null.
  ///
  /// Throws a [ProtocolError] if [byte] causes the length of the varint to
  /// exceed [_maxLength]. Throws a [StateError] if called after [add] has
  /// already returned a value.
  int? add(int byte) {
    if (_done) {
      throw StateError("VarintBuilder.add() has already returned a value.");
    }

    // Varints encode data in the 7 lower bits of each byte, which we access by
    // masking with 0x7f = 0b01111111.
    _value += (byte & 0x7f) << _bits;
    _bits += 7;

    // If the byte is higher than 0x7f = 0b01111111, that means its high bit is
    // set which and so there are more bytes to consume before we know the full
    // value.
    if (byte > 0x7f) {
      if (_bits >= _maxLength) {
        _done = true;
        throw _tooLong();
      } else {
        return null;
      }
    } else {
      _done = true;
      if (_bits > _maxLength && _value >= 1 << _maxLength) {
        // [_maxLength] is probably not divisible by 7, so we need to check that
        // the highest bits of the final byte aren't set.
        throw _tooLong();
      } else {
        return _value;
      }
    }
  }

  /// Resets this to its initial state so it can build another varint.
  void reset() {
    _value = 0;
    _bits = 0;
    _done = false;
  }

  /// Returns a [ProtocolError] indicating that the varint exceeded [_maxLength].
  ProtocolError _tooLong() =>
      parseError("Varint ${_name == null ? '' : '$_name '}was longer than "
          "$_maxLength bits.");
}
