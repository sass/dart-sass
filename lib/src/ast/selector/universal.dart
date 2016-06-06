// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../selector.dart';

class UniversalSelector extends SimpleSelector {
  final String namespace;

  final SourceSpan span;

  UniversalSelector({this.namespace, this.span});

  String toString() => namespace == null ? "*" : "$namespace|*";
}
