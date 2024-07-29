// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:cli_pkg/testing.dart' as pkg;
import 'package:test/test.dart';

import 'package:sass/src/embedded/embedded_sass.pb.dart';
import 'package:sass/src/embedded/utils.dart';
import 'package:sass/src/embedded/util/length_delimited_transformer.dart';

import 'utils.dart';

/// A wrapper for [Process] that provides a convenient API for testing the
/// embedded Sass process.
///
/// If the test fails, this will automatically print out any stderr and protocol
/// buffers from the process to aid debugging.
///
/// This API is based on the `test_process` package.
class EmbeddedProcess {
  /// The underlying process.
  final Process _process;

  /// A [StreamQueue] that emits each outbound protocol buffer from the process.
  ///
  /// The initial int is the compilation ID.
  StreamQueue<(int, OutboundMessage)> get outbound => _outbound;
  late StreamQueue<(int, OutboundMessage)> _outbound;

  /// A [StreamQueue] that emits each line of stderr from the process.
  StreamQueue<String> get stderr => _stderr;
  late StreamQueue<String> _stderr;

  /// A splitter that can emit new copies of [outbound].
  final StreamSplitter<(int, OutboundMessage)> _outboundSplitter;

  /// A splitter that can emit new copies of [stderr].
  final StreamSplitter<String> _stderrSplitter;

  /// A sink into which inbound messages can be passed to the process.
  ///
  /// The initial int is the compilation ID.
  final Sink<(int, InboundMessage)> inbound;

  /// The raw standard input byte sink.
  IOSink get stdin => _process.stdin;

  /// A log that includes lines from [stderr] and human-friendly serializations
  /// of protocol buffers from [outbound]
  final _log = <String>[];

  /// Whether [_log] has been passed to [printOnFailure] yet.
  var _loggedOutput = false;

  /// Returns a [Future] which completes to the exit code of the process, once
  /// it completes.
  Future<int> get exitCode => _process.exitCode;

  /// The process ID of the process.
  int get pid => _process.pid;

  /// Completes to [_process]'s exit code if it's exited, otherwise completes to
  /// `null` immediately.
  Future<int?> get _exitCodeOrNull async {
    var exitCode =
        await this.exitCode.timeout(Duration.zero, onTimeout: () => -1);
    return exitCode == -1 ? null : exitCode;
  }

  /// Starts a process.
  ///
  /// [executable], [workingDirectory], [environment],
  /// [includeParentEnvironment], and [runInShell] have the same meaning as for
  /// [Process.start].
  ///
  /// If [forwardOutput] is `true`, the process's [outbound] messages and
  /// [stderr] will be printed to the console as they appear. This is only
  /// intended to be set temporarily to help when debugging test failures.
  static Future<EmbeddedProcess> start(
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      bool forwardOutput = false}) async {
    var process = await Process.start(pkg.executableRunner("sass"),
        [...pkg.executableArgs("sass"), "--embedded"],
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: runInShell);

    return EmbeddedProcess._(process, forwardOutput: forwardOutput);
  }

  /// Creates a [EmbeddedProcess] for [process].
  ///
  /// The [forwardOutput] argument is the same as that to [start].
  EmbeddedProcess._(Process process, {bool forwardOutput = false})
      : _process = process,
        _outboundSplitter = StreamSplitter(
            process.stdout.transform(lengthDelimitedDecoder).map((packet) {
          var (compilationId, buffer) = parsePacket(packet);
          return (compilationId, OutboundMessage.fromBuffer(buffer));
        })),
        _stderrSplitter = StreamSplitter(process.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())),
        inbound = StreamSinkTransformer<(int, InboundMessage),
            List<int>>.fromHandlers(handleData: (pair, sink) {
          var (compilationId, message) = pair;
          sink.add(serializePacket(compilationId, message));
        }).bind(
            StreamSinkTransformer.fromStreamTransformer(lengthDelimitedEncoder)
                .bind(process.stdin)) {
    addTearDown(_tearDown);
    expect(_process.exitCode.then((_) => _logOutput()), completes,
        reason: "Process `sass --embedded` never exited.");

    _outbound = StreamQueue(_outboundSplitter.split());
    _stderr = StreamQueue(_stderrSplitter.split());

    _outboundSplitter.split().listen((pair) {
      for (var line in pair.$2.toDebugString().split("\n")) {
        if (forwardOutput) print(line);
        _log.add("    $line");
      }
    });

    _stderrSplitter.split().listen((line) {
      if (forwardOutput) print(line);
      _log.add("[e] $line");
    });
  }

  /// A callback that's run when the test completes.
  Future<void> _tearDown() async {
    // If the process is already dead, do nothing.
    if (await _exitCodeOrNull != null) return;

    _process.kill(ProcessSignal.sigkill);

    // Log output now rather than waiting for the exitCode callback so that
    // it's visible even if we time out waiting for the process to die.
    await _logOutput();
  }

  /// Formats the contents of [_log] and passes them to [printOnFailure].
  Future<void> _logOutput() async {
    if (_loggedOutput) return;
    _loggedOutput = true;

    var exitCodeOrNull = await _exitCodeOrNull;

    // Wait a timer tick to ensure that all available lines have been flushed to
    // [_log].
    await Future<void>.delayed(Duration.zero);

    var buffer = StringBuffer();
    buffer.write("Process `dart_sass_embedded` ");
    if (exitCodeOrNull == null) {
      buffer.write("was killed with SIGKILL in a tear-down.");
    } else {
      buffer.write("exited with exitCode $exitCodeOrNull.");
    }
    buffer.writeln(" Output:");
    buffer.writeln(_log.join("\n"));

    printOnFailure(buffer.toString());
  }

  /// Sends [message] to the process with the default compilation ID.
  void send(InboundMessage message) =>
      inbound.add((defaultCompilationId, message));

  /// Fetches the next message from [outbound] and asserts that it has the
  /// default compilation ID.
  Future<OutboundMessage> receive() async {
    var (actualCompilationId, message) = await outbound.next;
    expect(actualCompilationId, equals(defaultCompilationId),
        reason: "Expected default compilation ID");
    return message;
  }

  /// Closes the process's stdin and waits for it to exit gracefully.
  Future<void> close() async {
    stdin.close();
    await shouldExit(0);
  }

  /// Kills the process (with SIGKILL on POSIX operating systems), and returns a
  /// future that completes once it's dead.
  ///
  /// If this is called after the process is already dead, it does nothing.
  Future<void> kill() async {
    _process.kill(ProcessSignal.sigkill);
    await exitCode;
  }

  /// Waits for the process to exit, and verifies that the exit code matches
  /// [expectedExitCode] (if given).
  ///
  /// If this is called after the process is already dead, it verifies its
  /// existing exit code.
  Future<void> shouldExit([int? expectedExitCode]) async {
    var exitCode = await this.exitCode;
    if (expectedExitCode == null) return;
    expect(exitCode, expectedExitCode,
        reason: "Process `dart_sass_embedded` had an unexpected exit code.");
  }
}
