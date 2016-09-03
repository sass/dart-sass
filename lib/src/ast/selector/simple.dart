// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../exception.dart';
import '../selector.dart';

abstract class SimpleSelector extends Selector {
  // 1000 is the base used for calculating selector specificity.
  //
  // The spec says this should be "sufficiently high"; it's extremely unlikely
  // that any single selector sequence will contain 1,000 simple selectors.
  int get minSpecificity => 1000;
  int get maxSpecificity => minSpecificity;

  SimpleSelector addSuffix(String suffix) =>
      throw new InternalException('Invalid parent selector "$this"');

  List<SimpleSelector> unify(List<SimpleSelector> compound) {
    if (compound.contains(this)) return compound;

    var result = <SimpleSelector>[];
    var addedThis = false;
    for (var simple in compound) {
      // Make sure pseudo selectors always come last.
      if (!addedThis && simple is PseudoSelector) {
        result.add(this);
        addedThis = true;
      }
      result.add(simple);
    }
    if (!addedThis) result.add(this);

    return result;
  }
}
