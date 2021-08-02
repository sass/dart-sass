// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';
import 'dart:convert';

import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:grinder/grinder.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

/// The path in which pub expects to find its credentials file.
final String _pubCredentialsPath = () {
  // This follows the same logic as pub:
  // https://github.com/dart-lang/pub/blob/d99b0d58f4059d7bb4ac4616fd3d54ec00a2b5d4/lib/src/system_cache.dart#L34-L43
  String cacheDir;
  var pubCache = Platform.environment['PUB_CACHE'];
  if (pubCache != null) {
    cacheDir = pubCache;
  } else if (Platform.isWindows) {
    var appData = Platform.environment['APPDATA']!;
    cacheDir = p.join(appData, 'Pub', 'Cache');
  } else {
    cacheDir = p.join(Platform.environment['HOME']!, '.pub-cache');
  }

  return p.join(cacheDir, 'credentials.json');
}();

/// Returns the HTTP basic authentication Authorization header from the
/// environment.
String get _githubAuthorization {
  var bearerToken = pkg.githubBearerToken.value;
  return bearerToken != null
      ? "Bearer $bearerToken"
      : "Basic " +
          base64.encode(utf8.encode("${pkg.githubUser}:${pkg.githubPassword}"));
}

@Task('Deploy sub-packages to pub.')
Future<void> deploySubPackages() async {
  // Write pub credentials
  Directory(p.dirname(_pubCredentialsPath)).createSync(recursive: true);
  File(_pubCredentialsPath).openSync(mode: FileMode.writeOnlyAppend)
    ..writeStringSync(pkg.pubCredentials.value)
    ..closeSync();

  var client = http.Client();
  for (var package in Directory("pkg").listSync().map((dir) => dir.path)) {
    var pubspecPath = "$package/pubspec.yaml";
    var pubspec = Pubspec.parse(
        File(pubspecPath).readAsStringSync(),
        sourceUrl: p.toUri(pubspecPath));

    // Remove the dependency override on `sass`, because otherwise it will block
    // publishing.
    var pubspecYaml = loadYaml(File(pubspecPath).readAsStringSync());
    pubspecYaml.remove("dependency_overrides");
    File(pubspecPath).writeAsStringSync(json.encode(pubspecYaml));

    log("pub publish ${pubspec.name}");
    var process = await Process.start(
        p.join(sdkDir.path, "bin/pub"), ["publish", "--force"],
        workingDirectory: package);
    LineSplitter().bind(utf8.decoder.bind(process.stdout)).listen(log);
    LineSplitter().bind(utf8.decoder.bind(process.stderr)).listen(log);
    if (await process.exitCode != 0) fail("pub publish ${pubspec.name} failed");

    var response = await client.post(
        Uri.parse("https://api.github.com/repos/sass/sass/git/refs"),
        headers: {
          "accept": "application/vnd.github.v3+json",
          "content-type": "application/json",
          "authorization": _githubAuthorization
        },
        body: jsonEncode({
          "ref": "refs/tags/${pubspec.name}/${pubspec.version}",
          "sha": Platform.environment["GITHUB_SHA"]!
        }));

    if (response.statusCode != 201) {
      fail("${response.statusCode} error creating tag:\n${response.body}");
    } else {
      log("Tagged ${pubspec.name} ${pubspec.version}.");
    }
  }
}
