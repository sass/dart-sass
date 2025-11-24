// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {ClassSelector, Interpolation} from '../..';
import {
  fromSimpleSelectorProps,
  parseSimpleSelector,
} from '../../../test/utils';

describe('a class selector', () => {
  let node: ClassSelector;

  describe('without interpolation', () => {
    function describeNode(
      description: string,
      create: () => ClassSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType class', () => expect(node.sassType).toBe('class'));

        it('has a class', () =>
          expect(node).toHaveInterpolation('class', 'foo'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('.foo'));

    describeNode(
      'constructed manually',
      () => new ClassSelector({class: 'foo'}),
    );

    describeNode('from props', () => fromSimpleSelectorProps({class: 'foo'}));
  });

  describe('with interpolation', () => {
    function describeNode(
      description: string,
      create: () => ClassSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType class', () => expect(node.sassType).toBe('class'));

        it('has a class', () =>
          expect(node.class).toHaveStringExpression(0, 'foo'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('.#{foo}'));

    describeNode(
      'constructed manually',
      () => new ClassSelector({class: [{text: 'foo'}]}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({class: [{text: 'foo'}]}),
    );
  });

  describe('assigned new class', () => {
    beforeEach(() => void (node = parseSimpleSelector('.foo')));

    it("removes the old class's parent", () => {
      const oldClass = node.class;
      node.class = 'bar';
      expect(oldClass.parent).toBeUndefined();
    });

    it('assigns class explicitly', () => {
      const className = new Interpolation('bar');
      node.class = className;
      expect(node.class).toBe(className);
      expect(node).toHaveInterpolation('class', 'bar');
    });

    it('assigns class as InterpolationProps', () => {
      node.class = 'bar';
      expect(node).toHaveInterpolation('class', 'bar');
    });
  });

  it('stringifies', () =>
    expect(parseSimpleSelector('.foo').toString()).toBe('.foo'));

  describe('clone', () => {
    let original: ClassSelector;

    beforeEach(() => {
      original = parseSimpleSelector('.foo');
    });

    describe('with no overrides', () => {
      let clone: ClassSelector;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('class', () => expect(clone).toHaveInterpolation('class', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['class', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('class', () => {
        it('defined', () =>
          expect(original.clone({class: 'bar'})).toHaveInterpolation(
            'class',
            'bar',
          ));

        it('undefined', () =>
          expect(original.clone({class: undefined})).toHaveInterpolation(
            'class',
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

  it('toJSON', () => expect(parseSimpleSelector('.foo')).toMatchSnapshot());
});
