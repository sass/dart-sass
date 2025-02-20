// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {NullExpression} from '../..';
import * as utils from '../../../test/utils';

describe('a null expression', () => {
  let node: NullExpression;

  function describeNode(
    description: string,
    create: () => NullExpression,
  ): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has sassType null', () => expect(node.sassType).toBe('null'));

      it('has value null', () => expect(node.value).toBe(null));
    });
  }

  describeNode('parsed', () => utils.parseExpression('null'));

  describe('constructed manually', () => {
    describeNode('without props', () => new NullExpression());

    describeNode('with empty props', () => new NullExpression({}));

    describeNode('with value: null', () => new NullExpression({value: null}));
  });

  describeNode('constructed from ExpressionProps', () =>
    utils.fromExpressionProps({value: null}),
  );

  it('stringifies', () => expect(new NullExpression().toString()).toBe('null'));

  describe('clone', () => {
    let original: NullExpression;

    beforeEach(() => void (original = utils.parseExpression('null')));

    describe('with no overrides', () => {
      let clone: NullExpression;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('value', () => expect(clone.value).toBe(null));

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      it('creates a new self', () => expect(clone).not.toBe(original));
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {}}).raws).toEqual({}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({}));
      });
    });
  });

  it('toJSON', () => expect(utils.parseExpression('null')).toMatchSnapshot());
});
