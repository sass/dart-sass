// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:grinder/grinder.dart';
import 'package:http/http.dart' as http;
import 'package:node_preamble/preamble.dart' as preamble;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The version of Dart Sass.
final String _version =
    loadYaml(new File('pubspec.yaml').readAsStringSync())['version'];

/// The version of the current Dart executable.
final String _dartVersion = Platform.version.split(" ").first;

/// The root of the Dart SDK.
final _sdkDir = p.dirname(p.dirname(Platform.resolvedExecutable));

main(args) => grind(args);

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
  destination.writeAsStringSync("""
    ${preamble.getPreamble()}
    global.exports = exports;
    $text
  """);
}

@Task('Build a pure-JS npm package.')
@Depends(js)
npm_package() {
  var dir = new Directory('build/npm');
  dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  log("copying package/package.json to build/npm");
  var json = JSON.decode(new File('package/package.json').readAsStringSync());
  json['version'] = _version;
  new File(p.join(dir.path, 'package.json'))
      .writeAsStringSync(JSON.encode(json));

  copy(new File('package/sass.js'), dir);
  copy(new File('build/sass.dart.js'), dir);
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
  var snapshot = new File('build/sass.dart.snapshot').readAsBytesSync();
  var sassLicense = new File('LICENSE').readAsBytesSync();
  var dartLicense = new File(p.join(_sdkDir, 'LICENSE')).readAsBytesSync();
  var archive = new Archive()
    ..addFile(_file("dart-sass/src/dart", executable, executable: true))
    ..addFile(_file("dart-sass/src/DART_LICENSE", dartLicense))
    ..addFile(_file("dart-sass/src/sass.dart.snapshot", snapshot))
    ..addFile(_file("dart-sass/src/SASS_LICENSE", sassLicense))
    ..addFile(_scriptFor(os));

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

/// Returns a shell script archive file for the given [os].
ArchiveFile _scriptFor(String os) {
  var contents = new File("package/dart-sass.${os == 'windows' ? 'bat' : 'sh'}")
      .readAsStringSync()
      .replaceAll("SASS_VERSION", _version);
  var bytes = UTF8.encode(contents);
  return _file("dart-sass/dart-sass${os == 'windows' ? '.bat' : ''}", bytes,
      executable: true);
}

/// Creates an [ArchiveFile] with the given [path] and [data].
///
/// If [executable] is `true`, this marks the file as executable.
ArchiveFile _file(String path, List<int> data, {bool executable: false}) =>
    new ArchiveFile(path, data.length, data)
      ..mode = executable ? 495 : 428
      ..lastModTime = new DateTime.now().millisecondsSinceEpoch ~/ 1000;
