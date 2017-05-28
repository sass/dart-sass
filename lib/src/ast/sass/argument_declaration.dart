// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../parse/scss.dart';
import 'argument.dart';
import 'node.dart';

/// An argument declaration, as for a function or mixin definition.
class ArgumentDeclaration implements SassNode {
  /// The arguments that are taken.
  final List<Argument> arguments;

  /// The name of the rest argument (as in `$args...`), or `null` if none was
  /// declared.
  final String restArgument;

  final FileSpan span;

  ArgumentDeclaration(Iterable<Argument> arguments,
      {this.restArgument, this.span})
      : arguments = new List.unmodifiable(arguments);

  /// Creates a declaration that declares no arguments.
  ArgumentDeclaration.empty({this.span})
      : arguments = const [],
        restArgument = null;

  /// Parses an argument declaration from [contents], which should not include
  /// parentheses.
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory ArgumentDeclaration.parse(String contents, {url}) =>
      new ScssParser("($contents)", url: url).parseArgumentDeclaration();

  String toString() {
    var components =
        new List<String>.from(arguments.map((arg) => arg.toString()));
    if (restArgument != null) {
      components.add('$restArgument...');
    }
    return components.join(', ');
  }
}
