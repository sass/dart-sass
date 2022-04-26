// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';

import '../../exception.dart';
import '../../logger.dart';
import '../../parse/scss.dart';
import '../../utils.dart';
import '../../util/character.dart';
import '../../util/span.dart';
import 'argument.dart';
import 'node.dart';

/// An argument declaration, as for a function or mixin definition.
///
/// {@category AST}
/// {@category Parsing}
@sealed
class ArgumentDeclaration implements SassNode {
  /// The arguments that are taken.
  final List<Argument> arguments;

  /// The name of the rest argument (as in `$args...`), or `null` if none was
  /// declared.
  final String? restArgument;

  final FileSpan span;

  /// Returns [span] expanded to include an identifier immediately before the
  /// declaration, if possible.
  FileSpan get spanWithName {
    var text = span.file.getText(0);

    // Move backwards through any whitespace between the name and the arguments.
    var i = span.start.offset - 1;
    while (i > 0 && isWhitespace(text.codeUnitAt(i))) {
      i--;
    }

    // Then move backwards through the name itself.
    if (!isName(text.codeUnitAt(i))) return span;
    i--;
    while (i >= 0 && isName(text.codeUnitAt(i))) {
      i--;
    }

    // If the name didn't start with [isNameStart], it's not a valid identifier.
    if (!isNameStart(text.codeUnitAt(i + 1))) return span;

    // Trim because it's possible that this span is empty (for example, a mixin
    // may be declared without an argument list).
    return span.file.span(i + 1, span.end.offset).trim();
  }

  /// Returns whether this declaration takes no arguments.
  bool get isEmpty => arguments.isEmpty && restArgument == null;

  ArgumentDeclaration(Iterable<Argument> arguments, this.span,
      {this.restArgument})
      : arguments = List.unmodifiable(arguments);

  /// Creates a declaration that declares no arguments.
  ArgumentDeclaration.empty(this.span)
      : arguments = const [],
        restArgument = null;

  /// Parses an argument declaration from [contents], which should be of the
  /// form `@rule name(args) {`.
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory ArgumentDeclaration.parse(String contents,
          {Object? url, Logger? logger}) =>
      ScssParser(contents, url: url, logger: logger).parseArgumentDeclaration();

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
        throw MultiSpanSassScriptException(
            "Missing argument ${_originalArgumentName(argument.name)}.",
            "invocation",
            {spanWithName: "declaration"});
      }
    }

    if (restArgument != null) return;

    if (positional > arguments.length) {
      throw MultiSpanSassScriptException(
          "Only ${arguments.length} "
              "${names.isEmpty ? '' : 'positional '}"
              "${pluralize('argument', arguments.length)} allowed, but "
              "$positional ${pluralize('was', positional, plural: 'were')} "
              "passed.",
          "invocation",
          {spanWithName: "declaration"});
    }

    if (namedUsed < names.length) {
      var unknownNames = Set.of(names)
        ..removeAll(arguments.map((argument) => argument.name));
      throw MultiSpanSassScriptException(
          "No ${pluralize('argument', unknownNames.length)} named "
              "${toSentence(unknownNames.map((name) => "\$$name"), 'or')}.",
          "invocation",
          {spanWithName: "declaration"});
    }
  }

  /// Returns the argument named [name] with a leading `$` and its original
  /// underscores (which are otherwise converted to hyphens).
  String _originalArgumentName(String name) {
    if (name == restArgument) {
      var text = span.text;
      var fromDollar = text.substring(text.lastIndexOf("\$"));
      return fromDollar.substring(0, text.indexOf("."));
    }

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
      } else if (argument.defaultValue == null) {
        return false;
      }
    }

    if (restArgument != null) return true;
    if (positional > arguments.length) return false;
    if (namedUsed < names.length) return false;
    return true;
  }

  String toString() => [
        for (var arg in arguments) '\$$arg',
        if (restArgument != null) '\$$restArgument...'
      ].join(', ');
}
