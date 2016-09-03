// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../ast/selector.dart';

class ExtendSource {
  final SelectorList extender;

  final FileSpan span;

  bool isUsed = false;

  ExtendSource(this.extender, this.span);

  int get hashCode => extender.hashCode;

  bool operator ==(Object other) =>
      other is ExtendSource && other.extender == extender;
}
