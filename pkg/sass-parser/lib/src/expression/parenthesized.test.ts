// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {ParenthesizedExpression, StringExpression} from '../..';
import * as utils from '../../../test/utils';

describe('a parenthesized expression', () => {
  let node: ParenthesizedExpression;
  function describeNode(
    description: string,
    create: () => ParenthesizedExpression,
  ): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has sassType parenthesized', () =>
        expect(node.sassType).toBe('parenthesized'));

      it('has an expression', () =>
        expect(node).toHaveStringExpression('inParens', 'foo'));
    });
  }

  describeNode('parsed', () => utils.parseExpression('(foo)'));

  describeNode(
    'constructed manually',
    () => new ParenthesizedExpression({inParens: {text: 'foo'}}),
  );

  describeNode('constructed from ExpressionProps', () =>
    utils.fromExpressionProps({inParens: {text: 'foo'}}),
  );

  describe('assigned new', () => {
    beforeEach(() => void (node = utils.parseExpression('(foo)')));

    describe('expression', () => {
      it("removes the old expression's parent", () => {
        const oldInParens = node.inParens;
        node.inParens = {text: 'zip'};
        expect(oldInParens.parent).toBeUndefined();
      });

      it('assigns the expression explicitly', () => {
        const inParens = new StringExpression({text: 'zip'});
        node.inParens = inParens;
        expect(node.inParens).toBe(inParens);
        expect(node).toHaveStringExpression('inParens', 'zip');
      });

      it('assigns the expression as ExpressionProps', () => {
        node.inParens = {text: 'zip'};
        expect(node).toHaveStringExpression('inParens', 'zip');
      });
    });
  });

  describe('stringifies', () => {
    beforeEach(() => void (node = utils.parseExpression('(foo)')));

    it('without raws', () => expect(node.toString()).toBe('(foo)'));

    it('with afterOpen', () => {
      node.raws.afterOpen = '/**/';
      expect(node.toString()).toBe('(/**/foo)');
    });

    it('with beforeClose', () => {
      node.raws.beforeClose = '/**/';
      expect(node.toString()).toBe('(foo/**/)');
    });
  });

  describe('clone', () => {
    let original: ParenthesizedExpression;
    beforeEach(() => {
      original = utils.parseExpression('(foo)');
      // TODO: remove this once raws are properly parsed
      original.raws.afterOpen = '  ';
    });

    describe('with no overrides', () => {
      let clone: ParenthesizedExpression;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('inParens', () =>
          expect(clone).toHaveStringExpression('inParens', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({afterOpen: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['inParens', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('inParens', () => {
        it('defined', () =>
          expect(
            original.clone({inParens: {text: 'zip'}}),
          ).toHaveStringExpression('inParens', 'zip'));

        it('undefined', () =>
          expect(original.clone({inParens: undefined})).toHaveStringExpression(
            'inParens',
            'foo',
          ));
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {beforeClose: '  '}}).raws).toEqual({
            beforeClose: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            afterOpen: '  ',
          }));
      });
    });
  });

  it('toJSON', () => expect(utils.parseExpression('(foo)')).toMatchSnapshot());
});
