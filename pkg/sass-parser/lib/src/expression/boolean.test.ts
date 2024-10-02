// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {BooleanExpression} from '../..';
import * as utils from '../../../test/utils';

describe('a boolean expression', () => {
  let node: BooleanExpression;

  describe('true', () => {
    function describeNode(
      description: string,
      create: () => BooleanExpression
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType boolean', () => expect(node.sassType).toBe('boolean'));

        it('is true', () => expect(node.value).toBe(true));
      });
    }

    describeNode('parsed', () => utils.parseExpression('true'));

    describeNode(
      'constructed manually',
      () =>
        new BooleanExpression({
          value: true,
        })
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({
        value: true,
      })
    );
  });

  describe('false', () => {
    function describeNode(
      description: string,
      create: () => BooleanExpression
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType boolean', () => expect(node.sassType).toBe('boolean'));

        it('is false', () => expect(node.value).toBe(false));
      });
    }

    describeNode('parsed', () => utils.parseExpression('false'));

    describeNode(
      'constructed manually',
      () =>
        new BooleanExpression({
          value: false,
        })
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({
        value: false,
      })
    );
  });

  describe('assigned new', () => {
    beforeEach(() => void (node = utils.parseExpression('true')));

    it('value', () => {
      node.value = false;
      expect(node.value).toBe(false);
    });
  });

  describe('stringifies', () => {
    it('true', () => {
      expect(utils.parseExpression('true').toString()).toBe('true');
    });

    it('false', () => {
      expect(utils.parseExpression('false').toString()).toBe('false');
    });
  });

  describe('clone', () => {
    let original: BooleanExpression;

    beforeEach(() => {
      original = utils.parseExpression('true');
    });

    describe('with no overrides', () => {
      let clone: BooleanExpression;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('value', () => expect(clone.value).toBe(true));

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));
      });
    });

    describe('overrides', () => {
      describe('value', () => {
        it('defined', () =>
          expect(original.clone({value: false}).value).toBe(false));

        it('undefined', () =>
          expect(original.clone({value: undefined}).value).toBe(true));
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {}}).raws).toEqual({}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({}));
      });
    });
  });

  it('toJSON', () => expect(utils.parseExpression('true')).toMatchSnapshot());
});
