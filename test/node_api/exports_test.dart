// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

@TestOn('node')
@Tags(['node'])

import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:sass/src/node/promise.dart';
import 'package:test/test.dart';

import '../ensure_npm_package.dart';
import 'api.dart';
import 'utils.dart';

/// Describes a JavaScript object.
///
/// Object's always have a `constructor` property in JavaScript.
@JS()
class ObjectWithConstructor {
  Object constructor;
}

void main() {
  setUpAll(ensureNpmPackage);
  useSandbox();

  group('run_ method', () {
    test('returns a JavaScript native Promise', () async {
      var result = sass.run_([]) as ObjectWithConstructor;
      expect(result, isA<Promise<void>>());
      expect(result.constructor.toString(), contains('[native code]'));
      await promiseToFuture(result);
    });
  });
}
