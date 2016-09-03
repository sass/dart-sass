// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

class SassException extends SourceSpanException {
  FileSpan get span => super.span as FileSpan;

  SassException(String message, FileSpan span) : super(message, span);
}

class SassFormatException extends SourceSpanFormatException
    implements SassException {
  FileSpan get span => super.span as FileSpan;

  String get source => span.file.getText(0);

  SassFormatException(String message, FileSpan span) : super(message, span);
}
