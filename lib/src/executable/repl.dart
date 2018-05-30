// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:cli_repl/cli_repl.dart';
import 'package:stack_trace/stack_trace.dart';

import '../ast/sass.dart';
import '../exception.dart';
import '../executable/options.dart';
import '../logger/tracking.dart';
import '../value.dart' as internal;
import '../visitor/evaluate.dart';

/// Runs an interactive SassScript shell according to [options].
Future repl(ExecutableOptions options) async {
  var repl = new Repl(prompt: '>> ');
  var variables = <String, internal.Value>{};
  await for (String line in repl.runAsync()) {
    if (line.trim().isEmpty) continue;
    var logger = new TrackingLogger(options.logger);
    try {
      Expression expression;
      VariableDeclaration declaration;
      try {
        declaration = new VariableDeclaration.parse(line, logger: logger);
        expression = declaration.expression;
      } on SassFormatException {
        // TODO(nweiz): If [line] looks like a variable assignment, rethrow the
        // original exception.
        expression = new Expression.parse(line, logger: logger);
      }

      var result =
          evaluateExpression(expression, variables: variables, logger: logger);
      if (declaration != null) variables[declaration.name] = result;
      print(result);
    } on SassException catch (error, stackTrace) {
      _logError(error, stackTrace, line, repl, options, logger);
    }
  }
}

/// Logs an error from the interactive shell.
void _logError(SassException error, StackTrace stackTrace, String line,
    Repl repl, ExecutableOptions options, TrackingLogger logger) {
  // If something was logged after the input, just print the error.
  if (!options.quiet && (logger.emittedDebug || logger.emittedWarning)) {
    print("Error: ${error.message}");
    print(error.span.highlight(color: options.color));
    return;
  }

  // Otherwise, highlight the bad input from the previous line.
  var arrows = error.span.highlight().split('\n').last.trimRight();
  var buffer = new StringBuffer();
  if (options.color) buffer.write("\u001b[31m");

  if (options.color && arrows.length <= line.length) {
    int start = arrows.length - arrows.trimLeft().length;
    // Position the cursor at the beginning of the error text.
    buffer.write("\u001b[1F\u001b[${start + 3}C");
    // Rewrite the bad input, this time in red text.
    buffer.writeln(line.substring(start, arrows.length));
  }

  // Write arrows underneath the error text.
  buffer.write(" " * repl.prompt.length);
  buffer.writeln(arrows);
  if (options.color) buffer.write("\u001b[0m");

  buffer.writeln("Error: ${error.message}");
  if (options.trace) buffer.write(new Trace.from(stackTrace).terse);
  print(buffer.toString().trimRight());
}
