// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {BinaryOperationExpression, StringExpression} from '../..';
import * as utils from '../../../test/utils';

describe('a binary operation', () => {
  let node: BinaryOperationExpression;
  function describeNode(
    description: string,
    create: () => BinaryOperationExpression
  ): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has sassType binary-operation', () =>
        expect(node.sassType).toBe('binary-operation'));

      it('has an operator', () => expect(node.operator).toBe('+'));

      it('has a left node', () =>
        expect(node).toHaveStringExpression('left', 'foo'));

      it('has a right node', () =>
        expect(node).toHaveStringExpression('right', 'bar'));
    });
  }

  describeNode('parsed', () => utils.parseExpression('foo + bar'));

  describeNode(
    'constructed manually',
    () =>
      new BinaryOperationExpression({
        operator: '+',
        left: {text: 'foo'},
        right: {text: 'bar'},
      })
  );

  describeNode('constructed from ExpressionProps', () =>
    utils.fromExpressionProps({
      operator: '+',
      left: {text: 'foo'},
      right: {text: 'bar'},
    })
  );

  describe('assigned new', () => {
    beforeEach(() => void (node = utils.parseExpression('foo + bar')));

    it('operator', () => {
      node.operator = '*';
      expect(node.operator).toBe('*');
    });

    describe('left', () => {
      it("removes the old left's parent", () => {
        const oldLeft = node.left;
        node.left = {text: 'zip'};
        expect(oldLeft.parent).toBeUndefined();
      });

      it('assigns left explicitly', () => {
        const left = new StringExpression({text: 'zip'});
        node.left = left;
        expect(node.left).toBe(left);
        expect(node).toHaveStringExpression('left', 'zip');
      });

      it('assigns left as ExpressionProps', () => {
        node.left = {text: 'zip'};
        expect(node).toHaveStringExpression('left', 'zip');
      });
    });

    describe('right', () => {
      it("removes the old right's parent", () => {
        const oldRight = node.right;
        node.right = {text: 'zip'};
        expect(oldRight.parent).toBeUndefined();
      });

      it('assigns right explicitly', () => {
        const right = new StringExpression({text: 'zip'});
        node.right = right;
        expect(node.right).toBe(right);
        expect(node).toHaveStringExpression('right', 'zip');
      });

      it('assigns right as ExpressionProps', () => {
        node.right = {text: 'zip'};
        expect(node).toHaveStringExpression('right', 'zip');
      });
    });
  });

  describe('stringifies', () => {
    beforeEach(() => void (node = utils.parseExpression('foo + bar')));

    it('without raws', () => expect(node.toString()).toBe('foo + bar'));

    it('with beforeOperator', () => {
      node.raws.beforeOperator = '/**/';
      expect(node.toString()).toBe('foo/**/+ bar');
    });

    it('with afterOperator', () => {
      node.raws.afterOperator = '/**/';
      expect(node.toString()).toBe('foo +/**/bar');
    });
  });

  describe('clone', () => {
    let original: BinaryOperationExpression;
    beforeEach(() => {
      original = utils.parseExpression('foo + bar');
      // TODO: remove this once raws are properly parsed
      original.raws.beforeOperator = '  ';
    });

    describe('with no overrides', () => {
      let clone: BinaryOperationExpression;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('operator', () => expect(clone.operator).toBe('+'));

        it('left', () => expect(clone).toHaveStringExpression('left', 'foo'));

        it('right', () => expect(clone).toHaveStringExpression('right', 'bar'));

        it('raws', () => expect(clone.raws).toEqual({beforeOperator: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['left', 'right', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('operator', () => {
        it('defined', () =>
          expect(original.clone({operator: '*'}).operator).toBe('*'));

        it('undefined', () =>
          expect(original.clone({operator: undefined}).operator).toBe('+'));
      });

      describe('left', () => {
        it('defined', () =>
          expect(original.clone({left: {text: 'zip'}})).toHaveStringExpression(
            'left',
            'zip'
          ));

        it('undefined', () =>
          expect(original.clone({left: undefined})).toHaveStringExpression(
            'left',
            'foo'
          ));
      });

      describe('right', () => {
        it('defined', () =>
          expect(original.clone({right: {text: 'zip'}})).toHaveStringExpression(
            'right',
            'zip'
          ));

        it('undefined', () =>
          expect(original.clone({right: undefined})).toHaveStringExpression(
            'right',
            'bar'
          ));
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {afterOperator: '  '}}).raws).toEqual({
            afterOperator: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            beforeOperator: '  ',
          }));
      });
    });
  });

  it('toJSON', () =>
    expect(utils.parseExpression('foo + bar')).toMatchSnapshot());
});
