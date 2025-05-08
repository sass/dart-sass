// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:js_interop';

import 'package:js_core/unsafe.dart';

import '../../../value.dart';
import '../../hybrid/value/list.dart';
import '../value.dart';

extension type JSSassLegacyList._(JSLegacyValue _) implements JSLegacyValue {
  /// The JS `sass.types.List` class.
  static final jsClass = JSClass<JSSassLegacyList>(
      (
        JSSassLegacyList self,
        int? length, [
        bool? commaSeparator,
        UnsafeDartWrapper<SassList>? modernValue,
      ]) {
        self.modernValue = modernValue ??
            // Either [modernValue] or [length] must be passed.
            SassList(
              Iterable.generate(length!, (_) => sassNull),
              (commaSeparator ?? true)
                  ? ListSeparator.comma
                  : ListSeparator.space,
            ).toJS;
      }.toJSCaptureThis,
      name: 'sass.types.List')
    ..defineMethods({
      'getValue': ((JSSassLegacyList self, int index) =>
          self.toDart.asList[index].toJSLegacy).toJSCaptureThis,
      'setValue': (JSSassLegacyList self, int index, JSLegacyValue value) {
        var mutable = self.toDart.asList.toList();
        mutable[index] = value.toDart;
        self.modernValue = self.toDart.withListContents(mutable).toJS;
      }.toJSCaptureThis,
      'getSeparator': ((JSSassLegacyList self) =>
          self.toDart.separator == ListSeparator.comma).toJSCaptureThis,
      'setSeparator': (JSSassLegacyList self, bool isComma) {
        self.modernValue = SassList(
          self.toDart.asList,
          isComma ? ListSeparator.comma : ListSeparator.space,
          brackets: self.toDart.hasBrackets,
        ).toJS;
      }.toJSCaptureThis,
      'getLength': ((JSSassLegacyList self) => self.toDart.asList.length)
          .toJSCaptureThis,
    });

  /// The value of the list in the modern JS API.
  @JS('dartValue')
  external UnsafeDartWrapper<SassList> modernValue;

  SassList get toDart => modernValue.toDart;
}

extension SassListToJSLegacy on SassList {
  JSSassLegacyList get toJSLegacy =>
      JSSassLegacyList.jsClass.construct(null, null, toJS);
}
