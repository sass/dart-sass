// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Interpolation, QualifiedName, TypeSelector} from '../..';
import {
  fromSimpleSelectorProps,
  parseSimpleSelector,
} from '../../../test/utils';

describe('a type selector', () => {
  let node: TypeSelector;

  function describeNode(description: string, create: () => TypeSelector): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has sassType type', () => expect(node.sassType).toBe('type'));

      it('has a type', () => {
        expect(node.type.toString()).toEqual('foo');
        expect(node.type.sassType).toEqual('qualified-name');
        expect(node.type.parent).toBe(node);
      });
    });
  }

  describeNode('parsed', () => parseSimpleSelector('foo'));

  describeNode('constructed manually', () => new TypeSelector({type: 'foo'}));

  describeNode('from props', () => fromSimpleSelectorProps({type: 'foo'}));

  describe('assigned new type', () => {
    beforeEach(() => void (node = parseSimpleSelector('foo')));

    it("removes the old type's parent", () => {
      const oldType = node.type;
      node.type = 'bar';
      expect(oldType.parent).toBeUndefined();
    });

    it('assigns type explicitly', () => {
      const type = new QualifiedName('bar');
      node.type = type;
      expect(node.type).toBe(type);
      expect(node.type.parent).toBe(node);
    });

    it('assigns type as Interpolation', () => {
      const type = new Interpolation('bar');
      node.type = type;
      expect(node.type.sassType).toEqual('qualified-name');
      expect(node.type.toString()).toEqual('bar');
      expect(node.type.parent).toBe(node);
    });

    it('assigns type as InterpolationProps', () => {
      node.type = 'bar';
      expect(node).toHaveNode('type', 'bar', 'qualified-name');
    });
  });

  it('stringifies', () =>
    expect(parseSimpleSelector('foo').toString()).toBe('foo'));

  describe('clone', () => {
    let original: TypeSelector;

    beforeEach(() => {
      original = parseSimpleSelector('foo');
    });

    describe('with no overrides', () => {
      let clone: TypeSelector;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('type', () => {
          expect(clone.type.toString()).toEqual('foo');
          expect(clone.type.parent).toBe(clone);
        });

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['type', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('class', () => {
        it('defined', () =>
          expect(original.clone({type: 'bar'})).toHaveNode('type', 'bar'));

        it('undefined', () =>
          expect(original.clone({type: undefined})).toHaveNode('type', 'foo'));
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {}}).raws).toEqual({}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({}));
      });
    });
  });

  it('toJSON', () => expect(parseSimpleSelector('foo')).toMatchSnapshot());
});
