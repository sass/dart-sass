// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:isolate';

import 'package:dart2_constant/convert.dart' as convert;
import 'package:source_maps/source_maps.dart';
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

    for (var source in options.sourcesToDestinations.keys) {
      var destination = options.sourcesToDestinations[source];
      await _compileStylesheet(options, source, destination);
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

/// Compiles the stylesheet at [source] to [destination].
///
/// If [source] is `null`, that indicates that the stylesheet should be read
/// from stdin. If [destination] is `null`, that indicates that the stylesheet
/// should be emitted to stdout.
Future _compileStylesheet(
    ExecutableOptions options, String source, String destination) async {
  try {
    SingleMapping sourceMap;
    var sourceMapCallback =
        options.emitSourceMap ? (SingleMapping map) => sourceMap = map : null;

    var indented =
        options.indented ?? (source != null && p.extension(source) == '.sass');
    var text = source == null ? await readStdin() : readFile(source);
    var url = source == null ? null : p.toUri(source);
    var importer = new FilesystemImporter('.');
    String css;
    if (options.asynchronous) {
      css = await compileStringAsync(text,
          indented: indented,
          logger: options.logger,
          style: options.style,
          importer: importer,
          loadPaths: options.loadPaths,
          url: url,
          sourceMap: sourceMapCallback);
    } else {
      css = compileString(text,
          indented: indented,
          logger: options.logger,
          style: options.style,
          importer: importer,
          loadPaths: options.loadPaths,
          url: url,
          sourceMap: sourceMapCallback);
    }

    css += _writeSourceMap(options, sourceMap, destination);
    if (destination == null) {
      if (css.isNotEmpty) print(css);
    } else {
      ensureDir(p.dirname(destination));
      writeFile(destination, css + "\n");
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
    stderr
        .writeln("Error reading ${p.relative(error.path)}: ${error.message}.");

    // Error 66 indicates no input.
    exitCode = 66;

    if (options.trace) {
      stderr.writeln();
      stderr.write(new Trace.from(stackTrace).terse.toString());
      stderr.flush();
    }
  }
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
