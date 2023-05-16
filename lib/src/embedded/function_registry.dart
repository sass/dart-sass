// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../value/function.dart';
import 'embedded_sass.pb.dart';

/// A registry of [SassFunction]s indexed by ID so that the host can invoke
/// them.
class FunctionRegistry {
  /// First-class functions that have been sent to the host.
  ///
  /// The functions are located at indexes in the list matching their IDs.
  final _functionsById = <SassFunction>[];

  /// A reverse map from functions to their indexes in [_functionsById].
  final _idsByFunction = <SassFunction, int>{};

  /// Converts [function] to a protocol buffer to send to the host.
  Value_CompilerFunction protofy(SassFunction function) {
    var id = _idsByFunction.putIfAbsent(function, () {
      _functionsById.add(function);
      return _functionsById.length - 1;
    });

    return Value_CompilerFunction()..id = id;
  }

  /// Returns the compiler-side function associated with [id].
  ///
  /// If no such function exists, returns `null`.
  SassFunction? operator [](int id) => _functionsById[id];
}
