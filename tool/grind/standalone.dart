// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

import 'utils.dart';

/// Whether we're using a 64-bit Dart SDK.
bool get _is64Bit => Platform.version.contains("x64");

@Task('Build Dart script snapshot.')
snapshot() {
  ensureBuild();
  Dart.run('bin/sass.dart', vmArgs: ['--snapshot=build/sass.dart.snapshot']);
}

@Task('Build Dart application snapshot.')
appSnapshot() {
  ensureBuild();
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

/// Builds a standalone Sass package for the given [os] and architecture.
///
/// The [client] is used to download the corresponding Dart SDK.
Future _buildPackage(http.Client client, String os, {bool x64: true}) async {
  var architecture = x64 ? "x64" : "ia32";

  // TODO: Compile a single executable that embeds the Dart VM and the snapshot
  // when dart-lang/sdk#27596 is fixed.
  var channel = isDevSdk ? "dev" : "stable";
  var url = "https://storage.googleapis.com/dart-archive/channels/$channel/"
      "release/$dartVersion/sdk/dartsdk-$os-$architecture-release.zip";
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
    ..addFile(fileFromBytes(
        "dart-sass/src/dart${os == 'windows' ? '.exe' : ''}", executable,
        executable: true))
    ..addFile(
        file("dart-sass/src/DART_LICENSE", p.join(sdkDir.path, 'LICENSE')))
    ..addFile(file("dart-sass/src/sass.dart.snapshot", snapshot))
    ..addFile(file("dart-sass/src/SASS_LICENSE", "LICENSE"))
    ..addFile(fileFromString(
        "dart-sass/dart-sass${os == 'windows' ? '.bat' : ''}",
        readAndReplaceVersion(
            "package/dart-sass.${os == 'windows' ? 'bat' : 'sh'}"),
        executable: true))
    ..addFile(fileFromString("dart-sass/sass${os == 'windows' ? '.bat' : ''}",
        readAndReplaceVersion("package/sass.${os == 'windows' ? 'bat' : 'sh'}"),
        executable: true));

  var prefix = 'build/dart-sass-$version-$os-$architecture';
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
