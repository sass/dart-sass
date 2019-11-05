// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'embedded_sass.pb.dart';

/// Returns a [ProtocolError] indicating that a mandatory field with the givne
/// [fieldName] was missing.
ProtocolError mandatoryError(String fieldName) => ProtocolError()
  ..type = ProtocolError_ErrorType.PARAMS
  ..message = "Missing mandatory field $fieldName";
