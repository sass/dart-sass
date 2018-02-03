// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:charcode/charcode.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:grinder/grinder.dart';
import 'package:http/http.dart' as http;
import 'package:node_preamble/preamble.dart' as preamble;
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';
import 'package:xml/xml.dart' as xml;
import 'package:yaml/yaml.dart';

import 'package:sass/src/util/path.dart';

import 'synchronize.dart';

export 'synchronize.dart';

/// The version of Dart Sass.
final String _version =
    loadYaml(new File('pubspec.yaml').readAsStringSync())['version'] as String;

/// The version of the current Dart executable.
final Version _dartVersion =
    new Version.parse(Platform.version.split(" ").first);

/// Whether we're using a dev Dart SDK.
bool get _isDevSdk => _dartVersion.isPreRelease;

/// The root of the Dart SDK.
final _sdkDir = p.dirname(p.dirname(Platform.resolvedExecutable));

/// Whether we're using a 64-bit Dart SDK.
bool get _is64Bit => Platform.version.contains("x64");

main(List<String> args) => grind(args);

@DefaultTask('Compile async code and reformat.')
@Depends(format, synchronize)
all() {}

@Task('Run the Dart formatter.')
format() {
  Pub.run('dart_style',
      script: 'format',
      arguments: ['--overwrite']
        ..addAll(existingSourceDirs.map((dir) => dir.path)));
}

@Task('Build Dart script snapshot.')
snapshot() {
  _ensureBuild();
  Dart.run('bin/sass.dart', vmArgs: ['--snapshot=build/sass.dart.snapshot']);
}

@Task('Build Dart application snapshot.')
appSnapshot() {
  _ensureBuild();
  Dart.run('bin/sass.dart',
      arguments: ['tool/app-snapshot-input.scss'],
      vmArgs: [
        '--snapshot=build/sass.dart.app.snapshot',
        '--snapshot-kind=app-jit'
      ],
      quiet: true);
}

@Task('Build standalone packages for all OSes.')
@Depends(snapshot, appSnapshot)
package() async {
  var client = new http.Client();
  await Future.wait(["linux", "macos", "windows"].expand((os) => [
        _buildPackage(client, os, x64: true),
        _buildPackage(client, os, x64: false)
      ]));
  client.close();
}

@Task('Compile to JS.')
js() {
  _ensureBuild();
  var destination = new File('build/sass.dart.js');

  var args = [
    '--trust-type-annotations',
    '-Dnode=true',
    '-Dversion=$_version',
    '-Ddart-version=$_dartVersion',
  ];
  if (Platform.environment["SASS_MINIFY_JS"] != "false") args.add("--minify");

  Dart2js.compile(new File('bin/sass.dart'),
      outFile: destination, extraArgs: args);
  var text = destination.readAsStringSync();
  destination.writeAsStringSync(preamble.getPreamble() + text);
}

@Task('Build a pure-JS npm package.')
@Depends(js)
npm_package() {
  var json = JSON.decode(new File('package/package.json').readAsStringSync())
      as Map<String, dynamic>;
  json['version'] = _version;

  _writeNpmPackage('build/npm', json);
  _writeNpmPackage('build/npm-old', json..addAll({"name": "dart-sass"}));
}

@Task('Installs dependencies from npm.')
npm_install() => run("npm", arguments: ["install"]);

@Task('Runs the tasks that are required for running tests.')
@Depends(npm_package, npm_install)
before_test() {}

/// Writes a Dart Sass NPM package to the directory at [destination].
///
/// The [json] will be used as the package's package.json.
void _writeNpmPackage(String destination, Map<String, dynamic> json) {
  var dir = new Directory(destination);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  log("copying package/package.json to $destination");
  new File(p.join(destination, 'package.json'))
      .writeAsStringSync(JSON.encode(json));

  copy(new File(p.join('package', 'sass.js')), dir);
  copy(new File(p.join('build', 'sass.dart.js')), dir);

  log("copying package/README.npm.md to $destination");
  new File(p.join(destination, 'README.md'))
      .writeAsStringSync(_readAndResolveMarkdown('package/README.npm.md'));
}

final _readAndResolveRegExp = new RegExp(
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
String _readAndResolveMarkdown(String path) => new File(path)
        .readAsStringSync()
        .replaceAllMapped(_readAndResolveRegExp, (match) {
      String included;
      try {
        included = new File(p.join(p.dirname(path), p.fromUri(match[1])))
            .readAsStringSync();
      } catch (error) {
        _matchError(match, error.toString(), url: p.toUri(path));
      }

      Match headerMatch;
      try {
        headerMatch = "# ${match[2]}\n".allMatches(included).first;
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
void _matchError(Match match, String message, {url}) {
  var file = new SourceFile.fromString(match.input, url: url);
  throw new SourceSpanException(message, file.span(match.start, match.end));
}

@Task('Build a Chocolatey package.')
@Depends(snapshot)
chocolatey_package() {
  _ensureBuild();

  var nuspec = _nuspec();
  var archive = new Archive()
    ..addFile(_fileFromString("sass.nuspec", nuspec.toString()))
    ..addFile(
        _file("[Content_Types].xml", "package/chocolatey/[Content_Types].xml"))
    ..addFile(_file("_rels/.rels", "package/chocolatey/rels.xml"))
    ..addFile(_fileFromString(
        "package/services/metadata/core-properties/properties.psmdcp",
        _nupkgProperties(nuspec)))
    ..addFile(_file("tools/LICENSE", "LICENSE"))
    ..addFile(_file("tools/sass.dart.snapshot", "build/sass.dart.snapshot"))
    ..addFile(_file("tools/chocolateyInstall.ps1",
        "package/chocolatey/chocolateyInstall.ps1"))
    ..addFile(_file("tools/chocolateyUninstall.ps1",
        "package/chocolatey/chocolateyUninstall.ps1"))
    ..addFile(_fileFromString("tools/sass.bat",
        _readAndReplaceVersion("package/chocolatey/sass.bat")));

  var output = "build/sass.${_chocolateyVersion()}.nupkg";
  log("Creating $output...");
  new File(output).writeAsBytesSync(new ZipEncoder().encode(archive));
}

/// Creates a `sass.nuspec` file's contents.
xml.XmlDocument _nuspec() {
  String sdkVersion;
  if (_isDevSdk) {
    assert(_dartVersion.preRelease[0] == "dev");
    assert(_dartVersion.preRelease[1] is int);
    sdkVersion = "${_dartVersion.major}.${_dartVersion.minor}."
        "${_dartVersion.patch}.${_dartVersion.preRelease[1]}";
  } else {
    sdkVersion = _dartVersion.toString();
  }

  var builder = new xml.XmlBuilder();
  builder.processing("xml", 'version="1.0"');
  builder.element("package", nest: () {
    builder
        .namespace("http://schemas.microsoft.com/packaging/2011/10/nuspec.xsd");
    builder.element("metadata", nest: () {
      builder.element("id", nest: "sass");
      builder.element("title", nest: "Sass");
      builder.element("version", nest: _chocolateyVersion());
      builder.element("authors", nest: "Natalie Weizenbaum");
      builder.element("owners", nest: "nex3");
      builder.element("projectUrl", nest: "https://github.com/sass/dart-sass");
      builder.element("licenseUrl",
          nest: "https://github.com/sass/dart-sass/blob/$_version/LICENSE");
      builder.element("iconUrl",
          nest: "https://cdn.rawgit.com/sass/sass-site/"
              "f99ee33e4f688e244c7a5902c59d61f78daccc55/source/assets/img/"
              "logos/logo-seal.png");
      builder.element("bugTrackerUrl",
          nest: "https://github.com/sass/dart-sass/issues");
      builder.element("description", nest: """
**Sass makes CSS fun again**. Sass is an extension of CSS, adding nested rules, variables, mixins, selector inheritance, and more. It's translated to well-formatted, standard CSS using the command line tool or a web-framework plugin.

This package is Dart Sass, the new Dart implementation of Sass.
""");
      builder.element("summary", nest: "Sass makes CSS fun again.");
      builder.element("tags", nest: "css preprocessor style sass");
      builder.element("copyright",
          nest: "Copyright ${new DateTime.now().year} Google, Inc.");
      builder.element("dependencies", nest: () {
        builder.element("dependency", attributes: {
          "id": _isDevSdk ? "dart-sdk-dev" : "dart-sdk",
          // Unfortunately we need the exact same Dart version as we built with,
          // since we ship a snapshot which isn't cross-version compatible. Once
          // we switch to native compilation this won't be an issue.
          "version": "[$sdkVersion]",
        });
      });
    });
  });

  return builder.build() as xml.XmlDocument;
}

/// The current Sass version, formatted for Chocolatey which doesn't allow dots
/// in prerelease versions.
String _chocolateyVersion() {
  var components = _version.split("-");
  if (components.length == 1) return components.first;
  assert(components.length == 2);
  return "${components.first}-${components.last.replaceAll('.', '')}";
}

/// Returns the contents of the `properties.psmdcp` file, computed from the
/// nuspec's XML.
String _nupkgProperties(xml.XmlDocument nuspec) {
  var builder = new xml.XmlBuilder();
  builder.processing("xml", 'version="1.0"');
  builder.element("coreProperties", nest: () {
    builder.namespace(
        "http://schemas.openxmlformats.org/package/2006/metadata/core-properties");
    builder.namespace("http://purl.org/dc/elements/1.1/", "dc");
    builder.element("dc:creator",
        nest: nuspec.findAllElements("authors").first.text);
    builder.element("dc:description",
        nest: nuspec.findAllElements("description").first.text);
    builder.element("dc:identifier",
        nest: nuspec.findAllElements("id").first.text);
    builder.element("version",
        nest: nuspec.findAllElements("version").first.text);
    builder.element("keywords",
        nest: nuspec.findAllElements("tags").first.text);
    builder.element("dc:title",
        nest: nuspec.findAllElements("title").first.text);
  });
  return builder.build().toString();
}

/// Ensure that the `build/` directory exists.
void _ensureBuild() {
  new Directory('build').createSync(recursive: true);
}

/// Builds a standalone Sass package for the given [os] and architecture.
///
/// The [client] is used to download the corresponding Dart SDK.
Future _buildPackage(http.Client client, String os, {bool x64: true}) async {
  var architecture = x64 ? "x64" : "ia32";

  // TODO: Compile a single executable that embeds the Dart VM and the snapshot
  // when dart-lang/sdk#27596 is fixed.
  var channel = _isDevSdk ? "dev" : "stable";
  var url = "https://storage.googleapis.com/dart-archive/channels/$channel/"
      "release/$_dartVersion/sdk/dartsdk-$os-$architecture-release.zip";
  log("Downloading $url...");
  var response = await client.get(Uri.parse(url));
  if (response.statusCode ~/ 100 != 2) {
    throw "Failed to download package: ${response.statusCode} "
        "${response.reasonPhrase}.";
  }

  var dartExecutable = new ZipDecoder()
      .decodeBytes(response.bodyBytes)
      .firstWhere((file) => os == 'windows'
          ? file.name.endsWith("/bin/dart.exe")
          : file.name.endsWith("/bin/dart"));
  var executable = DelegatingList.typed<int>(dartExecutable.content as List);

  // Use the app snapshot when packaging for the current operating system.
  //
  // TODO: Use an app snapshot everywhere when dart-lang/sdk#28617 is fixed.
  var snapshot = os == Platform.operatingSystem && x64 == _is64Bit
      ? "build/sass.dart.app.snapshot"
      : "build/sass.dart.snapshot";

  var archive = new Archive()
    ..addFile(_fileFromBytes(
        "dart-sass/src/dart${os == 'windows' ? '.exe' : ''}", executable,
        executable: true))
    ..addFile(_file("dart-sass/src/DART_LICENSE", p.join(_sdkDir, 'LICENSE')))
    ..addFile(_file("dart-sass/src/sass.dart.snapshot", snapshot))
    ..addFile(_file("dart-sass/src/SASS_LICENSE", "LICENSE"))
    ..addFile(_fileFromString(
        "dart-sass/dart-sass${os == 'windows' ? '.bat' : ''}",
        _readAndReplaceVersion(
            "package/dart-sass.${os == 'windows' ? 'bat' : 'sh'}"),
        executable: true));

  var prefix = 'build/dart-sass-$_version-$os-$architecture';
  if (os == 'windows') {
    var output = "$prefix.zip";
    log("Creating $output...");
    new File(output).writeAsBytesSync(new ZipEncoder().encode(archive));
  } else {
    var output = "$prefix.tar.gz";
    log("Creating $output...");
    new File(output).writeAsBytesSync(
        new GZipEncoder().encode(new TarEncoder().encode(archive)));
  }
}

/// Reads [file], replaces all instances of SASS_VERSION with the actual
/// version, and returns its contents.
String _readAndReplaceVersion(String file) =>
    new File(file).readAsStringSync().replaceAll("SASS_VERSION", _version);

/// Creates an [ArchiveFile] with the given [path] and [data].
///
/// If [executable] is `true`, this marks the file as executable.
ArchiveFile _fileFromBytes(String path, List<int> data,
        {bool executable: false}) =>
    new ArchiveFile(path, data.length, data)
      ..mode = executable ? 495 : 428
      ..lastModTime = new DateTime.now().millisecondsSinceEpoch ~/ 1000;

/// Creates a UTF-8-encoded [ArchiveFile] with the given [path] and [contents].
///
/// If [executable] is `true`, this marks the file as executable.
ArchiveFile _fileFromString(String path, String contents,
        {bool executable: false}) =>
    _fileFromBytes(path, UTF8.encode(contents), executable: executable);

/// Creates an [ArchiveFile] at the archive path [target] from the local file at
/// [source].
///
/// If [executable] is `true`, this marks the file as executable.
ArchiveFile _file(String target, String source, {bool executable: false}) =>
    _fileFromBytes(target, new File(source).readAsBytesSync(),
        executable: executable);

/// A regular expression for locating the URL and SHA256 hash of the Sass
/// archive in the `homebrew-sass` formula.
final _homebrewRegExp = new RegExp(r'\n( *)url "[^"]+"'
    r'\n *sha256 "[^"]+"');

@Task('Update the Homebrew formula for the current version.')
update_homebrew() async {
  _ensureBuild();

  var process = await Process.start("git", [
    "archive",
    "--prefix=dart-sass-$_version/",
    "--format=tar.gz",
    _version
  ]);
  var digest = await sha256.bind(process.stdout).first;
  var stderr = await UTF8.decodeStream(process.stderr);
  if ((await process.exitCode) != 0) {
    fail('git archive "$_version" failed:\n$stderr');
  }

  if (new Directory("build/homebrew-sass/.git").existsSync()) {
    await runAsync("git",
        arguments: ["fetch", "origin"],
        workingDirectory: "build/homebrew-sass");
    await runAsync("git",
        arguments: ["reset", "--hard", "origin/master"],
        workingDirectory: "build/homebrew-sass");
  } else {
    delete(new Directory("build/homebrew-sass"));
    await runAsync("git", arguments: [
      "clone",
      "git@github.com:sass/homebrew-sass.git",
      "build/homebrew-sass"
    ]);
  }

  var formula = new File("build/homebrew-sass/sass.rb");
  log("updating ${formula.path}");
  formula.writeAsStringSync(formula.readAsStringSync().replaceFirstMapped(
      _homebrewRegExp,
      (match) =>
          '\n${match[1]}url "https://github.com/sass/dart-sass/archive/$_version.tar.gz"'
          '\n${match[1]}sha256 "$digest"'));

  run("git",
      arguments: [
        "commit",
        "--all",
        "--message",
        "Update Dart Sass to $_version"
      ],
      workingDirectory: "build/homebrew-sass");

  await runAsync("git",
      arguments: ["push"], workingDirectory: "build/homebrew-sass");
}
