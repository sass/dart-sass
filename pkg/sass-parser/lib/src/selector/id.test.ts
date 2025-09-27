// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {IDSelector, Interpolation} from '../..';
import {
  fromSimpleSelectorProps,
  parseSimpleSelector,
} from '../../../test/utils';

describe('an ID selector', () => {
  let node: IDSelector;

  describe('without interpolation', () => {
    function describeNode(description: string, create: () => IDSelector): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType id', () => expect(node.sassType).toBe('id'));

        it('has an ID', () => expect(node).toHaveInterpolation('id', 'foo'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('#foo'));

    describeNode('constructed manually', () => new IDSelector({id: 'foo'}));

    describeNode('from props', () => fromSimpleSelectorProps({id: 'foo'}));
  });

  describe('with interpolation', () => {
    function describeNode(description: string, create: () => IDSelector): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType id', () => expect(node.sassType).toBe('id'));

        it('has an ID', () => expect(node.id).toHaveStringExpression(0, 'foo'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('##{foo}'));

    describeNode(
      'constructed manually',
      () => new IDSelector({id: [{text: 'foo'}]}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({id: [{text: 'foo'}]}),
    );
  });

  describe('assigned new id', () => {
    beforeEach(() => void (node = parseSimpleSelector('#foo')));

    it("removes the old id's parent", () => {
      const oldId = node.id;
      node.id = 'bar';
      expect(oldId.parent).toBeUndefined();
    });

    it('assigns id explicitly', () => {
      const id = new Interpolation('bar');
      node.id = id;
      expect(node.id).toBe(id);
      expect(node).toHaveInterpolation('id', 'bar');
    });

    it('assigns id as InterpolationProps', () => {
      node.id = 'bar';
      expect(node).toHaveInterpolation('id', 'bar');
    });
  });

  it('stringifies', () =>
    expect(parseSimpleSelector('#foo').toString()).toBe('#foo'));

  describe('clone', () => {
    let original: IDSelector;

    beforeEach(() => {
      original = parseSimpleSelector('#foo');
    });

    describe('with no overrides', () => {
      let clone: IDSelector;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('id', () => expect(clone).toHaveInterpolation('id', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['id', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('id', () => {
        it('defined', () =>
          expect(original.clone({id: 'bar'})).toHaveInterpolation('id', 'bar'));

        it('undefined', () =>
          expect(original.clone({id: undefined})).toHaveInterpolation(
            'id',
            'foo',
          ));
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {}}).raws).toEqual({}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({}));
      });
    });
  });

  it('toJSON', () => expect(parseSimpleSelector('#foo')).toMatchSnapshot());
});
