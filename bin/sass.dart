// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:stack_trace/stack_trace.dart';
import 'package:term_glyph/term_glyph.dart' as term_glyph;

import 'package:sass/src/executable/concurrent.dart';
import 'package:sass/src/executable/options.dart';
import 'package:sass/src/executable/repl.dart';
import 'package:sass/src/executable/watch.dart';
import 'package:sass/src/import_cache.dart';
import 'package:sass/src/importer/filesystem.dart';
import 'package:sass/src/io.dart';
import 'package:sass/src/stylesheet_graph.dart';
import 'package:sass/src/utils.dart';
import 'package:sass/src/embedded/executable.dart'
    // Never load the embedded protocol when compiling to JS.
    if (dart.library.js) 'package:sass/src/embedded/unavailable.dart'
    as embedded;

Future<void> main(List<String> args) async {
  if (args case ['--embedded', ...var rest]) {
    embedded.main(rest);
    return;
  }

  ExecutableOptions? options;
  try {
    options = ExecutableOptions.parse(args);
    term_glyph.ascii = !options.unicode;

    if (options.version) {
      print(await _loadVersion());
      exitCode = 0;
      return;
    }

    if (options.interactive) {
      await repl(options);
      return;
    }

    var graph = StylesheetGraph(ImportCache(
        importers: [...options.pkgImporters, FilesystemImporter.noLoadPath],
        loadPaths: options.loadPaths));
    if (options.watch) {
      await watch(options, graph);
      return;
    }

    await compileStylesheets(options, graph, options.sourcesToDestinations,
        ifModified: options.update);
  } on UsageException catch (error) {
    print("${error.message}\n");
    print("Usage: sass <input.scss> [output.css]\n"
        "       sass <input.scss>:<output.css> <input/>:<output/> <dir/>\n");
    print(ExecutableOptions.usage);
    exitCode = 64;
  } catch (error, stackTrace) {
    var buffer = StringBuffer();
    if (options?.color ?? false) buffer.write('\u001b[31m\u001b[1m');
    buffer.write('Unexpected exception:');
    if (options?.color ?? false) buffer.write('\u001b[0m');
    buffer.writeln();
    buffer.writeln(error);
    buffer.writeln();
    buffer.writeln();
    buffer.write(
        Trace.from(getTrace(error) ?? stackTrace).terse.toString().trimRight());
    printError(buffer);
    exitCode = 255;
  }
}

/// Loads and returns the current version of Sass.
Future<String> _loadVersion() async {
  if (const bool.hasEnvironment('version')) {
    var version = const String.fromEnvironment('version');
    if (const bool.fromEnvironment('node')) {
      version += " compiled with dart2js "
          "${const String.fromEnvironment('dart-version')}";
    }
    return version;
  }

  var libDir =
      p.fromUri(await Isolate.resolvePackageUri(Uri.parse('package:sass/')));
  var pubspec = readFile(p.join(libDir, '..', 'pubspec.yaml'));
  return pubspec
      .split("\n")
      .firstWhere((line) => line.startsWith('version: '))
      .split(" ")
      .last;
}
