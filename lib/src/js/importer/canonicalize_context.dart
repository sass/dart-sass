// Copyright 2014 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../importer/canonicalize_context.dart';
import '../../util/nullable.dart';
import '../reflection.dart';
import '../utils.dart';

/// Adds JS members to Dart's `CanonicalizeContext` class.
void updateCanonicalizeContextPrototype() =>
    getJSClass(CanonicalizeContext(null, false)).defineGetters({
      'fromImport': (CanonicalizeContext self) => self.fromImport,
      'containingUrl': (CanonicalizeContext self) =>
          self.containingUrl.andThen(dartToJSUrl),
    });
