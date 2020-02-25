// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:convert';
import 'dart:io';

import 'package:charcode/charcode.dart';
import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import 'grind/synchronize.dart';

export 'grind/bazel.dart';
export 'grind/benchmark.dart';
export 'grind/sanity_check.dart';
export 'grind/synchronize.dart';

void main(List<String> args) {
  pkg.humanName = "Dart Sass";
  pkg.botName = "Sass Bot";
  pkg.botEmail = "sass.bot.beep.boop@gmail.com";
  pkg.executables = {"sass": "bin/sass.dart"};
  pkg.chocolateyNuspec = _nuspec;
  pkg.homebrewRepo = "sass/homebrew-sass";
  pkg.homebrewFormula = "sass.rb";
  pkg.jsRequires = {"fs": "fs", "chokidar": "chokidar", "readline": "readline"};
  pkg.jsModuleMainLibrary = "lib/src/node.dart";
  pkg.npmPackageJson =
      json.decode(File("package/package.json").readAsStringSync())
          as Map<String, Object>;
  pkg.npmReadme = _readAndResolveMarkdown("package/README.npm.md");
  pkg.standaloneName = "dart-sass";

  pkg.addAllTasks();
  grind(args);
}

@DefaultTask('Compile async code and reformat.')
@Depends(format, synchronize)
void all() {}

@Task('Run the Dart formatter.')
void format() {
  Pub.run('dart_style', script: 'format', arguments: [
    '--overwrite',
    '--fix',
    for (var dir in existingSourceDirs) dir.path
  ]);
}

@Task('Installs dependencies from npm.')
void npmInstall() => run("npm", arguments: ["install"]);

@Task('Runs the tasks that are required for running tests.')
@Depends(format, synchronize, "pkg-npm-dev", npmInstall, "pkg-standalone-dev")
void beforeTest() {}

String get _nuspec => """
<?xml version="1.0"?>
<package xmlns="http://schemas.microsoft.com/packaging/2010/07/nuspec.xsd">
  <metadata>
    <id>sass</id>
    <title>Sass</title>
    <authors>Natalie Weizenbaum</authors>
    <owners>nex3</owners>
    <projectUrl>https://github.com/sass/dart-sass</projectUrl>
    <licenseUrl>https://github.com/sass/dart-sass/blob/${pkg.version}/LICENSE</licenseUrl>
    <iconUrl>https://cdn.rawgit.com/sass/sass-site/f99ee33e4f688e244c7a5902c59d61f78daccc55/source/assets/img/logos/logo-seal.png</iconUrl>
    <bugTrackerUrl>https://github.com/sass/dart-sass/issues</bugTrackerUrl>
    <description>**Sass makes CSS fun again**. Sass is an extension of CSS, adding nested rules, variables, mixins, selector inheritance, and more. It's translated to well-formatted, standard CSS using the command line tool or a web-framework plugin.

This package is Dart Sass, the new Dart implementation of Sass.</description>
    <summary>Sass makes CSS fun again.</summary>
    <tags>css preprocessor style sass</tags>
    <copyright>Copyright ${DateTime.now().year} Google, Inc.</copyright>
  </metadata>
</package>
""";

final _readAndResolveRegExp = RegExp(
    r"^<!-- +#include +([^\s]+) +"
    '"([^"\n]+)"'
    r" +-->$",
    multiLine: true);

/// Reads a Markdown file from [path] and resolves include directives.
///
/// Include directives have the syntax `"<!-- #include" PATH HEADER "-->"`,
/// which must appear on its own line. PATH is a relative file: URL to another
/// Markdown file, and HEADER is the name of a header in that file whose
/// contents should be included as-is.
String _readAndResolveMarkdown(String path) => File(path)
        .readAsStringSync()
        .replaceAllMapped(_readAndResolveRegExp, (match) {
      String included;
      try {
        included = File(p.join(p.dirname(path), p.fromUri(match[1])))
            .readAsStringSync();
      } catch (error) {
        _matchError(match, error.toString(), url: p.toUri(path));
      }

      Match headerMatch;
      try {
        headerMatch = "# ${match[2]}".allMatches(included).first;
      } on StateError {
        _matchError(match, "Could not find header.", url: p.toUri(path));
      }

      var headerLevel = 0;
      var index = headerMatch.start;
      while (index >= 0 && included.codeUnitAt(index) == $hash) {
        headerLevel++;
        index--;
      }

      // The section goes until the next header of the same level, or the end
      // of the document.
      var sectionEnd = included.indexOf("#" * headerLevel, headerMatch.end);
      if (sectionEnd == -1) sectionEnd = included.length;

      return included.substring(headerMatch.end, sectionEnd).trim();
    });

/// Throws a nice [SourceSpanException] associated with [match].
void _matchError(Match match, String message, {Object url}) {
  var file = SourceFile.fromString(match.input, url: url);
  throw SourceSpanException(message, file.span(match.start, match.end));
}
