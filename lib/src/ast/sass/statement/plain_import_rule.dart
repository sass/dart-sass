// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:charcode/charcode.dart';
import 'package:source_span/source_span.dart';

import '../../../visitor/interface/statement.dart';
import '../interpolation.dart';
import '../statement.dart';
import '../supports_condition.dart';

/// A rule that produces a plain CSS `@import` rule.
class PlainImportRule implements Statement {
  /// The URL for this import.
  ///
  /// This already contains quotes.
  final Interpolation url;

  /// The supports condition attached to this import, or `null` if no condition
  /// is attached.
  final SupportsCondition supports;

  /// The media query attached to this import, or `null` if no condition is
  /// attached.
  final Interpolation media;

  final FileSpan span;

  PlainImportRule(this.url, this.span, {this.supports, this.media});

  /*=T*/ accept/*<T>*/(StatementVisitor/*<T>*/ visitor) =>
      visitor.visitPlainImportRule(this);

  String toString() {
    var buffer = new StringBuffer("@import $url");
    if (supports != null) buffer.write(" supports($supports)");
    if (media != null) buffer.write(" $media");
    buffer.writeCharCode($semicolon);
    return buffer.toString();
  }
}
