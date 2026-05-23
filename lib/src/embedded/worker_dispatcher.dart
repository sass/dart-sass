// Copyright 2023 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';
import 'dart:io' if (dart.library.js) 'js/io.dart';
import 'dart:typed_data';

import 'package:pool/pool.dart';
import 'package:protobuf/protobuf.dart';
import 'package:stream_channel/stream_channel.dart';

import 'embedded_sass.pb.dart';
import 'util/proto_extensions.dart';
import 'utils.dart';
import 'vm/concurrency.dart' if (dart.library.js) 'js/concurrency.dart';
import 'vm/reusable_worker.dart' if (dart.library.js) 'js/reusable_worker.dart';

/// A class that dispatches messages between the host and various workers that
/// are each running an individual compilation.
class WorkerDispatcher {
  /// The channel of encoded protocol buffers, connected to the host.
  final StreamChannel<Uint8List> _channel;

  /// Whether to wait for all worker workers to exit before exiting the main
  /// worker or not.
  final bool _gracefulWorkerShutdown;

  /// All workers that have been spawned to dispatch to.
  ///
  /// Only used for cleaning up the process when the underlying channel closes.
  final _allWorkers = StreamController<ReusableWorker>(sync: true);

  /// The workers that aren't currently running compilations
  final _inactiveWorkers = <ReusableWorker>{};

  /// A map from active compilationIds to workers running those compilations.
  final _activeWorkers = <int, Future<ReusableWorker>>{};

  /// A pool controlling how many workers (and thus concurrent compilations)
  /// may be live at once.
  final _workerPool = Pool(concurrencyLimit);

  /// Whether [_channel] has been closed or not.
  var _closed = false;

  WorkerDispatcher(this._channel, {bool gracefulWorkerShutdown = true})
      : _gracefulWorkerShutdown = gracefulWorkerShutdown;

  void listen() {
    _channel.stream.listen(
      (packet) async {
        int? compilationId;
        InboundMessage? message;
        try {
          Uint8List messageBuffer;
          (compilationId, messageBuffer) = parsePacket(packet);

          if (compilationId != 0) {
            var worker = await _activeWorkers.putIfAbsent(
              compilationId,
              () => _getWorker(compilationId!),
            );

            // The shutdown may have started by the time the worker is spawned
            if (_closed) return;

            try {
              worker.send(packet);
              return;
            } on StateError catch (_) {
              throw paramsError(
                "Received multiple messages for compilation ID $compilationId",
              );
            }
          }

          try {
            message = InboundMessage.fromBuffer(messageBuffer);
          } on InvalidProtocolBufferException catch (error) {
            throw parseError(error.message);
          }

          if (message.whichMessage() case var type
              when type != InboundMessage_Message.versionRequest) {
            throw paramsError(
              "Only VersionRequest may have wire ID 0, was $type.",
            );
          }

          var request = message.versionRequest;
          var response = versionResponse();
          response.id = request.id;
          _send(0, OutboundMessage()..versionResponse = response);
        } catch (error, stackTrace) {
          _handleError(
            error,
            stackTrace,
            compilationId: compilationId,
            messageId: message?.id,
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _handleError(error, stackTrace);
      },
      onDone: () {
        if (_gracefulWorkerShutdown) {
          _closed = true;
          _allWorkers.stream.listen((worker) => worker.kill());
        } else {
          exit(exitCode);
        }
      },
    );
  }

  /// Returns an worker that's ready to run a new compilation.
  ///
  /// This re-uses an existing worker if possible, and spawns a new one
  /// otherwise.
  Future<ReusableWorker> _getWorker(int compilationId) async {
    var resource = await _workerPool.request();
    ReusableWorker worker;
    if (_inactiveWorkers.isNotEmpty) {
      worker = _inactiveWorkers.first;
      _inactiveWorkers.remove(worker);
    } else {
      var future = ReusableWorker.spawn(
        onError: (Object error, StackTrace stackTrace) {
          _handleError(error, stackTrace);
        },
      );
      worker = await future;
      _allWorkers.add(worker);
    }

    worker.borrow((message) {
      var fullBuffer = message as Uint8List;

      // The first byte of messages from workers indicates whether the entire
      // compilation is finished (1) or if it encountered an error (2). Sending
      // this as part of the message buffer rather than a separate message
      // avoids a race condition where the host might send a new compilation
      // request with the same ID as one that just finished before the
      // [WorkerDispatcher] receives word that the worker with that ID is done.
      // See sass/dart-sass#2004.
      var category = fullBuffer[0];
      var packet = Uint8List.sublistView(fullBuffer, 2);

      switch (category) {
        case 0:
          _channel.sink.add(packet);
        case 1:
          _activeWorkers.remove(compilationId);
          worker.release();
          _inactiveWorkers.add(worker);
          resource.release();
          _channel.sink.add(packet);
        case 2:
          _channel.sink.add(packet);
          // The second byte of message is the exitCode when fatal error
          // occurs. This is needed because in Node.js process.exitCode
          // is thread local, so that we need to pass it from the worker
          // thread back to main thread. Using onexit event to retrieve
          // the exitCode is unrelibale because worker.kill() might get
          // triggered from main thread before the worker thread finish
          // exit itself, in which case onexit event will recevie an exit
          // code 1 regardless of actual process.exitCode value in worker
          // thread.
          exitCode = fullBuffer[1];
          _exit();
      }
    });

    return worker;
  }

  /// Creates a [OutboundMessage_VersionResponse]
  static OutboundMessage_VersionResponse versionResponse() {
    return OutboundMessage_VersionResponse()
      ..protocolVersion = const String.fromEnvironment("protocol-version")
      ..compilerVersion = const String.fromEnvironment("compiler-version")
      ..implementationVersion = const String.fromEnvironment("compiler-version")
      ..implementationName = "dart-sass";
  }

  /// Handles an error thrown by the dispatcher or code it dispatches to.
  ///
  /// The [compilationId] and [messageId] indicate the IDs of the message being
  /// responded to, if available.
  void _handleError(
    Object error,
    StackTrace stackTrace, {
    int? compilationId,
    int? messageId,
  }) {
    sendError(
      compilationId ?? errorId,
      handleError(error, stackTrace, messageId: messageId),
    );
    _exit();
  }

  /// Exits the current process.
  ///
  /// For Dart VM process it exits immediately. For Node.js process, it waits
  /// for all worker threads to shutdown before exits the main thread, to ensure
  /// the exit code from the worker thread is propagated back to the main thread
  /// before exiting.
  void _exit() {
    if (_gracefulWorkerShutdown) {
      _channel.sink.close();
    } else {
      exit(exitCode);
    }
  }

  /// Sends [message] to the host.
  void _send(int compilationId, OutboundMessage message) =>
      _channel.sink.add(serializePacket(compilationId, message));

  /// Sends [error] to the host.
  void sendError(int compilationId, ProtocolError error) =>
      _send(compilationId, OutboundMessage()..error = error);
}
