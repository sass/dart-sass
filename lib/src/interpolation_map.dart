// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import 'ast/sass.dart';
import 'util/character.dart';

/// A class that can map locations in a string generated from an [Interpolation]
/// to the original source code in the [interpolation].
class InterpolationMap {
  /// The interpolation from which this map was generated.
  final Interpolation _interpolation;

  /// Locations in the generated string.
  ///
  /// Each of these indicates the location in the generated string that
  /// corresponds to the end of the component at the same index of
  /// [_interpolation.contents]. Its length is always one less than
  /// [_interpolation.contents] because the last element always ends the string.
  final List<SourceLocation> _targetLocations;

  /// Creates a new interpolation map that maps the given [targetLocations] in
  /// the generated string to the contents of the interpolation.
  ///
  /// Each [targetLocation] at index `i` corresponds to the character in the
  /// generated string after `interpolation.contents[i]`.
  InterpolationMap(
      this._interpolation, Iterable<SourceLocation> targetLocations)
      : _targetLocations = List.unmodifiable(targetLocations) {
        var expectedLocations = math.max(0, _interpolation.contents.length - 1);
    if (_targetLocations.length != expectedLocations) {
      throw ArgumentError(
        "InterpolationMap must have $expectedLocations targetLocations if the "
        "interpolation has ${_interpolation.contents.length} components.");
    }
  }

  /// Maps [error]'s span in the string generated from this interpolation to its
  /// original source.
  FormatException mapException(SourceSpanFormatException error) {
    var target = error.span;
    if (target == null) return error;

    var source = mapSpan(target);
    var startIndex = _indexInContents(target.start);
    var endIndex = _indexInContents(target.end);

    if (!_interpolation.contents
        .skip(startIndex)
        .take(endIndex - startIndex + 1)
        .any((content) => content is Expression)) {
      return SourceSpanFormatException(error.message, source, error.source);
    } else {
      return MultiSourceSpanFormatException(error.message, source, "",
          {target: "error in interpolated output"}, error.source);
    }
  }

  /// Maps a span in the string generated from this interpolation to its
  /// original source.
  FileSpan mapSpan(SourceSpan target) {
    var start = _mapLocation(target.start);
    var end = _mapLocation(target.end);

    if (start is FileSpan) {
      if (end is FileSpan) return start.expand(end);

      return _interpolation.span.file.span(
          _expandInterpolationSpanLeft(start.start),
          (end as FileLocation).offset);
    } else if (end is FileSpan) {
      return _interpolation.span.file.span((start as FileLocation).offset,
          _expandInterpolationSpanRight(end.end));
    } else {
      return _interpolation.span.file
          .span((start as FileLocation).offset, (end as FileLocation).offset);
    }
  }

  /// Maps a location in the string generated from this interpolation to its
  /// original source.
  ///
  /// If [source] points to an un-interpolated portion of the original string,
  /// this will return the corresponding [FileLocation]. If it points to text
  /// generated from interpolation, this will return the full [FileSpan] for
  /// that interpolated expression.
  Object /* FileLocation|FileSpan */ _mapLocation(SourceLocation target) {
    var index = _indexInContents(target);
    var chunk = _interpolation.contents[index];
    if (chunk is Expression) return chunk.span;

    var previousLocation = index == 0
        ? _interpolation.span.start
        : _interpolation.span.file.location(_expandInterpolationSpanRight(
            (_interpolation.contents[index - 1] as Expression).span.end));
    var offsetInString =
        target.offset - (index == 0 ? 0 : _targetLocations[index - 1].offset);

    // This produces slightly incorrect mappings if there are _unnecessary_
    // escapes in the source file, but that's unlikely enough that it's probably
    // not worth doing a reparse here to fix it.
    return previousLocation.file
        .location(previousLocation.offset + offsetInString);
  }

  /// Return the index in [_interpolation.contents] at which [target] points.
  int _indexInContents(SourceLocation target) {
    for (var i = 0; i < _targetLocations.length; i++) {
      if (target.offset < _targetLocations[i].offset) return i;
    }

    return _interpolation.contents.length - 1;
  }

  /// Given the start of a [FileSpan] covering an interpolated expression, returns
  /// the offset of the interpolation's opening `#`.
  ///
  /// Note that this can be tricked by a `#{` that appears within a single-line
  /// comment before the expression, but since it's only used for error
  /// reporting that's probably fine.
  int _expandInterpolationSpanLeft(FileLocation start) {
    var source = start.file.getText(0, start.offset);
    var i = start.offset - 1;
    while (true) {
      var prev = source.codeUnitAt(i--);
      if (prev == $lbrace) {
        if (source.codeUnitAt(i) == $hash) break;
      } else if (prev == $slash) {
        var second = source.codeUnitAt(i--);
        if (second == $asterisk) {
          while (true) {
            var char = source.codeUnitAt(i--);
            if (char != $asterisk) continue;

            do {
              char = source.codeUnitAt(i--);
            } while (char == $asterisk);
            if (char == $slash) break;
          }
        }
      }
    }

    return i;
  }

  /// Given the end of a [FileSpan] covering an interpolated expression, returns
  /// the offset of the interpolation's closing `}`.
  int _expandInterpolationSpanRight(FileLocation end) {
    var scanner = StringScanner(end.file.getText(end.offset));
    while (true) {
      var next = scanner.readChar();
      if (next == $rbrace) break;
      if (next == $slash) {
        var second = scanner.readChar();
        if (second == $slash) {
          while (!isNewline(scanner.readChar())) {}
        } else if (second == $asterisk) {
          while (true) {
            var char = scanner.readChar();
            if (char != $asterisk) continue;

            do {
              char = scanner.readChar();
            } while (char == $asterisk);
            if (char == $slash) break;
          }
        }
      }
    }

    return end.offset + scanner.position;
  }
}
