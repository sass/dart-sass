// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Interpolation, PlaceholderSelector} from '../..';
import {
  fromSimpleSelectorProps,
  parseSimpleSelector,
} from '../../../test/utils';

describe('a placeholder selector', () => {
  let node: PlaceholderSelector;

  describe('without interpolation', () => {
    function describeNode(
      description: string,
      create: () => PlaceholderSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType placeholder', () =>
          expect(node.sassType).toBe('placeholder'));

        it('has a placeholder', () =>
          expect(node).toHaveInterpolation('placeholder', 'foo'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('%foo'));

    describeNode(
      'constructed manually',
      () => new PlaceholderSelector({placeholder: 'foo'}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({placeholder: 'foo'}),
    );
  });

  describe('with interpolation', () => {
    function describeNode(
      description: string,
      create: () => PlaceholderSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType placeholder', () =>
          expect(node.sassType).toBe('placeholder'));

        it('has a placeholder', () =>
          expect(node.placeholder).toHaveStringExpression(0, 'foo'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('%#{foo}'));

    describeNode(
      'constructed manually',
      () => new PlaceholderSelector({placeholder: [{text: 'foo'}]}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({placeholder: [{text: 'foo'}]}),
    );
  });

  describe('assigned new placeholder', () => {
    beforeEach(() => void (node = parseSimpleSelector('%foo')));

    it("removes the old placeholder's parent", () => {
      const oldPlaceholder = node.placeholder;
      node.placeholder = 'bar';
      expect(oldPlaceholder.parent).toBeUndefined();
    });

    it('assigns placeholder explicitly', () => {
      const placeholder = new Interpolation('bar');
      node.placeholder = placeholder;
      expect(node.placeholder).toBe(placeholder);
      expect(node).toHaveInterpolation('placeholder', 'bar');
    });

    it('assigns placeholder as InterpolationProps', () => {
      node.placeholder = 'bar';
      expect(node).toHaveInterpolation('placeholder', 'bar');
    });
  });

  it('stringifies', () =>
    expect(parseSimpleSelector('%foo').toString()).toBe('%foo'));

  describe('clone', () => {
    let original: PlaceholderSelector;

    beforeEach(() => {
      original = parseSimpleSelector('%foo');
    });

    describe('with no overrides', () => {
      let clone: PlaceholderSelector;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('placeholder', () =>
          expect(clone).toHaveInterpolation('placeholder', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['placeholder', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('placeholder', () => {
        it('defined', () =>
          expect(original.clone({placeholder: 'bar'})).toHaveInterpolation(
            'placeholder',
            'bar',
          ));

        it('undefined', () =>
          expect(original.clone({placeholder: undefined})).toHaveInterpolation(
            'placeholder',
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

  it('toJSON', () => expect(parseSimpleSelector('%foo')).toMatchSnapshot());
});
