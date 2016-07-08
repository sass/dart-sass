// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../utils.dart';
import '../node.dart';
import 'expression.dart';
import 'node.dart';

class MediaQuery implements SassNode {
  final InterpolationExpression modifier;

  final InterpolationExpression type;

  final List<InterpolationExpression> features;

  FileSpan get span {
    var components = <AstNode>[];
    if (modifier != null) components.add(modifier);
    if (type != null) components.add(type);
    components.addAll(features);
    return spanForList(components);
  }

  MediaQuery(this.type, {this.modifier,
      Iterable<InterpolationExpression> features})
      : features = features == null
            ? const []
            : new List.unmodifiable(features);

  MediaQuery.condition(Iterable<InterpolationExpression> features,
      {this.modifier, this.type})
      : features = new List.unmodifiable(features);

  String toString() {
    var buffer = new StringBuffer();
    if (modifier != null) buffer.write("$modifier ");
    if (type != null) {
      buffer.write(type);
      if (features.isNotEmpty) buffer.write(" and ");
    }

    buffer.write(features.join(" and "));
    return buffer.toString();
  }
}
