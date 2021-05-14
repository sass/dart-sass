// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:sass/sass.dart';
import 'package:test/test.dart';

/// An [Importer] whose [canonicalize] method asserts the value of
/// [Importer.fromImport].
class FromImportImporter extends Importer {
  /// The expected value of [Importer.fromImport] in the call to [canonicalize].
  final bool _expected;

  /// The callback to call once [canonicalize] is called.
  ///
  /// This ensures that the test doesn't exit until [canonicalize] is called.
  final void Function() _done;

  FromImportImporter(this._expected) : _done = expectAsync0(() {});

  Uri? canonicalize(Uri url) {
    expect(fromImport, equals(_expected));
    _done();
    return Uri.parse('u:');
  }

  ImporterResult? load(Uri url) => ImporterResult("", syntax: Syntax.scss);
}
