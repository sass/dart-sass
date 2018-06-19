// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:path/path.dart' as p;

import 'npm.dart';
import 'standalone.dart';
import 'utils.dart';

@Task('Run benchmarks for Sass compilation speed.')
@Depends(snapshot, appSnapshot, npm_package)
benchmark() async {
  var libsass = await cloneOrPull('https://github.com/sass/libsass');
  var sassc = await cloneOrPull('https://github.com/sass/sassc');

  await runAsync("make",
      runOptions: new RunOptions(
          workingDirectory: sassc,
          environment: {"SASS_LIBSASS_PATH": p.absolute(libsass)}));
  log("");

  var ruby = await cloneOrPull('https://github.com/sass/ruby-sass');
  log("");

  await Dart.runAsync("benchmark/generate.dart");
  log("");

  var libsassRevision = await _revision(libsass);
  var sasscRevision = await _revision(sassc);
  var dartSassRevision = await _revision('.');
  var rubySassRevision = await _revision(ruby);
  var gPlusPlusVersion = await _version("g++");
  var nodeVersion = await _version("node");
  var rubyVersion = await _version("ruby");

  var perf = new File("perf.md").readAsStringSync();
  perf = perf
      .replaceFirst(new RegExp(r"This was tested against:\n\n[^]*?\n\n"), """
This was tested against:

* libsass $libsassRevision and sassc $sasscRevision compiled with $gPlusPlusVersion.
* Dart Sass $dartSassRevision on Dart $dartVersion and Node $nodeVersion.
* Ruby Sass $rubySassRevision on $rubyVersion.

""");

  var buffer = new StringBuffer("""
# Measurements

I ran five instances of each configuration and recorded the fastest time.

""");

  var benchmarks = [
    ["small_plain.scss", "Small Plain CSS", "4 instances of `.foo {a: b}`"],
    ["large_plain.scss", "Large Plain CSS", "2^17 instances of `.foo {a: b}`"],
    [
      "preceding_sparse_extend.scss",
      "Preceding Sparse `@extend`",
      "`.x {@extend .y}`, 2^17 instances of `.foo {a: b}`, and then `.y {a: b}`"
    ],
    [
      "following_sparse_extend.scss",
      "Following Sparse `@extend`",
      "`.y {a: b}`, 2^17 instances of `.foo {a: b}`, and then `.x {@extend .y}`"
    ],
    [
      "preceding_dense_extend.scss",
      "Preceding Dense `@extend`",
      "`.bar {@extend .foo}` followed by 2^17 instances of `.foo {a: b}`"
    ],
    [
      "following_dense_extend.scss",
      "Following Dense `@extend`",
      "2^17 instances of `.foo {a: b}` followed by `.bar {@extend .foo}`"
    ]
  ];

  for (var info in benchmarks) {
    var path = p.join('benchmark/source', info[0]);
    var title = info[1];
    var description = info[2];

    buffer.writeln("## $title");
    buffer.writeln();
    buffer.writeln("Running on a file containing $description:");
    buffer.writeln();

    var sasscTime = await _benchmark(p.join(sassc, 'bin', 'sassc'), [path]);
    buffer.writeln("* sassc: ${_formatTime(sasscTime)}");

    var scriptSnapshotTime = await _benchmark(
        Platform.executable, [p.join('build', 'sass.dart.snapshot'), path]);
    buffer.writeln("* Dart Sass from a script snapshot: "
        "${_formatTime(scriptSnapshotTime)}");

    var appSnapshotTime = await _benchmark(
        Platform.executable, [p.join('build', 'sass.dart.app.snapshot'), path]);
    buffer.writeln(
        "* Dart Sass from an app snapshot: ${_formatTime(appSnapshotTime)}");

    var nodeTime =
        await _benchmark("node", [p.join('build', 'npm', 'sass.js'), path]);
    buffer.writeln("* Dart Sass on Node.js: ${_formatTime(nodeTime)}");

    var rubyTime = await _benchmark(
        "ruby", [p.join('build', 'ruby-sass', 'bin', 'sass'), path]);
    buffer.writeln("* Ruby Sass with a hot cache: ${_formatTime(rubyTime)}");

    buffer.writeln();
    buffer.writeln('Based on these numbers, Dart Sass from an app snapshot is '
        'approximately:');
    buffer.writeln();
    buffer.writeln('* ${_compare(appSnapshotTime, sasscTime)} libsass');
    buffer
        .writeln('* ${_compare(appSnapshotTime, nodeTime)} Dart Sass on Node');
    buffer.writeln('* ${_compare(appSnapshotTime, rubyTime)} Ruby Sass');
    buffer.writeln();
    log('');
  }

  buffer.write("# Conclusions");
  perf = perf.replaceFirst(
      new RegExp(r"# Measurements\n[^]*# Prior Measurements"),
      buffer.toString());

  new File("perf.md").writeAsStringSync(perf);
}

/// Returns the revision of the Git repository at [path].
Future<String> _revision(String path) async => (await runAsync("git",
        arguments: ["rev-parse", "--short", "HEAD"],
        quiet: true,
        workingDirectory: path))
    .trim();

/// Returns the first line of output from `executable --version`.
Future<String> _version(String executable) async =>
    (await runAsync(executable, arguments: ["--version"], quiet: true))
        .split("\n")
        .first;

Future<Duration> _benchmark(String executable, List<String> arguments) async {
  log("$executable ${arguments.join(' ')}");

  // Run the benchmark once without recording output to give Ruby Sass a hot
  // cache and give other implementations a chance to warm up at the OS level.
  await _benchmarkOnce(executable, arguments);

  Duration lowest;
  for (var i = 0; i < 5; i++) {
    var duration = await _benchmarkOnce(executable, arguments);
    if (lowest == null || duration < lowest) lowest = duration;
  }
  return lowest;
}

Future<Duration> _benchmarkOnce(
    String executable, List<String> arguments) async {
  var result = await Process.run(
      "sh", ["-c", "time $executable ${arguments.join(' ')}"]);
  var match =
      new RegExp(r"(\d+)m(\d+)\.(\d+)s").firstMatch(result.stderr as String);
  return new Duration(
      minutes: int.parse(match[1]),
      seconds: int.parse(match[2]),
      milliseconds: int.parse(match[3]));
}

String _formatTime(Duration duration) =>
    "${duration.inSeconds}." +
    (duration.inMilliseconds % 1000).toString().padLeft(3, '0') +
    's';

/// Returns an approximate, human-readable comparison between [duration1] and
/// [duration2].
String _compare(Duration duration1, Duration duration2) {
  var faster = duration1 < duration2;
  var ratio = faster
      ? duration2.inMilliseconds / duration1.inMilliseconds
      : duration1.inMilliseconds / duration2.inMilliseconds;
  var rounded = (ratio * 10).round().toString();
  var humanRatio = '${rounded.substring(0, rounded.length - 1)}.' +
      '${rounded.substring(rounded.length - 1)}x';
  if (humanRatio == '1.0x') return 'identical to';

  return humanRatio + (faster ? ' faster than' : ' slower than');
}
