// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {SelectorExpression} from '../..';
import * as utils from '../../../test/utils';

describe('a selector expression', () => {
  let node: SelectorExpression;

  function describeNode(
    description: string,
    create: () => SelectorExpression,
  ): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has sassType selector', () => expect(node.sassType).toBe('selector-expr'));
    });
  }

  describeNode('parsed', () => utils.parseExpression('&'));

  describe('constructed manually', () => {
    describeNode('without props', () => new SelectorExpression());

    describeNode('with empty props', () => new SelectorExpression({}));
  });

  it('stringifies', () => expect(new SelectorExpression().toString()).toBe('&'));

  describe('clone', () => {
    let original: SelectorExpression;

    beforeEach(() => void (original = utils.parseExpression('&')));

    describe('with no overrides', () => {
      let clone: SelectorExpression;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
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

  it('toJSON', () => expect(utils.parseExpression('&')).toMatchSnapshot());
});
