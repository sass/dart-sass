// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:tuple/tuple.dart';

import '../ast/css.dart';
import '../ast/selector.dart';
import '../ast/sass.dart';
import '../util/box.dart';
import 'extension_store.dart';
import 'extension.dart';

/// An [ExtensionStore] that contains no extensions and can have no extensions
/// added.
class EmptyExtensionStore implements ExtensionStore {
  bool get isEmpty => true;

  Set<SimpleSelector> get simpleSelectors => const UnmodifiableSetView.empty();

  const EmptyExtensionStore();

  Iterable<Extension> extensionsWhereTarget(
          bool callback(SimpleSelector target)) =>
      const [];

  Box<SelectorList> addSelector(SelectorList selector,
      [List<CssMediaQuery>? mediaContext]) {
    throw UnsupportedError(
        "addSelector() can't be called for a const ExtensionStore.");
  }

  void addExtension(
      SelectorList extender, SimpleSelector target, ExtendRule extend,
      [List<CssMediaQuery>? mediaContext]) {
    throw UnsupportedError(
        "addExtension() can't be called for a const ExtensionStore.");
  }

  void addExtensions(Iterable<ExtensionStore> extenders) {
    throw UnsupportedError(
        "addExtensions() can't be called for a const ExtensionStore.");
  }

  Tuple2<ExtensionStore, Map<SelectorList, Box<SelectorList>>> clone() =>
      const Tuple2(EmptyExtensionStore(), {});
}
