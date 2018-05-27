// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:isolate';

import 'package:cli_repl/cli_repl.dart';
import 'package:dart2_constant/convert.dart' as convert;
import 'package:source_maps/source_maps.dart';
import 'package:stack_trace/stack_trace.dart';

import '../sass.dart';
import 'ast/sass/expression.dart';
import 'ast/sass/statement/variable_declaration.dart';
import 'exception.dart';
import 'executable_options.dart';
import 'io.dart';
import 'util/path.dart';
import 'value.dart' as internal;
import 'visitor/evaluate.dart';

main(List<String> args) async {
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

    try {
      SingleMapping sourceMap;
      var sourceMapCallback =
          options.emitSourceMap ? (SingleMapping map) => sourceMap = map : null;

      var text =
          options.readFromStdin ? await readStdin() : readFile(options.source);
      var url = options.readFromStdin ? null : p.toUri(options.source);
      var importer = new FilesystemImporter('.');
      String css;
      if (options.asynchronous) {
        css = await compileStringAsync(text,
            indented: options.indented,
            logger: options.logger,
            style: options.style,
            importer: importer,
            loadPaths: options.loadPaths,
            url: url,
            sourceMap: sourceMapCallback);
      } else {
        css = compileString(text,
            indented: options.indented,
            logger: options.logger,
            style: options.style,
            importer: importer,
            loadPaths: options.loadPaths,
            url: url,
            sourceMap: sourceMapCallback);
      }

      css += _writeSourceMap(options, sourceMap);
      if (options.writeToStdout) {
        if (css.isNotEmpty) print(css);
      } else {
        ensureDir(p.dirname(options.destination));
        writeFile(options.destination, css + "\n");
      }
    } on SassException catch (error, stackTrace) {
      stderr.writeln(error.toString(color: options.color));

      if (options.trace) {
        stderr.writeln();
        stderr.write(new Trace.from(stackTrace).terse.toString());
        stderr.flush();
      }

      // Exit code 65 indicates invalid data per
      // http://www.freebsd.org/cgi/man.cgi?query=sysexits.
      exitCode = 65;
    } on FileSystemException catch (error, stackTrace) {
      stderr.writeln(
          "Error reading ${p.relative(error.path)}: ${error.message}.");

      // Error 66 indicates no input.
      exitCode = 66;

      if (options.trace) {
        stderr.writeln();
        stderr.write(new Trace.from(stackTrace).terse.toString());
        stderr.flush();
      }
    }
  } on UsageException catch (error) {
    print("${error.message}\n");
    print("Usage: sass <input> [output]\n");
    print(ExecutableOptions.usage);
    exitCode = 64;
  } catch (error, stackTrace) {
    if (options != null && options.color) stderr.write('\u001b[31m\u001b[1m');
    stderr.write('Unexpected exception:');
    if (options != null && options.color) stderr.write('\u001b[0m');
    stderr.writeln();

    stderr.writeln(error);
    stderr.writeln();
    stderr.write(new Trace.from(stackTrace).terse.toString());
    await stderr.flush();
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

/// Writes the source map given by [mapping] to disk (if necessary) according to [options].
///
/// Returns the source map comment to add to the end of the CSS file.
String _writeSourceMap(ExecutableOptions options, SingleMapping sourceMap) {
  if (sourceMap == null) return "";

  if (!options.writeToStdout) {
    sourceMap.targetUrl = p.toUri(p.basename(options.destination)).toString();
  }

  for (var i = 0; i < sourceMap.urls.length; i++) {
    var url = sourceMap.urls[i];

    // The special URL "" indicates a file that came from stdin.
    if (url == "") continue;

    sourceMap.urls[i] = options.sourceMapUrl(Uri.parse(url)).toString();
  }
  var sourceMapText = convert.json
      .encode(sourceMap.toJson(includeSourceContents: options.embedSources));

  Uri url;
  if (options.embedSourceMap) {
    url = new Uri.dataFromString(sourceMapText, mimeType: 'application/json');
  } else {
    var sourceMapPath = options.destination + '.map';
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
    try {
      Expression expression;
      VariableDeclaration declaration;
      try {
        declaration = new VariableDeclaration.parse(line);
        expression = declaration.expression;
      } on SassFormatException {
        expression = new Expression.parse(line);
      }
      var result = evaluateExpression(expression, variables: variables);
      if (declaration != null) {
        variables[declaration.name] = result;
      }
      print(result);
    } on SassException catch (error, stackTrace) {
      var highlighted = error.span.highlight();
      var arrows = highlighted.split('\n').last.trimRight();
      var buffer = new StringBuffer();
      if (options.color) buffer.write("\u001b[31m"); // set color to red
      if (options.color && arrows.length <= line.length) {
        int start = arrows.length - arrows.trimLeft().length;
        buffer.write("\u001b[1F"); // move to start of input line
        buffer.write("\u001b[${start + 3}C"); // move to start of error
        buffer.write(line.substring(start, arrows.length)); // write bad input
        buffer.write("\n"); // move to start of output line
      }
      buffer.write(" " * repl.prompt.length); // align with start of input
      buffer.writeln(arrows);
      if (options.color) buffer.write("\u001b[0m"); // clear color
      buffer.writeln("Error: ${error.message}");
      if (options.trace) {
        buffer.write(new Trace.from(stackTrace).terse);
      }
      print(buffer.toString().trimRight());
    }
  }
}
