// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../value/mixin.dart';
import 'embedded_sass.pb.dart';

/// A registry of [SassMixin]s indexed by ID so that the host can invoke
/// them.
final class MixinRegistry {
  /// First-class mixins that have been sent to the host.
  ///
  /// The mixins are located at indexes in the list matching their IDs.
  final _mixinsById = <SassMixin>[];

  /// A reverse map from mixins to their indexes in [_mixinsById].
  final _idsByMixin = <SassMixin, int>{};

  /// Converts [mixin] to a protocol buffer to send to the host.
  Value_CompilerMixin protofy(SassMixin mixin) {
    var id = _idsByMixin.putIfAbsent(mixin, () {
      _mixinsById.add(mixin);
      return _mixinsById.length - 1;
    });

    return Value_CompilerMixin()..id = id;
  }

  /// Returns the compiler-side mixin associated with [id].
  ///
  /// If no such mixin exists, returns `null`.
  SassMixin? operator [](int id) => _mixinsById[id];
}
