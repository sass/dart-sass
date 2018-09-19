// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:grinder/grinder.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

import 'utils.dart';

/// Whether we're using a 64-bit Dart SDK.
bool get _is64Bit => Platform.version.contains("x64");

@Task('Build Dart script snapshot.')
snapshot() {
  ensureBuild();
  Dart.run('bin/sass.dart',
      vmArgs: ['--no-preview-dart-2', '--snapshot=build/sass.dart.snapshot']);
}

@Task('Build Dart 2 script snapshot.')
snapshotDart2() {
  ensureBuild();
  Dart.run('bin/sass.dart',
      vmArgs: ['--snapshot=build/sass.dart.dart2.snapshot']);
}

@Task('Build a dev-mode Dart application snapshot.')
appSnapshot() => _appSnapshot(release: false);

// Don't build in Dart 2 runtime mode for now because it's substantially slower
// than Dart 1 mode. See dart-lang/sdk#33257.
@Task('Build a release-mode Dart application snapshot.')
releaseAppSnapshot() => _appSnapshot(release: true);

@Task('Build a release-mode Dart 2 application snapshot.')
releaseDart2AppSnapshot() => _appSnapshot(release: true, dart2: true);

/// Compiles Sass to an application snapshot.
///
/// If [release] is `true`, this compiles in checked mode. Otherwise, it
/// compiles in unchecked mode. If [dart2] is `true`, this compiles in Dart 2
/// mode. Otherwise, it compiles in Dart 1 mode.
void _appSnapshot({@required bool release, bool dart2: false}) {
  var args = [
    '--snapshot=build/sass.dart.app${dart2 ? '.dart2' : ''}.snapshot',
    '--snapshot-kind=app-jit'
  ];

  if (!dart2) args.add('--no-preview-dart-2');

  if (!release) {
    if (dart2) {
      args.add('--enable-asserts');
    } else {
      args.add('--checked');
    }
  }

  ensureBuild();
  Dart.run('bin/sass.dart',
      arguments: ['tool/app-snapshot-input.scss'], vmArgs: args, quiet: true);
}

@Task('Build standalone packages for all OSes.')
@Depends(snapshot, releaseAppSnapshot)
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
  var executable = dartExecutable.content as List<int>;

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
