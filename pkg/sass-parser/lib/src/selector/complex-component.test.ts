// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  ComplexSelector,
  ComplexSelectorComponent,
  ComplexSelectorComponentProps,
  CompoundSelector,
} from '../..';
import * as utils from '../../../test/utils';

/** Parses `text` as a single compound selector. */
function parse(text: string): ComplexSelectorComponent {
  const list = utils.parseSelector(text);
  expect(list.nodes).toHaveLength(1);
  const complex = list.nodes[0];
  expect(complex.nodes).toHaveLength(1);
  return complex.nodes[0];
}

/** Loads `props` as a complex selector component. */
function fromProps(
  props: ComplexSelectorComponentProps,
): ComplexSelectorComponent {
  return new ComplexSelector([props]).nodes[0];
}

describe('a complex selector component', () => {
  let node: ComplexSelectorComponent;

  describe('without a combinator', () => {
    function describeNode(
      description: string,
      create: () => ComplexSelectorComponent,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType complex-selector-component', () =>
          expect(node.sassType).toBe('complex-selector-component'));

        it('has no combinator', () => expect(node.combinator).toBeUndefined());

        it('has a compound', () =>
          expect(node).toHaveNode('compound', '.foo', 'compound-selector'));
      });
    }

    describeNode('parsed', () => parse('.foo'));

    describeNode(
      'constructed manually',
      () => new ComplexSelectorComponent({compound: {class: 'foo'}}),
    );

    describe('from props', () => {
      describeNode('as an object', () => fromProps({compound: {class: 'foo'}}));

      describeNode('as a compound selector', () => fromProps({class: 'foo'}));
    });
  });

  describe('with a combinator', () => {
    function describeNode(
      description: string,
      create: () => ComplexSelectorComponent,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType complex-selector-component', () =>
          expect(node.sassType).toBe('complex-selector-component'));

        it('has a combinator', () => expect(node.combinator).toEqual('>'));

        it('has a compound', () =>
          expect(node).toHaveNode('compound', '.foo', 'compound-selector'));
      });
    }

    describeNode('parsed', () => parse('.foo >'));

    describeNode(
      'constructed manually',
      () =>
        new ComplexSelectorComponent({
          compound: {class: 'foo'},
          combinator: '>',
        }),
    );

    describeNode('from props', () =>
      fromProps({compound: {class: 'foo'}, combinator: '>'}),
    );
  });

  describe('assigned new', () => {
    beforeEach(() => void (node = parse('.foo >')));

    describe('combinator', () => {
      it('defined', () => {
        node.combinator = '+';
        expect(node.combinator).toEqual('+');
      });

      it('undefined', () => {
        node.combinator = undefined;
        expect(node.combinator).toBeUndefined();
      });
    });

    describe('compound', () => {
      it("removes the old compound's parent", () => {
        const oldCompound = node.compound;
        node.compound = {class: 'bar'};
        expect(oldCompound.parent).toBeUndefined();
      });

      it('assigns compound explicitly', () => {
        const compound = new CompoundSelector({class: 'bar'});
        node.compound = compound;
        expect(node.compound).toBe(compound);
        expect(node.compound.parent).toBe(node);
      });

      it('assigns compound as CompoundSelectorProps', () => {
        node.compound = {class: 'bar'};
        expect(node).toHaveNode('compound', '.bar');
      });
    });
  });

  describe('stringifies', () => {
    describe('without a combinator', () => {
      beforeEach(() => {
        node = new ComplexSelectorComponent({class: 'foo'});
      });

      it('with no raws', () => expect(node.toString()).toBe('.foo'));

      it('ignores all raws', () => {
        node.raws.between = '  ';
        expect(node.toString()).toBe('.foo');
      });
    });

    describe('with a combinator', () => {
      beforeEach(() => {
        node = new ComplexSelectorComponent({
          combinator: '+',
          compound: {class: 'foo'},
        });
      });

      it('with no raws', () => expect(node.toString()).toBe('.foo +'));

      it('ignores all raws', () => {
        node.raws.between = '  ';
        expect(node.toString()).toBe('.foo  +');
      });
    });
  });

  describe('clone', () => {
    let original: ComplexSelectorComponent;

    beforeEach(() => {
      original = parse('.foo +');
    });

    describe('with no overrides', () => {
      let clone: ComplexSelectorComponent;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('combinator', () => expect(clone.combinator).toEqual('+'));

        it('compound', () => expect(clone).toHaveNode('compound', '.foo'));

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['compound', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('combinator', () => {
        it('defined', () =>
          expect(original.clone({combinator: '>'}).combinator).toBe('>'));

        it('undefined', () =>
          expect(
            original.clone({combinator: undefined}).combinator,
          ).toBeUndefined());
      });

      describe('selector', () => {
        it('defined', () => {
          const clone = original.clone({compound: {id: 'bar'}});
          expect(clone).toHaveNode('compound', '#bar');
        });

        it('undefined', () =>
          expect(
            original.clone({compound: undefined}).compound.toString(),
          ).toEqual('.foo'));
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {}}).raws).toEqual({}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({}));
      });
    });
  });

  describe('toJSON', () => {
    it('with no combinator', () => expect(parse('.foo')).toMatchSnapshot());

    it('with a combinator', () => expect(parse('.foo +')).toMatchSnapshot());
  });
});
