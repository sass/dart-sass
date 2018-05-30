// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:isolate';

import 'package:cli_repl/cli_repl.dart';
import 'package:dart2_constant/convert.dart' as convert;
import 'package:path/path.dart' as p;
import 'package:source_maps/source_maps.dart';
import 'package:stack_trace/stack_trace.dart';

import '../sass.dart';
import 'ast/sass.dart';
import 'ast/sass/expression.dart';
import 'ast/sass/statement/variable_declaration.dart';
import 'async_import_cache.dart';
import 'exception.dart';
import 'executable_options.dart';
import 'logger/tracking.dart';
import 'import_cache.dart';
import 'io.dart';
import 'value.dart' as internal;
import 'stylesheet_graph.dart';
import 'visitor/async_evaluate.dart';
import 'visitor/evaluate.dart';
import 'visitor/serialize.dart';

main(List<String> args) async {
  var printedError = false;

  // Prints [error] to stderr, along with a preceding newline if anything else
  // has been printed to stderr.
  //
  // If [trace] is passed, its terse representation is printed after the error.
  void printError(String error, StackTrace stackTrace) {
    if (printedError) stderr.writeln();
    printedError = true;
    stderr.writeln(error);

    if (stackTrace != null) {
      stderr.writeln();
      stderr.writeln(new Trace.from(stackTrace).terse.toString().trimRight());
    }
  }

  ExecutableOptions options;
  try {
    options = new ExecutableOptions.parse(args);
    if (options.version) {
      print(await _loadVersion());
      exitCode = 0;
      return;
    }

    if (options.interactive) {
      _repl(options);
      return;
    }

    var graph = new StylesheetGraph(new ImportCache([],
        loadPaths: options.loadPaths, logger: options.logger));
    for (var source in options.sourcesToDestinations.keys) {
      var destination = options.sourcesToDestinations[source];
      try {
        await _compileStylesheet(options, graph, source, destination);
      } on SassException catch (error, stackTrace) {
        printError(error.toString(color: options.color),
            options.trace ? stackTrace : null);

        // Exit code 65 indicates invalid data per
        // http://www.freebsd.org/cgi/man.cgi?query=sysexits.
        //
        // We let exitCode 66 take precedence for deterministic behavior.
        if (exitCode != 66) exitCode = 65;
      } on FileSystemException catch (error, stackTrace) {
        printError("Error reading ${p.relative(error.path)}: ${error.message}.",
            options.trace ? stackTrace : null);

        // Error 66 indicates no input.
        exitCode = 66;
      }
    }
  } on UsageException catch (error) {
    print("${error.message}\n");
    print("Usage: sass <input.scss> [output.css]\n"
        "       sass <input.scss>:<output.css> <input/>:<output/>\n");
    print(ExecutableOptions.usage);
    exitCode = 64;
  } catch (error, stackTrace) {
    var buffer = new StringBuffer();
    if (options != null && options.color) buffer.write('\u001b[31m\u001b[1m');
    buffer.write('Unexpected exception:');
    if (options != null && options.color) buffer.write('\u001b[0m');
    buffer.writeln();
    buffer.writeln(error);

    printError(buffer.toString(), stackTrace);
    exitCode = 255;
  }
}

/// Loads and returns the current version of Sass.
Future<String> _loadVersion() async {
  var version = const String.fromEnvironment('version');
  if (const bool.fromEnvironment('node')) {
    version += " compiled with dart2js "
        "${const String.fromEnvironment('dart-version')}";
  }
  if (version != null) return version;

  var libDir =
      p.fromUri(await Isolate.resolvePackageUri(Uri.parse('package:sass/')));
  var pubspec = readFile(p.join(libDir, '..', 'pubspec.yaml'));
  return pubspec
      .split("\n")
      .firstWhere((line) => line.startsWith('version: '))
      .split(" ")
      .last;
}

/// Compiles the stylesheet at [source] to [destination].
///
/// Loads files using `graph.importCache` when possible.
///
/// If [source] is `null`, that indicates that the stylesheet should be read
/// from stdin. If [destination] is `null`, that indicates that the stylesheet
/// should be emitted to stdout.
Future _compileStylesheet(ExecutableOptions options, StylesheetGraph graph,
    String source, String destination) async {
  var importer = new FilesystemImporter('.');
  if (options.update) {
    try {
      if (source != null &&
          destination != null &&
          !graph.modifiedSince(
              p.toUri(source), modificationTime(destination), importer)) {
        return;
      }
    } on FileSystemException catch (_) {
      // Compile as normal if the destination file doesn't exist.
    }
  }

  var stylesheet = await _parseStylesheet(options, graph.importCache, source);
  var evaluateResult = options.asynchronous
      ? await evaluateAsync(stylesheet,
          importCache: new AsyncImportCache([],
              loadPaths: options.loadPaths, logger: options.logger),
          importer: importer,
          logger: options.logger,
          sourceMap: options.emitSourceMap)
      : await evaluate(stylesheet,
          importCache: graph.importCache,
          importer: importer,
          logger: options.logger,
          sourceMap: options.emitSourceMap);

  var serializeResult = serialize(evaluateResult.stylesheet,
      style: options.style, sourceMap: options.emitSourceMap);

  var css = serializeResult.css;
  css += _writeSourceMap(options, serializeResult.sourceMap, destination);
  if (destination == null) {
    if (css.isNotEmpty) print(css);
  } else {
    ensureDir(p.dirname(destination));
    writeFile(destination, css + "\n");
  }

  if (!options.update || options.quiet) return;
  var buffer = new StringBuffer();
  if (options.color) buffer.write('\u001b[32m');
  buffer.write('Compiled ${source ?? 'stdin'} to $destination.');
  if (options.color) buffer.write('\u001b[0m');
  print(buffer);
}

/// Parses [source] according to [options], loading it from [graph] if
/// possible.
///
/// Returns the parsed [Stylesheet].
Future<Stylesheet> _parseStylesheet(
    ExecutableOptions options, ImportCache importCache, String source) async {
  // Import from the cache if possible so it caches the file in case anything
  // else imports it.
  if (source != null && options.indented == null) {
    return importCache.importCanonical(new FilesystemImporter('.'),
        p.toUri(p.absolute(source)), p.toUri(source));
  }

  var text = source == null ? await readStdin() : readFile(source);
  var url = source == null ? null : p.toUri(source);
  return options.indented ?? (source != null && p.extension(source) == '.sass')
      ? new Stylesheet.parseSass(text, url: url, logger: options.logger)
      : new Stylesheet.parseScss(text, url: url, logger: options.logger);
}

/// Writes the source map given by [mapping] to disk (if necessary) according to
/// [options].
///
/// The [destination] is the path where the CSS file associated with this source
/// map will be written. If it's `null`, that indicates that the CSS will be
/// printed to stdout.
///
/// Returns the source map comment to add to the end of the CSS file.
String _writeSourceMap(
    ExecutableOptions options, SingleMapping sourceMap, String destination) {
  if (sourceMap == null) return "";

  if (destination != null) {
    sourceMap.targetUrl = p.toUri(p.basename(destination)).toString();
  }

  for (var i = 0; i < sourceMap.urls.length; i++) {
    var url = sourceMap.urls[i];

    // The special URL "" indicates a file that came from stdin.
    if (url == "") continue;

    sourceMap.urls[i] =
        options.sourceMapUrl(Uri.parse(url), destination).toString();
  }
  var sourceMapText = convert.json
      .encode(sourceMap.toJson(includeSourceContents: options.embedSources));

  Uri url;
  if (options.embedSourceMap) {
    url = new Uri.dataFromString(sourceMapText, mimeType: 'application/json');
  } else {
    var sourceMapPath = destination + '.map';
    ensureDir(p.dirname(sourceMapPath));
    writeFile(sourceMapPath, sourceMapText);

    url = p.toUri(sourceMapPath);
  }

  return (options.style == OutputStyle.compressed ? '' : '\n\n') +
      '/*# sourceMappingURL=$url */';
}

/// Runs an interactive SassScript shell.
_repl(ExecutableOptions options) async {
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
        expression = new Expression.parse(line, logger: logger);
      }
      var result =
          evaluateExpression(expression, variables: variables, logger: logger);
      if (declaration != null) {
        variables[declaration.name] = result;
      }
      print(result);
    } on SassException catch (error, stackTrace) {
      _logError(error, stackTrace, line, repl, options, logger);
    }
  }
}

/// Logs an error from the interactive shell.
_logError(SassException error, StackTrace stackTrace, String line, Repl repl,
    ExecutableOptions options, TrackingLogger logger) {
  // If something was logged after the input, just print the error.
  if (options.logger != Logger.quiet &&
      (logger.emittedDebug || logger.emittedWarning)) {
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
    // Position cursor.
    buffer.write("\u001b[1F\u001b[${start + 3}C");
    // Write bad input.
    buffer.writeln(line.substring(start, arrows.length));
  }
  // Align arrows to start of input.
  buffer.write(" " * repl.prompt.length);
  buffer.writeln(arrows);
  // Reset color.
  if (options.color) buffer.write("\u001b[0m");

  buffer.writeln("Error: ${error.message}");
  if (options.trace) {
    buffer.write(new Trace.from(stackTrace).terse);
  }
  print(buffer.toString().trimRight());
}
