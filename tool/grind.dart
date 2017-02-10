// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:grinder/grinder.dart';
import 'package:http/http.dart' as http;
import 'package:node_preamble/preamble.dart' as preamble;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart' as xml;
import 'package:yaml/yaml.dart';

/// The version of Dart Sass.
final String _version =
    loadYaml(new File('pubspec.yaml').readAsStringSync())['version'] as String;

/// The version of the current Dart executable.
final String _dartVersion = Platform.version.split(" ").first;

/// The root of the Dart SDK.
final _sdkDir = p.dirname(p.dirname(Platform.resolvedExecutable));

main(List<String> args) => grind(args);

@DefaultTask('Run the Dart formatter.')
format() {
  Pub.run('dart_style',
      script: 'format',
      arguments: ['--overwrite']
        ..addAll(existingSourceDirs.map((dir) => dir.path)));
}

@Task('Build Dart snapshot.')
snapshot() {
  _ensureBuild();
  Dart.run('bin/sass.dart', vmArgs: ['--snapshot=build/sass.dart.snapshot']);
}

@Task('Build standalone packages for all OSes.')
@Depends(snapshot)
package() async {
  var client = new http.Client();
  await _buildPackage(client, "linux", "x64");
  await _buildPackage(client, "linux", "ia32");
  await _buildPackage(client, "macos", "x64");
  await _buildPackage(client, "macos", "ia32");
  await _buildPackage(client, "windows", "x64");
  await _buildPackage(client, "windows", "ia32");
  client.close();
}

@Task('Compile to JS.')
js() {
  _ensureBuild();
  var destination = new File('build/sass.dart.js');
  Dart2js.compile(new File('bin/sass.dart'), outFile: destination, extraArgs: [
    '-Dnode=true',
    '-Dversion=$_version',
    '-Ddart-version=$_dartVersion',
  ]);
  var text = destination.readAsStringSync();
  destination.writeAsStringSync(preamble.getPreamble() + text);
}

@Task('Build a pure-JS npm package.')
@Depends(js)
npm_package() {
  var dir = new Directory('build/npm');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  log("copying package/package.json to build/npm");
  var json = JSON.decode(new File('package/package.json').readAsStringSync());
  json['version'] = _version;
  new File(p.join(dir.path, 'package.json'))
      .writeAsStringSync(JSON.encode(json));

  copy(new File(p.join('package', 'sass.js')), dir);
  copy(new File(p.join('build', 'sass.dart.js')), dir);
  copy(new File('README.md'), dir);
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
      builder.element("description",
          nest: """
**Sass makes CSS fun again**. Sass is an extension of CSS, adding nested rules, variables, mixins, selector inheritance, and more. It's translated to well-formatted, standard CSS using the command line tool or a web-framework plugin.

This package is Dart Sass, the new Dart implementation of Sass.
""");
      builder.element("summary", nest: "Sass makes CSS fun again.");
      builder.element("tags", nest: "css preprocessor style sass");
      builder.element("copyright",
          nest: "Copyright ${new DateTime.now().year} Google, Inc.");
      builder.element("dependencies", nest: () {
        builder.element("dependency", attributes: {
          "id": "dart-sdk",
          // Unfortunately we need the exact same Dart version as we built with,
          // since we ship a snapshot which isn't cross-version compatible. Once
          // we switch to native compilation this won't be an issue.
          "version": "[$_dartVersion]",
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

/// Builds a standalone Sass package for the given [os] and [architecture].
///
/// The [client] is used to download the corresponding Dart SDK.
Future _buildPackage(http.Client client, String os, String architecture) async {
  // TODO: Compile a single executable that embeds the Dart VM and the snapshot.
  var url = "https://storage.googleapis.com/dart-archive/channels/stable/"
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
  var executable = dartExecutable.content;
  var archive = new Archive()
    ..addFile(_fileFromBytes(
        "dart-sass/src/dart${os == 'windows' ? '.exe' : ''}", executable,
        executable: true))
    ..addFile(_file("dart-sass/src/DART_LICENSE", p.join(_sdkDir, 'LICENSE')))
    ..addFile(
        _file("dart-sass/src/sass.dart.snapshot", "build/sass.dart.snapshot"))
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
