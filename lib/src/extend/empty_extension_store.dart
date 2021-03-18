// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:collection/collection.dart';
import 'package:source_span/source_span.dart';
import 'package:tuple/tuple.dart';

import '../ast/css.dart';
import '../ast/css/modifiable.dart';
import '../ast/selector.dart';
import '../ast/sass.dart';
import 'extension_store.dart';
import 'extension.dart';

class EmptyExtensionStore implements ExtensionStore {
  bool get isEmpty => true;

  Set<SimpleSelector> get simpleSelectors => const UnmodifiableSetView.empty();

  const EmptyExtensionStore();

  Iterable<Extension> extensionsWhereTarget(
          bool callback(SimpleSelector target)) =>
      const [];

  ModifiableCssValue<SelectorList> addSelector(
      SelectorList selector, FileSpan? span,
      [List<CssMediaQuery>? mediaContext]) {
    throw UnsupportedError(
        "addSelector() can't be called for a const ExtensionStore.");
  }

  void addExtension(
      CssValue<SelectorList> extender, SimpleSelector target, ExtendRule extend,
      [List<CssMediaQuery>? mediaContext]) {
    throw UnsupportedError(
        "addExtension() can't be called for a const ExtensionStore.");
  }

  void addExtensions(Iterable<ExtensionStore> extenders) {
    throw UnsupportedError(
        "addExtensions() can't be called for a const ExtensionStore.");
  }

  Tuple2<ExtensionStore,
          Map<CssValue<SelectorList>, ModifiableCssValue<SelectorList>>>
      clone() => const Tuple2(EmptyExtensionStore(), {});
}
