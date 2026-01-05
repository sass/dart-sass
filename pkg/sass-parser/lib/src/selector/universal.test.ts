// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Interpolation, UniversalSelector} from '../..';
import {
  fromSimpleSelectorProps,
  parseSimpleSelector,
} from '../../../test/utils';

describe('a universal selector', () => {
  let node: UniversalSelector;

  describe('without a namespace', () => {
    function describeNode(
      description: string,
      create: () => UniversalSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType universal', () =>
          expect(node.sassType).toBe('universal'));

        it('has no namespace', () => expect(node.namespace).toBeUndefined());
      });
    }

    describeNode('parsed', () => parseSimpleSelector('*'));

    describeNode('constructed manually', () => new UniversalSelector());

    describeNode('from props', () =>
      fromSimpleSelectorProps({namespace: undefined}),
    );
  });

  describe('without interpolation', () => {
    function describeNode(
      description: string,
      create: () => UniversalSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType universal', () =>
          expect(node.sassType).toBe('universal'));

        it('has a namespace', () =>
          expect(node).toHaveInterpolation('namespace', 'foo'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('foo|*'));

    describeNode(
      'constructed manually',
      () => new UniversalSelector({namespace: 'foo'}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({namespace: 'foo'}),
    );
  });

  describe('with interpolation', () => {
    function describeNode(
      description: string,
      create: () => UniversalSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType universal', () =>
          expect(node.sassType).toBe('universal'));

        it('has a namespace', () =>
          expect(node.namespace).toHaveStringExpression(0, 'foo'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('#{foo}|*'));

    describeNode(
      'constructed manually',
      () => new UniversalSelector({namespace: [{text: 'foo'}]}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({namespace: [{text: 'foo'}]}),
    );
  });

  describe('assigned new namespace', () => {
    beforeEach(() => void (node = parseSimpleSelector('foo|*')));

    it("removes the old namespace's parent", () => {
      const oldNamespace = node.namespace;
      node.namespace = 'bar';
      expect(oldNamespace!.parent).toBeUndefined();
    });

    it('assigns namespace explicitly', () => {
      const namespace = new Interpolation('bar');
      node.namespace = namespace;
      expect(node.namespace).toBe(namespace);
      expect(node).toHaveInterpolation('namespace', 'bar');
    });

    it('assigns namespace as InterpolationProps', () => {
      node.namespace = 'bar';
      expect(node).toHaveInterpolation('namespace', 'bar');
    });

    it('assigns undefined namespace', () => {
      const oldNamespace = node.namespace;
      node.namespace = undefined;
      expect(oldNamespace!.parent).toBeUndefined();
      expect(node.namespace).toBeUndefined();
    });
  });

  describe('stringifies', () => {
    it('with no namespace', () =>
      expect(parseSimpleSelector('*').toString()).toBe('*'));

    it('with a namespace', () =>
      expect(parseSimpleSelector('foo|*').toString()).toBe('foo|*'));
  });

  describe('clone', () => {
    let original: UniversalSelector;

    beforeEach(() => {
      original = parseSimpleSelector('foo|*');
    });

    describe('with no overrides', () => {
      let clone: UniversalSelector;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('namespace', () =>
          expect(clone).toHaveInterpolation('namespace', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      it('creates a new self', () => expect(clone).not.toBe(original));
    });

    describe('overrides', () => {
      describe('namespace', () => {
        it('defined', () =>
          expect(original.clone({namespace: 'bar'})).toHaveInterpolation(
            'namespace',
            'bar',
          ));

        it('undefined', () =>
          expect(
            original.clone({namespace: undefined}).namespace,
          ).toBeUndefined());
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
    it('with no namespace', () =>
      expect(parseSimpleSelector('*')).toMatchSnapshot());

    it('with a namespace', () =>
      expect(parseSimpleSelector('foo|*')).toMatchSnapshot());
  });
});
