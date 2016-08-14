// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import 'dart:math' as math;

import 'package:charcode/charcode.dart';

import '../selector.dart';

final _vendorPrefix = new RegExp(r'^-[a-zA-Z0-9]+-');

class PseudoSelector extends SimpleSelector {
  final String name;

  final String normalizedName;

  final PseudoType type;

  final String argument;

  final SelectorList selector; 

  int get minSpecificity {
    if (_minSpecificity == null) _computeSpecificity();
    return _minSpecificity;
  }
  int _minSpecificity;

  int get maxSpecificity {
    if (_maxSpecificity == null) _computeSpecificity();
    return _maxSpecificity;
  }
  int _maxSpecificity;

  PseudoSelector(String name, this.type, {this.argument, this.selector})
      : name = name,
        normalizedName = name.replaceFirst(_vendorPrefix, '');

  List<SimpleSelector> unify(List<SimpleSelector> compound) {
    if (compound.contains(this)) return compound;

    var result = <SimpleSelector>[];
    var addedThis = false;
    for (var simple in compound) {
      if (simple is PseudoSelector && simple.type == PseudoType.element) {
        // A given compound selector may only contain one pseudo element. If
        // [compound] has a different one than [this], unification fails.
        if (this.type == PseudoType.element) return null;

        // Otherwise, this is a pseudo selector and should come before pseduo
        // elements.
        result.add(this);
        addedThis = true;
      }

      result.add(simple);
    }
    if (!addedThis) result.add(this);

    return result;
  }

  void _computeSpecificity() {
    if (type == PseudoType.element) {
      _minSpecificity = 1;
      _maxSpecificity = 1;
      return;
    }

    if (selector == null) {
      _minSpecificity = super.minSpecificity;
      _maxSpecificity = super.maxSpecificity;
      return;
    }

    if (name == 'not') {
      _minSpecificity = 0;
      _maxSpecificity = 0;
      for (var complex in selector.components) {
        _minSpecificity = math.max(_minSpecificity, complex.minSpecificity);
        _maxSpecificity = math.max(_maxSpecificity, complex.maxSpecificity);
      }
    } else {
      // This is higher than any selector's specificity can actually be.
      _minSpecificity = math.pow(super.minSpecificity, 3);
      _maxSpecificity = 0;
      for (var complex in selector.components) {
        _minSpecificity = math.min(_minSpecificity, complex.minSpecificity);
        _maxSpecificity = math.max(_maxSpecificity, complex.maxSpecificity);
      }
    }
  }

  // This intentionally uses identity for the selector list, if one is available.
  bool operator==(other) =>
      other is PseudoSelector &&
      other.name == name &&
      other.type == type &&
      other.argument == argument &&
      other.selector == selector;

  int get hashCode =>
      name.hashCode ^ type.hashCode ^ argument.hashCode ^ selector.hashCode;

  String toString() {
    var buffer = new StringBuffer("$type$name");
    if (argument == null && selector == null) return buffer.toString();

    buffer.writeCharCode($lparen);
    if (argument != null) buffer.write(argument);
    if (argument != null && selector != null) buffer.writeCharCode($space);
    if (selector != null) buffer.write(selector);
    buffer.writeCharCode($rparen);
    return buffer.toString();
  }
}

class PseudoType {
  static const element = const PseudoType._("::");
  static const klass = const PseudoType._(":");

  final String _text;

  const PseudoType._(this._text);

  String toString() => _text;
}
