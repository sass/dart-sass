// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../extend/functions.dart';
import '../../utils.dart';
import '../selector.dart';

class UniversalSelector extends SimpleSelector {
  final String namespace;

  int get minSpecificity => 0;

  UniversalSelector({this.namespace});

  List<SimpleSelector> unify(List<SimpleSelector> compound) {
    if (compound.first is UniversalSelector || compound.first is TypeSelector) {
      var unified = unifyUniversalAndElement(this, compound.first);
      return [unified]..addAll(compound.skip(1));
    }

    if (namespace != null && namespace != "*") {
      return <SimpleSelector>[this]..addAll(compound);
    }
    if (compound.isNotEmpty) return compound;
    return [this];
  }

  bool operator==(other) => other is UniversalSelector &&
      other.namespace == namespace;

  int get hashCode => namespace.hashCode;

  String toString() => namespace == null ? "*" : "$namespace|*";
}
