// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../exception.dart';
import '../../logger.dart';
import '../../parse/scss.dart';
import '../../utils.dart';
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

  /// The name of the rest argument as written in the document, without
  /// underscores converted to hyphens and including the leading `$`.
  ///
  /// This isn't particularly efficient, and should only be used for error
  /// messages.
  String get originalRestArgument {
    if (restArgument == null) return null;

    var text = span.text;
    var fromDollar = text.substring(text.lastIndexOf("\$"));
    return fromDollar.substring(0, text.indexOf("."));
  }

  /// Returns whether this declaration takes no arguments.
  bool get isEmpty => arguments.isEmpty && restArgument == null;

  ArgumentDeclaration(Iterable<Argument> arguments,
      {this.restArgument, this.span})
      : arguments = List.unmodifiable(arguments);

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
  factory ArgumentDeclaration.parse(String contents,
          {Object url, Logger logger}) =>
      ScssParser("($contents)", url: url, logger: logger)
          .parseArgumentDeclaration();

  /// Throws a [SassScriptException] if [positional] and [names] aren't valid
  /// for this argument declaration.
  void verify(int positional, Set<String> names) {
    var namedUsed = 0;
    for (var i = 0; i < arguments.length; i++) {
      var argument = arguments[i];
      if (i < positional) {
        if (names.contains(argument.name)) {
          throw SassScriptException(
              "Argument ${_originalArgumentName(argument.name)} was passed "
              "both by position and by name.");
        }
      } else if (names.contains(argument.name)) {
        namedUsed++;
      } else if (argument.defaultValue == null) {
        throw SassScriptException(
            "Missing argument ${_originalArgumentName(argument.name)}.");
      }
    }

    if (restArgument != null) return;

    if (positional > arguments.length) {
      throw SassScriptException("Only ${arguments.length} "
          "${names.isEmpty ? '' : 'positional '}"
          "${pluralize('argument', arguments.length)} allowed, but "
          "${positional} ${pluralize('was', positional, plural: 'were')} "
          "passed.");
    }

    if (namedUsed < names.length) {
      var unknownNames = Set.of(names)
        ..removeAll(arguments.map((argument) => argument.name));
      throw SassScriptException(
          "No ${pluralize('argument', unknownNames.length)} named "
          "${toSentence(unknownNames.map((name) => "\$$name"), 'or')}.");
    }
  }

  /// Returns the argument named [name] with a leading `$` and its original
  /// underscores (which are otherwise converted to hyphens).
  String _originalArgumentName(String name) {
    if (name == restArgument) return originalRestArgument;

    for (var argument in arguments) {
      if (argument.name == name) return argument.originalName;
    }

    throw ArgumentError('This declaration has no argument named "\$$name".');
  }

  /// Returns whether [positional] and [names] are valid for this argument
  /// declaration.
  bool matches(int positional, Set<String> names) {
    var namedUsed = 0;
    for (var i = 0; i < arguments.length; i++) {
      var argument = arguments[i];
      if (i < positional) {
        if (names.contains(argument.name)) return false;
      } else if (names.contains(argument.name)) {
        namedUsed++;
      } else if (argument.defaultValue == null) return false;
    }

    if (restArgument != null) return true;
    if (positional > arguments.length) return false;
    if (namedUsed < names.length) return false;
    return true;
  }

  String toString() => [
        for (var arg in arguments) arg.toString(),
        if (restArgument != null) '$restArgument...'
      ].join(', ');
}
