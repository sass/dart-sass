// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Interpolation, ParentSelector} from '../..';
import {
  fromSimpleSelectorProps,
  parseSimpleSelector,
} from '../../../test/utils';

describe('a parent selector', () => {
  let node: ParentSelector;

  describe('without a suffix', () => {
    function describeNode(
      description: string,
      create: () => ParentSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType parent', () => expect(node.sassType).toBe('parent'));

        it('has no suffix', () => expect(node.suffix).toBeUndefined());
      });
    }

    describeNode('parsed', () => parseSimpleSelector('&'));

    describeNode('constructed manually', () => new ParentSelector());

    describeNode('from props', () =>
      fromSimpleSelectorProps({suffix: undefined}),
    );
  });

  describe('without interpolation', () => {
    function describeNode(
      description: string,
      create: () => ParentSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType parent', () => expect(node.sassType).toBe('parent'));

        it('has a suffix', () =>
          expect(node).toHaveInterpolation('suffix', 'foo'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('&foo'));

    describeNode(
      'constructed manually',
      () => new ParentSelector({suffix: 'foo'}),
    );

    describeNode('from props', () => fromSimpleSelectorProps({suffix: 'foo'}));
  });

  describe('with interpolation', () => {
    function describeNode(
      description: string,
      create: () => ParentSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType parent', () => expect(node.sassType).toBe('parent'));

        it('has a suffix', () =>
          expect(node.suffix).toHaveStringExpression(0, 'foo'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('&#{foo}'));

    describeNode(
      'constructed manually',
      () => new ParentSelector({suffix: [{text: 'foo'}]}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({suffix: [{text: 'foo'}]}),
    );
  });

  describe('assigned new suffix', () => {
    beforeEach(() => void (node = parseSimpleSelector('&foo')));

    it("removes the old suffix's parent", () => {
      const oldSuffix = node.suffix;
      node.suffix = 'bar';
      expect(oldSuffix!.parent).toBeUndefined();
    });

    it('assigns suffix explicitly', () => {
      const suffix = new Interpolation('bar');
      node.suffix = suffix;
      expect(node.suffix).toBe(suffix);
      expect(node).toHaveInterpolation('suffix', 'bar');
    });

    it('assigns suffix as InterpolationProps', () => {
      node.suffix = 'bar';
      expect(node).toHaveInterpolation('suffix', 'bar');
    });

    it('assigns undefined suffix', () => {
      const oldSuffix = node.suffix;
      node.suffix = undefined;
      expect(oldSuffix!.parent).toBeUndefined();
      expect(node.suffix).toBeUndefined();
    });
  });

  describe('stringifies', () => {
    it('with no suffix', () =>
      expect(parseSimpleSelector('&').toString()).toBe('&'));

    it('with a suffix', () =>
      expect(parseSimpleSelector('&foo').toString()).toBe('&foo'));
  });

  describe('clone', () => {
    let original: ParentSelector;

    beforeEach(() => {
      original = parseSimpleSelector('&foo');
    });

    describe('with no overrides', () => {
      let clone: ParentSelector;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('suffix', () => expect(clone).toHaveInterpolation('suffix', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      it('creates a new self', () => expect(clone).not.toBe(original));
    });

    describe('overrides', () => {
      describe('suffix', () => {
        it('defined', () =>
          expect(original.clone({suffix: 'bar'})).toHaveInterpolation(
            'suffix',
            'bar',
          ));

        it('undefined', () =>
          expect(original.clone({suffix: undefined}).suffix).toBeUndefined());
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
    it('with no suffix', () =>
      expect(parseSimpleSelector('&')).toMatchSnapshot());

    it('with a suffix', () =>
      expect(parseSimpleSelector('&foo')).toMatchSnapshot());
  });
});
