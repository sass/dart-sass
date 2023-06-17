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
import 'grind/utils.dart';

export 'grind/bazel.dart';
export 'grind/benchmark.dart';
export 'grind/double_check.dart';
export 'grind/frameworks.dart';
export 'grind/subpackages.dart';
export 'grind/synchronize.dart';

void main(List<String> args) {
  pkg.humanName.value = "Dart Sass";
  pkg.botName.value = "Sass Bot";
  pkg.botEmail.value = "sass.bot.beep.boop@gmail.com";
  pkg.executables.value = {"sass": "bin/sass.dart"};
  pkg.chocolateyNuspec.value = _nuspec;
  pkg.homebrewRepo.value = "sass/homebrew-sass";
  pkg.homebrewFormula.value = "Formula/sass.rb";
  pkg.jsRequires.value = [
    pkg.JSRequire("immutable", target: pkg.JSRequireTarget.all),
    pkg.JSRequire("chokidar", target: pkg.JSRequireTarget.cli),
    pkg.JSRequire("readline", target: pkg.JSRequireTarget.cli),
    pkg.JSRequire("fs", target: pkg.JSRequireTarget.node),
    pkg.JSRequire("stream", target: pkg.JSRequireTarget.node),
    pkg.JSRequire("util", target: pkg.JSRequireTarget.node),
  ];
  pkg.jsModuleMainLibrary.value = "lib/src/node.dart";
  pkg.npmPackageJson.fn = () =>
      json.decode(File("package/package.json").readAsStringSync())
          as Map<String, dynamic>;
  pkg.npmReadme.fn = () => _readAndResolveMarkdown("package/README.npm.md");
  pkg.npmAdditionalFiles.fn = _fetchJSTypes;
  pkg.standaloneName.value = "dart-sass";
  pkg.githubUser.fn = () => Platform.environment["GH_USER"];
  pkg.githubPassword.fn = () => Platform.environment["GH_TOKEN"];
  pkg.jsEsmExports.value = {
    'compile',
    'compileAsync',
    'compileString',
    'compileStringAsync',
    'Logger',
    'SassArgumentList',
    'SassBoolean',
    'SassCalculation',
    'CalculationOperation',
    'CalculationInterpolation',
    'SassColor',
    'SassFunction',
    'SassList',
    'SassMap',
    'SassNumber',
    'SassString',
    'Value',
    'CustomFunction',
    'ListSeparator',
    'sassFalse',
    'sassNull',
    'sassTrue',
    'Exception',
    'PromiseOr',
    'info',
    'render',
    'renderSync',
  };

  pkg.githubReleaseNotes.fn = () =>
      "To install Sass ${pkg.version}, download one of the packages below "
      "and [add it to your PATH][], or see [the Sass website][] for full "
      "installation instructions.\n"
      "\n"
      "[add it to your PATH]: https://katiek2.github.io/path-doc/\n"
      "[the Sass website]: https://sass-lang.com/install\n"
      "\n"
      "# Changes\n"
      "\n"
      "${pkg.githubReleaseNotes.defaultValue}";

  pkg.environmentConstants.fn = () {
    if (!Directory('build/language').existsSync()) {
      fail('Run `dart run grinder protobuf` before building Dart Sass '
          'executables.');
    }

    return {
      ...pkg.environmentConstants.defaultValue,
      "protocol-version": File('build/language/spec/EMBEDDED_PROTOCOL_VERSION')
          .readAsStringSync()
          .trim(),
      "compiler-version": pkg.pubspec.version!.toString(),
    };
  };

  pkg.addAllTasks();
  grind(args);
}

@DefaultTask('Compile async code and reformat.')
@Depends(format, synchronize)
void all() {}

@Task('Run the Dart formatter.')
void format() {
  run('dart',
      arguments: ['run', 'dart_style:format', '--overwrite', '--fix', '.']);
}

@Task('Installs dependencies from npm.')
void npmInstall() =>
    run(Platform.isWindows ? "npm.cmd" : "npm", arguments: ["install"]);

@Task('Runs the tasks that are required for running tests.')
@Depends(format, synchronize, protobuf, "pkg-npm-dev", npmInstall,
    "pkg-standalone-dev")
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
      late String included;
      try {
        included = File(p.join(p.dirname(path), p.fromUri(match[1])))
            .readAsStringSync();
      } catch (error) {
        _matchError(match, error.toString(), url: p.toUri(path));
      }

      late Match headerMatch;
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

/// Returns a map from JS type declaration file names to their contnets.
Map<String, String> _fetchJSTypes() {
  var languageRepo =
      cloneOrCheckout("https://github.com/sass/sass", "main", name: 'language');

  var typeRoot = p.join(languageRepo, 'js-api-doc');
  return {
    for (var entry in Directory(typeRoot).listSync(recursive: true))
      if (entry is File && entry.path.endsWith('.d.ts'))
        p.join('types', p.relative(entry.path, from: typeRoot)):
            entry.readAsStringSync()
  };
}

/// Throws a nice [SourceSpanException] associated with [match].
void _matchError(Match match, String message, {Object? url}) {
  var file = SourceFile.fromString(match.input, url: url);
  throw SourceSpanException(message, file.span(match.start, match.end));
}

@Task('Compile the protocol buffer definition to a Dart library.')
Future<void> protobuf() async {
  Directory('build').createSync(recursive: true);

  // Make sure we use the version of protoc_plugin defined by our pubspec,
  // rather than whatever version the developer might have globally installed.
  log("Writing protoc-gen-dart");
  if (Platform.isWindows) {
    File('build/protoc-gen-dart.bat').writeAsStringSync('''
@echo off
dart run protoc_plugin %*
''');
  } else {
    File('build/protoc-gen-dart').writeAsStringSync('''
#!/bin/sh
dart run protoc_plugin "\$@"
''');
    run('chmod', arguments: ['a+x', 'build/protoc-gen-dart']);
  }

  if (Platform.environment['UPDATE_SASS_PROTOCOL'] != 'false') {
    cloneOrCheckout("https://github.com/sass/sass.git", "main",
        name: 'language');
  }

  await runAsync("buf",
      arguments: ["generate"],
      runOptions: RunOptions(environment: {
        "PATH": 'build' +
            (Platform.isWindows ? ";" : ":") +
            Platform.environment["PATH"]!
      }));
}
