// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:math' as math;

import 'package:cli_repl/cli_repl.dart';
import 'package:stack_trace/stack_trace.dart';

import '../ast/sass.dart';
import '../exception.dart';
import '../executable/options.dart';
import '../import_cache.dart';
import '../importer/filesystem.dart';
import '../logger/tracking.dart';
import '../parse/parser.dart';
import '../visitor/evaluate.dart';

/// Runs an interactive SassScript shell according to [options].
Future<void> repl(ExecutableOptions options) async {
  var repl = Repl(prompt: '>> ');
  var logger = TrackingLogger(options.logger);
  var evaluator = Evaluator(
      importer: FilesystemImporter('.'),
      importCache:
          ImportCache(const [], loadPaths: options.loadPaths, logger: logger),
      logger: logger);
  await for (String line in repl.runAsync()) {
    if (line.trim().isEmpty) continue;
    try {
      if (line.startsWith("@")) {
        evaluator.use(UseRule.parse(line, logger: logger));
        continue;
      }

      if (Parser.isVariableDeclarationLike(line)) {
        var declaration = VariableDeclaration.parse(line, logger: logger);
        evaluator.setVariable(declaration);
        print(evaluator.evaluate(VariableExpression(
            declaration.name, declaration.span,
            namespace: declaration.namespace)));
      } else {
        print(evaluator.evaluate(Expression.parse(line, logger: logger)));
      }
    } on SassException catch (error, stackTrace) {
      _logError(error, stackTrace, line, repl, options, logger);
    }
  }
}

/// Logs an error from the interactive shell.
void _logError(SassException error, StackTrace stackTrace, String line,
    Repl repl, ExecutableOptions options, TrackingLogger logger) {
  // If the error doesn't come from the repl line, or if something was logged
  // after the user's input, just print the error normally.
  if (error.span.sourceUrl != null ||
      (!options.quiet && (logger.emittedDebug || logger.emittedWarning))) {
    print(error.toString(color: options.color));
    return;
  }

  // Otherwise, highlight the bad input from the previous line.
  var buffer = StringBuffer();
  if (options.color) buffer.write("\u001b[31m");

  var spacesBeforeError = repl.prompt.length + error.span.start.column;
  if (options.color && error.span.start.column < line.length) {
    // Position the cursor at the beginning of the error text.
    buffer.write("\u001b[1F\u001b[${spacesBeforeError}C");
    // Rewrite the bad input, this time in red text.
    buffer.writeln(error.span.text);
  }

  // Write arrows underneath the error text.
  buffer.write(" " * spacesBeforeError);
  buffer.writeln("^" * math.max(1, error.span.length));
  if (options.color) buffer.write("\u001b[0m");

  buffer.writeln("Error: ${error.message}");
  if (options.trace) buffer.write(Trace.from(stackTrace).terse);
  print(buffer.toString().trimRight());
}
