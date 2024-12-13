// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../exception.dart';
import '../../parse/scss.dart';
import '../../util/character.dart';
import '../../util/span.dart';
import '../../utils.dart';
import 'parameter.dart';
import 'node.dart';

/// An parameter declaration, as for a function or mixin definition.
///
/// {@category AST}
/// {@category Parsing}
final class ParameterList implements SassNode {
  /// The parameters that are taken.
  final List<Parameter> parameters;

  /// The name of the rest parameter (as in `$args...`), or `null` if none was
  /// declared.
  final String? restParameter;

  final FileSpan span;

  /// Returns [span] expanded to include an identifier immediately before the
  /// declaration, if possible.
  FileSpan get spanWithName {
    var text = span.file.getText(0);

    // Move backwards through any whitespace between the name and the parameters.
    var i = span.start.offset - 1;
    while (i > 0 && text.codeUnitAt(i).isWhitespace) {
      i--;
    }

    // Then move backwards through the name itself.
    if (!text.codeUnitAt(i).isName) return span;
    i--;
    while (i >= 0 && text.codeUnitAt(i).isName) {
      i--;
    }

    // If the name didn't start with [isNameStart], it's not a valid identifier.
    if (!text.codeUnitAt(i + 1).isNameStart) return span;

    // Trim because it's possible that this span is empty (for example, a mixin
    // may be declared without an parameter list).
    return span.file.span(i + 1, span.end.offset).trim();
  }

  /// Returns whether this declaration takes no parameters.
  bool get isEmpty => parameters.isEmpty && restParameter == null;

  ParameterList(Iterable<Parameter> parameters, this.span, {this.restParameter})
      : parameters = List.unmodifiable(parameters);

  /// Creates a declaration that declares no parameters.
  ParameterList.empty(this.span)
      : parameters = const [],
        restParameter = null;

  /// Parses an parameter declaration from [contents], which should be of the
  /// form `@rule name(args) {`.
  ///
  /// If passed, [url] is the name of the file from which [contents] comes.
  ///
  /// Throws a [SassFormatException] if parsing fails.
  factory ParameterList.parse(String contents, {Object? url}) =>
      ScssParser(contents, url: url).parseParameterList();

  /// Throws a [SassScriptException] if [positional] and [names] aren't valid
  /// for this parameter declaration.
  void verify(int positional, Set<String> names) {
    var namedUsed = 0;
    for (var i = 0; i < parameters.length; i++) {
      var parameter = parameters[i];
      if (i < positional) {
        if (names.contains(parameter.name)) {
          throw SassScriptException(
              "Argument ${_originalParameterName(parameter.name)} was passed "
              "both by position and by name.");
        }
      } else if (names.contains(parameter.name)) {
        namedUsed++;
      } else if (parameter.defaultValue == null) {
        throw MultiSpanSassScriptException(
            "Missing argument ${_originalParameterName(parameter.name)}.",
            "invocation",
            {spanWithName: "declaration"});
      }
    }

    if (restParameter != null) return;

    if (positional > parameters.length) {
      throw MultiSpanSassScriptException(
          "Only ${parameters.length} "
              "${names.isEmpty ? '' : 'positional '}"
              "${pluralize('argument', parameters.length)} allowed, but "
              "$positional ${pluralize('was', positional, plural: 'were')} "
              "passed.",
          "invocation",
          {spanWithName: "declaration"});
    }

    if (namedUsed < names.length) {
      var unknownNames = Set.of(names)
        ..removeAll(parameters.map((parameter) => parameter.name));
      throw MultiSpanSassScriptException(
          "No ${pluralize('parameter', unknownNames.length)} named "
              "${toSentence(unknownNames.map((name) => "\$$name"), 'or')}.",
          "invocation",
          {spanWithName: "declaration"});
    }
  }

  /// Returns the parameter named [name] with a leading `$` and its original
  /// underscores (which are otherwise converted to hyphens).
  String _originalParameterName(String name) {
    if (name == restParameter) {
      var text = span.text;
      var fromDollar = text.substring(text.lastIndexOf("\$"));
      return fromDollar.substring(0, text.indexOf("."));
    }

    for (var parameter in parameters) {
      if (parameter.name == name) return parameter.originalName;
    }

    throw ArgumentError('This declaration has no parameter named "\$$name".');
  }

  /// Returns whether [positional] and [names] are valid for this parameter
  /// declaration.
  bool matches(int positional, Set<String> names) {
    var namedUsed = 0;
    for (var i = 0; i < parameters.length; i++) {
      var parameter = parameters[i];
      if (i < positional) {
        if (names.contains(parameter.name)) return false;
      } else if (names.contains(parameter.name)) {
        namedUsed++;
      } else if (parameter.defaultValue == null) {
        return false;
      }
    }

    if (restParameter != null) return true;
    if (positional > parameters.length) return false;
    if (namedUsed < names.length) return false;
    return true;
  }

  String toString() => [
        for (var arg in parameters) '\$$arg',
        if (restParameter != null) '\$$restParameter...'
      ].join(', ');
}
