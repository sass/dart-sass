// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:async';

import 'package:dart2_constant/convert.dart' as convert;

import 'package:test/test.dart';

/// Creates a directory in the system temp directory and returns its path.
Future<String> createTempDir() async => (await runHybridExpression(
    '(await Directory.systemTemp.createTemp("dart_sass_")).path')) as String;

/// Writes [text] to [path].
Future writeTextFile(String path, String text) => runHybridExpression(
    'new File(message[0]).writeAsString(message[1])', [path, text]);

/// Creates a directoy at [path].
Future createDirectory(String path) =>
    runHybridExpression('new Directory(message).create()', path);

/// Recursively deletes the directoy at [path].
Future deleteDirectory(String path) =>
    runHybridExpression('new Directory(message).delete(recursive: true)', path);

/// Runs [expression], which may be asynchronous, in a hybrid isolate.
///
/// Returns the result of [expression] if it's JSON-serializable.
Future runHybridExpression(String expression, [message]) async {
  var channel = spawnHybridCode('''
    import 'dart:async';
    import 'dart:io';

    import 'package:dart2_constant/convert.dart' as convert;

    import 'package:stream_channel/stream_channel.dart';

    hybridMain(StreamChannel channel, message) async {
      var result = await ${expression};
      channel.sink.add(_isJsonSafe(result) ? convert.json.encode(result) : 'null');
      channel.sink.close();
    }

    bool _isJsonSafe(object) {
      if (object == null) return true;
      if (object is String) return true;
      if (object is num) return true;
      if (object is bool) return true;
      if (object is List) return object.every(_isJsonSafe);
      if (object is Map) {
        return object.keys.every(_isJsonSafe) &&
            object.values.every(_isJsonSafe);
      }
      return false;
    }
  ''', message: message);

  return convert.json.decode((await channel.stream.first) as String);
}
