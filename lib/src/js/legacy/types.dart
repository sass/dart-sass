// Copyright 2018 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

// ignore_for_file: non_constant_identifier_names
// See dart-lang/sdk#47374

import 'dart:js_interop';

import 'package:js_core/js_core.dart';
import 'package:js_core/unsafe.dart';
import 'value/boolean.dart';
import 'value/color.dart';
import 'value/list.dart';
import 'value/map.dart';
import 'value/null.dart';
import 'value/number.dart';
import 'value/string.dart';

extension type Types._(JSObject _) implements JSObject {
  external set Boolean(JSClass<JSSassLegacyBoolean> function);
  external set Color(JSClass<JSSassLegacyColor> function);
  external set List(JSClass<JSSassLegacyList> function);
  external set Map(JSClass<JSSassLegacyMap> function);
  external set Null(JSClass<JSSassLegacyNull> function);
  external set Number(JSClass<JSSassLegacyNumber> function);
  external set String(JSClass<JSSassLegacyString> function);
  external set Error(JSClass<JSError> function);

  external Types({
    JSClass<JSSassLegacyBoolean>? Boolean,
    JSClass<JSSassLegacyColor>? Color,
    JSClass<JSSassLegacyList>? List,
    JSClass<JSSassLegacyMap>? Map,
    JSClass<JSSassLegacyNull>? Null,
    JSClass<JSSassLegacyNumber>? Number,
    JSClass<JSSassLegacyString>? String,
    JSClass<JSError>? Error,
  });
}
