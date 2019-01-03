// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';
import 'package:string_scanner/string_scanner.dart';

import '../../../visitor/interface/statement.dart';
import '../statement.dart';

/// A silent Sass-style comment.
class SilentComment implements Statement {
  /// The text of this comment, including comment characters.
  final String text;

  /// The subset of lines in text that are marked as part of the documentation
  /// comments by beginning with '///'.
  ///
  /// The leading slashes and space on each line is removed. Returns `null` when
  /// there is no documentation comment.
  String get docComment {
    var buffer = StringBuffer();
    for (var line in text.split('\n')) {
      var scanner = StringScanner(line.trim());
      if (!scanner.scan('///')) continue;
      scanner.scan(' ');
      buffer.writeln(scanner.rest);
    }
    var comment = buffer.toString().trimRight();

    return comment.isNotEmpty ? comment : null;
  }

  final FileSpan span;

  SilentComment(this.text, this.span);

  T accept<T>(StatementVisitor<T> visitor) => visitor.visitSilentComment(this);

  String toString() => text;
}
