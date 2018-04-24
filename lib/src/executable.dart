// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:isolate';

import 'package:stack_trace/stack_trace.dart';

import '../sass.dart';
import 'exception.dart';
import 'executable_options.dart';
import 'io.dart';
import 'util/path.dart';

main(List<String> args) async {
  ExecutableOptions options;
  try {
    options = new ExecutableOptions.parse(args);
    if (options.version) {
      print(await _loadVersion());
      exitCode = 0;
      return;
    }

    try {
      String css;
      if (options.readFromStdin) {
        var text = await readStdin();
        var importer = new FilesystemImporter('.');
        if (options.asynchronous) {
          css = await compileStringAsync(text,
              indented: options.indented,
              logger: options.logger,
              style: options.style,
              importer: importer,
              loadPaths: options.loadPaths);
        } else {
          css = compileString(text,
              indented: options.indented,
              logger: options.logger,
              style: options.style,
              importer: importer,
              loadPaths: options.loadPaths);
        }
      } else if (options.asynchronous) {
        css = await compileAsync(options.source,
            logger: options.logger,
            style: options.style,
            loadPaths: options.loadPaths);
      } else {
        css = compile(options.source,
            logger: options.logger,
            style: options.style,
            loadPaths: options.loadPaths);
      }

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
