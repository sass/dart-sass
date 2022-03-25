// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:js/js.dart';

import '../../../value.dart';
import '../../reflection.dart';
import '../value.dart';

@JS()
class _NodeSassList {
  external SassList get dartValue;
  external set dartValue(SassList dartValue);
}

/// Creates a new `sass.types.List` object wrapping [value].
Object newNodeSassList(SassList value) =>
    legacyListClass.construct([null, null, value]);

/// The JS `sass.types.List` class.
final JSClass legacyListClass = createJSClass('sass.types.List',
    (_NodeSassList thisArg, int? length,
        [bool? commaSeparator, SassList? dartValue]) {
  thisArg.dartValue = dartValue ??
      // Either [dartValue] or [length] must be passed.
      SassList(Iterable.generate(length!, (_) => sassNull),
          (commaSeparator ?? true) ? ListSeparator.comma : ListSeparator.space);
})
  ..defineMethods({
    'getValue': (_NodeSassList thisArg, int index) =>
        wrapValue(thisArg.dartValue.asList[index]),
    'setValue': (_NodeSassList thisArg, int index, Object value) {
      var mutable = thisArg.dartValue.asList.toList();
      mutable[index] = unwrapValue(value);
      thisArg.dartValue = thisArg.dartValue.withListContents(mutable);
    },
    'getSeparator': (_NodeSassList thisArg) =>
        thisArg.dartValue.separator == ListSeparator.comma,
    'setSeparator': (_NodeSassList thisArg, bool isComma) {
      thisArg.dartValue = SassList(thisArg.dartValue.asList,
          isComma ? ListSeparator.comma : ListSeparator.space,
          brackets: thisArg.dartValue.hasBrackets);
    },
    'getLength': (_NodeSassList thisArg) => thisArg.dartValue.asList.length
  });
