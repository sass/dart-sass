// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

import 'utils.dart';

/// Whether we're using a 64-bit Dart SDK.
bool get _is64Bit => Platform.version.contains("x64");

@Task('Build Dart script snapshot.')
void snapshot() {
  ensureBuild();
  Dart.run('bin/sass.dart',
      vmArgs: ['-Dversion=$version', '--snapshot=build/sass.dart.snapshot']);
}

@Task('Build a dev-mode Dart application snapshot.')
void appSnapshot() => _appSnapshot();

@Task('Build a native-code Dart executable.')
void nativeExecutable() {
  ensureBuild();
  run(p.join(sdkDir.path, 'bin/dart2native'), arguments: [
    '--output-kind=aot',
    'bin/sass.dart',
    '-Dversion=$version',
    '--output=build/sass.dart.native'
  ]);
}

/// Compiles Sass to an application snapshot.
void _appSnapshot() {
  ensureBuild();
  Dart.run('bin/sass.dart',
      arguments: ['tool/app-snapshot-input.scss'],
      vmArgs: [
        '--enable-asserts',
        '-Dversion=$version',
        '--snapshot=build/sass.dart.app.snapshot',
        '--snapshot-kind=app-jit'
      ],
      quiet: true);
}

@Task('Build standalone packages for Linux.')
@Depends(snapshot, nativeExecutable)
Future<void> packageLinux() => _buildPackage("linux");

@Task('Build standalone packages for Mac OS.')
@Depends(snapshot, nativeExecutable)
Future<void> packageMacOs() => _buildPackage("macos");

@Task('Build standalone packages for Windows.')
@Depends(snapshot, nativeExecutable)
Future<void> packageWindows() => _buildPackage("windows");

/// Builds standalone 32- and 64-bit Sass packages for the given [os].
Future<void> _buildPackage(String os) async {
  var client = http.Client();
  await Future.wait(["ia32", "x64"].map((architecture) async {
    // TODO: Compile a single executable that embeds the Dart VM and the
    // snapshot when dart-lang/sdk#27596 is fixed.
    var channel = isDevSdk ? "dev" : "stable";
    var url = "https://storage.googleapis.com/dart-archive/channels/$channel/"
        "release/$dartVersion/sdk/dartsdk-$os-$architecture-release.zip";
    log("Downloading $url...");
    var response = await client.get(Uri.parse(url));
    if (response.statusCode ~/ 100 != 2) {
      throw "Failed to download package: ${response.statusCode} "
          "${response.reasonPhrase}.";
    }

    // Use a native executable when packaging for the current operating system.
    //
    // We only use the native executable on 64-bit machines, because currently
    // only 64-bit Dart SDKs ship with dart2aot.
    //
    // TODO: Use a native executable everywhere when dart-lang/sdk#28617 is
    // fixed.
    var useNative =
        os == Platform.operatingSystem && architecture == "x64" && _is64Bit;

    var filename = "/bin/" +
        (useNative ? "dartaotruntime" : "dart") +
        (os == 'windows' ? '.exe' : '');
    var executable = ZipDecoder()
        .decodeBytes(response.bodyBytes)
        .firstWhere((file) => file.name.endsWith(filename))
        .content as List<int>;

    var archive = Archive()
      ..addFile(fileFromBytes(
          "dart-sass/src/dart${os == 'windows' ? '.exe' : ''}", executable,
          executable: true))
      ..addFile(
          file("dart-sass/src/DART_LICENSE", p.join(sdkDir.path, 'LICENSE')))
      ..addFile(file("dart-sass/src/sass.dart.snapshot",
          useNative ? "build/sass.dart.native" : "build/sass.dart.snapshot"))
      ..addFile(file("dart-sass/src/SASS_LICENSE", "LICENSE"))
      ..addFile(file("dart-sass/dart-sass${os == 'windows' ? '.bat' : ''}",
          "package/dart-sass.${os == 'windows' ? 'bat' : 'sh'}",
          executable: true))
      ..addFile(file("dart-sass/sass${os == 'windows' ? '.bat' : ''}",
          "package/sass.${os == 'windows' ? 'bat' : 'sh'}",
          executable: true));

    var prefix = 'build/dart-sass-$version-$os-$architecture';
    if (os == 'windows') {
      var output = "$prefix.zip";
      log("Creating $output...");
      File(output).writeAsBytesSync(ZipEncoder().encode(archive));
    } else {
      var output = "$prefix.tar.gz";
      log("Creating $output...");
      File(output)
          .writeAsBytesSync(GZipEncoder().encode(TarEncoder().encode(archive)));
    }
  }));
  await client.close();
}
