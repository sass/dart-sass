// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'package:source_span/source_span.dart';

import '../../utils.dart';
import '../node.dart';
import 'value.dart';

class CssMediaQuery implements AstNode {
  final CssValue<String> modifier;

  final CssValue<String> type;

  final List<CssValue<String>> features;

  FileSpan get span {
    var components = <AstNode>[];
    if (modifier != null) components.add(modifier);
    if (type != null) components.add(type);
    components.addAll(features);
    return spanForList(components);
  }

  CssMediaQuery(this.type, {this.modifier,
      Iterable<CssValue<String>> features})
      : features = features == null
            ? const []
            : new List.unmodifiable(features);

  CssMediaQuery.condition(Iterable<CssValue<String>> features)
      : modifier = null,
        type = null,
        features = new List.unmodifiable(features);

  CssMediaQuery merge(CssMediaQuery other) {
    var ourModifier = this.modifier?.value?.toLowerCase();
    var ourType = this.type?.value?.toLowerCase();
    var theirModifier = other.modifier?.value?.toLowerCase();
    var theirType = other.type?.value?.toLowerCase();

    if (ourType == null && theirType == null) {
      return new CssMediaQuery.condition(
          features.toList()..addAll(other.features));
    }

    String modifier;
    String type;
    if (ourType == null) {
      modifier = theirModifier;
      type = theirType;
    } else if (theirType == null) {
      modifier = ourModifier;
      type = ourType;
    } else if ((ourModifier == 'not') != (theirModifier == 'not')) {
      if (ourType == theirType) return null;
      modifier = ourModifier == 'not' ? theirModifier : ourModifier;
      type = ourModifier == 'not' ? theirType : ourType;
    } else if (ourModifier == 'not') {
      assert(theirModifier == 'not');
      // CSS has no way of representing "neither screen nor print".
      if (ourType == theirType) return null;
      modifier = ourModifier; // "not"
      type = ourType;
    } else if (ourType != theirType) {
      return null;
    } else {
      modifier = ourModifier ?? theirModifier;
      type = ourType;
    }

    return new CssMediaQuery(
        type == ourType ? this.type : other.type,
        modifier: modifier == ourModifier ? this.modifier : other.modifier,
        features: features.toList()..addAll(other.features));
  }

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
