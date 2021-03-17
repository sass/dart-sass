// Copyright 2017 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:sass/sass.dart';

/// An [Importer] whose [canonicalize] and [load] methods are provided by
/// closures.
class TestImporter extends Importer {
  final Uri Function(Uri url) _canonicalize;
  final ImporterResult Function(Uri url) _load;

  TestImporter(this._canonicalize, this._load);

  Uri canonicalize(Uri url) => _canonicalize(url);

  ImporterResult load(Uri url) => _load(url);
}
