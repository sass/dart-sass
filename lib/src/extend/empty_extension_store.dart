// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';

import '../ast/css.dart';
import '../ast/selector.dart';
import '../ast/sass.dart';
import '../util/box.dart';
import 'extension_store.dart';
import 'extension.dart';

/// An [ExtensionStore] that contains no extensions and can have no extensions
/// added.
final class EmptyExtensionStore implements ExtensionStore {
  @override
  bool get isEmpty => true;

  @override
  Set<SimpleSelector> get simpleSelectors => const UnmodifiableSetView.empty();

  const EmptyExtensionStore();

  @override
  Iterable<Extension> extensionsWhereTarget(
    bool Function(SimpleSelector target) callback,
  ) =>
      const [];

  @override
  Box<SelectorList> addSelector(
    SelectorList selector, [
    List<CssMediaQuery>? mediaContext,
  ]) {
    throw UnsupportedError(
      "addSelector() can't be called for a const ExtensionStore.",
    );
  }

  @override
  void addExtension(
    SelectorList extender,
    SimpleSelector target,
    ExtendRule extend, [
    List<CssMediaQuery>? mediaContext,
  ]) {
    throw UnsupportedError(
      "addExtension() can't be called for a const ExtensionStore.",
    );
  }

  @override
  void addExtensions(Iterable<ExtensionStore> extenders) {
    throw UnsupportedError(
      "addExtensions() can't be called for a const ExtensionStore.",
    );
  }

  @override
  (ExtensionStore, Map<SelectorList, Box<SelectorList>>) clone() => const (
        EmptyExtensionStore(),
        {},
      );
}
