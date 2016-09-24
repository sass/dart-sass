// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../parse/scss.dart';
import 'argument.dart';
import 'node.dart';

class ArgumentDeclaration implements SassNode {
  final List<Argument> arguments;

  final String restArgument;

  final FileSpan span;

  ArgumentDeclaration(Iterable<Argument> arguments,
      {this.restArgument, this.span})
      : arguments = new List.unmodifiable(arguments);

  ArgumentDeclaration.empty({this.span})
      : arguments = const [],
        restArgument = null;

  factory ArgumentDeclaration.parse(String contents, {url}) =>
      new ScssParser("($contents)", url: url).parseArgumentDeclaration();

  String toString() =>
      arguments.join(', ') + (restArgument == null ? '' : ", $restArgument...");
}
