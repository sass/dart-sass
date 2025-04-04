// Copyright 2021 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:io';
import 'dart:convert';

import 'package:cli_pkg/cli_pkg.dart' as pkg;
import 'package:cli_util/cli_util.dart';
import 'package:grinder/grinder.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

import 'utils.dart';

/// The path in which pub expects to find its credentials file.
final String _pubCredentialsPath = p.join(
  applicationConfigHome('dart'),
  'pub-credentials.json',
);

@Task('Deploy pkg/sass_api to pub.')
Future<void> deploySassApi() async {
  // Write pub credentials
  Directory(p.dirname(_pubCredentialsPath)).createSync(recursive: true);
  File(_pubCredentialsPath).openSync(mode: FileMode.writeOnlyAppend)
    ..writeStringSync(pkg.pubCredentials.value)
    ..closeSync();

  var client = http.Client();
  var pubspecPath = "pkg/sass_api/pubspec.yaml";
  var pubspec = Pubspec.parse(
    File(pubspecPath).readAsStringSync(),
    sourceUrl: p.toUri(pubspecPath),
  );

  // Remove the dependency override on `sass`, because otherwise it will block
  // publishing.
  var pubspecYaml = Map<dynamic, dynamic>.of(
    loadYaml(File(pubspecPath).readAsStringSync()) as YamlMap,
  );
  pubspecYaml.remove("dependency_overrides");
  File(pubspecPath).writeAsStringSync(json.encode(pubspecYaml));

  // We use symlinks to avoid duplicating files between the main repo and
  // child repos, but `pub lish` doesn't resolve these before publishing so we
  // have to do so manually.
  for (var entry in Directory(
    "pkg/sass_api",
  ).listSync(recursive: true, followLinks: false)) {
    if (entry is! Link) continue;
    var target = p.join(p.dirname(entry.path), entry.targetSync());
    entry.deleteSync();
    File(entry.path).writeAsStringSync(File(target).readAsStringSync());
  }

  log("dart pub publish ${pubspec.name}");
  var process = await Process.start(
      p.join(sdkDir.path, "bin/dart"),
      [
        "pub",
        "publish",
        "--force",
      ],
      workingDirectory: "pkg/sass_api");
  LineSplitter().bind(utf8.decoder.bind(process.stdout)).listen(log);
  LineSplitter().bind(utf8.decoder.bind(process.stderr)).listen(log);
  if (await process.exitCode != 0) {
    fail("dart pub publish ${pubspec.name} failed");
  }

  // TODO(nweiz): Remove this when we use this tag to trigger the release
  // (blocked by dart-lang/pub-dev#8690).
  var response = await client.post(
    Uri.parse("https://api.github.com/repos/sass/dart-sass/git/refs"),
    headers: {
      "accept": "application/vnd.github.v3+json",
      "content-type": "application/json",
      "authorization": githubAuthorization,
    },
    body: jsonEncode({
      "ref": "refs/tags/${pubspec.name}/${pubspec.version}",
      "sha": Platform.environment["GITHUB_SHA"]!,
    }),
  );

  if (response.statusCode != 201) {
    fail("${response.statusCode} error creating tag:\n${response.body}");
  } else {
    log("Tagged ${pubspec.name} ${pubspec.version}.");
  }
}
