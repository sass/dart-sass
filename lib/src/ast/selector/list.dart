// Copyright 2016 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../../extend/functions.dart';
import '../../parse/selector.dart';
import '../../utils.dart';
import '../../exception.dart';
import '../../value.dart';
import '../../visitor/interface/selector.dart';
import '../selector.dart';

class SelectorList extends Selector {
  final List<ComplexSelector> components;

  bool get _containsParentSelector {
    return components.any((complex) {
      return complex.components.any((component) =>
          component is CompoundSelector &&
          component.components.any((simple) =>
              simple is ParentSelector ||
              (simple is PseudoSelector &&
                  simple.selector != null &&
                  simple.selector._containsParentSelector)));
    });
  }

  SassList get asSassList {
    return new SassList(components.map((complex) {
      return new SassList(
          complex.components
              .map((component) => new SassString(component.toString())),
          ListSeparator.space);
    }), ListSeparator.comma);
  }

  SelectorList(Iterable<ComplexSelector> components)
      : components = new List.unmodifiable(components);

  factory SelectorList.parse(String contents, {url, bool allowParent: true}) =>
      new SelectorParser(contents, url: url, allowParent: allowParent).parse();

  /*=T*/ accept/*<T>*/(SelectorVisitor/*<T>*/ visitor) =>
      visitor.visitSelectorList(this);

  SelectorList unify(SelectorList other) {
    var contents = components.expand((complex1) {
      return other.components.expand((complex2) {
        var unified = unifyComplex(complex1.components, complex2.components);
        if (unified == null) return const <ComplexSelector>[];
        return unified.map((complex) => new ComplexSelector(complex));
      });
    }).toList();

    return contents.isEmpty ? null : new SelectorList(contents);
  }

  SelectorList resolveParentSelectors(SelectorList parent,
      {bool implicitParent: true}) {
    if (parent == null) {
      if (!_containsParentSelector) return this;
      throw new InternalException(
          'Top-level selectors may not contain the parent selector "&".');
    }

    if (!_containsParentSelector) {
      return new SelectorList(parent.components.expand((parentComplex) {
        return components.map((childComplex) => new ComplexSelector(
            parentComplex.components.toList()..addAll(childComplex.components),
            lineBreak: childComplex.lineBreak || parentComplex.lineBreak));
      }));
    }

    return new SelectorList(flattenVertically(components.map((complex) {
      var newComplexes = [<ComplexSelectorComponent>[]];
      var lineBreaks = <bool>[false];
      for (var component in complex.components) {
        if (component is CompoundSelector) {
          var resolved = _resolveParentSelectorsCompound(component, parent);
          if (resolved == null) {
            for (var newComplex in newComplexes) {
              newComplex.add(component);
            }
            continue;
          }

          var previousComplexes = newComplexes;
          var previousLineBreaks = lineBreaks;
          newComplexes = <List<ComplexSelectorComponent>>[];
          lineBreaks = <bool>[];
          var i = 0;
          for (var newComplex in previousComplexes) {
            var lineBreak = previousLineBreaks[i++];
            for (var resolvedComplex in resolved) {
              newComplexes
                  .add(newComplex.toList()..addAll(resolvedComplex.components));
              lineBreaks.add(lineBreak || resolvedComplex.lineBreak);
            }
          }
        } else {
          for (var newComplex in newComplexes) {
            newComplex.add(component);
          }
        }
      }

      var i = 0;
      return newComplexes.map((newComplex) =>
          new ComplexSelector(newComplex, lineBreak: lineBreaks[i++]));
    })));
  }

  Iterable<ComplexSelector> _resolveParentSelectorsCompound(
      CompoundSelector compound, SelectorList parent) {
    var containsSelectorPseudo = compound.components.any((simple) =>
        simple is PseudoSelector &&
        simple.selector != null &&
        simple.selector._containsParentSelector);
    if (!containsSelectorPseudo &&
        compound.components.first is! ParentSelector) {
      return null;
    }

    Iterable<SimpleSelector> resolvedMembers = containsSelectorPseudo
        ? compound.components.map((simple) {
            if (simple is PseudoSelector) {
              if (simple.selector == null) return simple;
              if (!simple.selector._containsParentSelector) return simple;
              return simple.withSelector(simple.selector
                  .resolveParentSelectors(parent, implicitParent: false));
            } else {
              return simple;
            }
          })
        : compound.components;

    var parentSelector = compound.components.first;
    if (parentSelector is ParentSelector) {
      if (compound.components.length == 1 && parentSelector.suffix == null) {
        return parent.components;
      }
    } else {
      return [
        new ComplexSelector([new CompoundSelector(resolvedMembers)])
      ];
    }

    return parent.components.map((complex) {
      var lastComponent = complex.components.last;
      if (lastComponent is! CompoundSelector) {
        throw new InternalException(
            'Parent "$complex" is incompatible with this selector.');
      }

      var last = lastComponent as CompoundSelector;
      var suffix = (compound.components.first as ParentSelector).suffix;
      if (suffix != null) {
        last = new CompoundSelector(
            last.components.take(last.components.length - 1).toList()
              ..add(_addSuffix(last.components.last, suffix))
              ..addAll(resolvedMembers.skip(1)));
      } else {
        last = new CompoundSelector(
            last.components.toList()..addAll(resolvedMembers.skip(1)));
      }

      return new ComplexSelector(
          complex.components.take(complex.components.length - 1).toList()
            ..add(last),
          lineBreak: complex.lineBreak);
    });
  }

  SimpleSelector _addSuffix(SimpleSelector simple, String suffix) {
    if (simple is ClassSelector) {
      return new ClassSelector(simple.name + suffix);
    } else if (simple is IDSelector) {
      return new IDSelector(simple.name + suffix);
    } else if (simple is PlaceholderSelector) {
      return new PlaceholderSelector(simple.name + suffix);
    } else if (simple is TypeSelector) {
      return new TypeSelector(new NamespacedIdentifier(
          simple.name.name + suffix,
          namespace: simple.name.namespace));
    } else if (simple is PseudoSelector &&
        simple.argument == null &&
        simple.selector == null) {
      return new PseudoSelector(simple.name + suffix, simple.type);
    }

    throw new InternalException(
        'Parent "$simple" is incompatible with this selector.');
  }

  bool isSuperselector(SelectorList other) =>
      listIsSuperslector(components, other.components);

  int get hashCode => listHash(components);

  bool operator ==(other) =>
      other is ComplexSelector && listEquals(components, other.components);
}
