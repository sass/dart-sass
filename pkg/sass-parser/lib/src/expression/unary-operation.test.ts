// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {StringExpression, UnaryOperationExpression} from '../..';
import * as utils from '../../../test/utils';

describe('a unary operation', () => {
  let node: UnaryOperationExpression;
  function describeNode(
    description: string,
    create: () => UnaryOperationExpression,
  ): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has sassType unary-operation', () =>
        expect(node.sassType).toBe('unary-operation'));

      it('has an operator', () => expect(node.operator).toBe('+'));

      it('has an operand', () =>
        expect(node).toHaveStringExpression('operand', 'foo'));
    });
  }

  describeNode('parsed', () => utils.parseExpression('+foo'));

  describeNode(
    'constructed manually',
    () =>
      new UnaryOperationExpression({
        operator: '+',
        operand: {text: 'foo'},
      }),
  );

  describeNode('constructed from ExpressionProps', () =>
    utils.fromExpressionProps({
      operator: '+',
      operand: {text: 'foo'},
    }),
  );

  describe('assigned new', () => {
    beforeEach(() => void (node = utils.parseExpression('+foo')));

    it('operator', () => {
      node.operator = 'not';
      expect(node.operator).toBe('not');
    });

    describe('operand', () => {
      it("removes the old operand's parent", () => {
        const oldOperand = node.operand;
        node.operand = {text: 'zip'};
        expect(oldOperand.parent).toBeUndefined();
      });

      it('assigns operand explicitly', () => {
        const operand = new StringExpression({text: 'zip'});
        node.operand = operand;
        expect(node.operand).toBe(operand);
        expect(node).toHaveStringExpression('operand', 'zip');
      });

      it('assigns operand as ExpressionProps', () => {
        node.operand = {text: 'zip'};
        expect(node).toHaveStringExpression('operand', 'zip');
      });
    });
  });

  describe('stringifies', () => {
    describe('plus', () => {
      describe('with an identifier', () => {
        beforeEach(
          () =>
            void (node = new UnaryOperationExpression({
              operator: '+',
              operand: {text: 'foo'},
            })),
        );

        it('without raws', () => expect(node.toString()).toBe('+foo'));

        it('with between', () => {
          node.raws.between = '/**/';
          expect(node.toString()).toBe('+/**/foo');
        });
      });

      describe('with a number', () => {
        beforeEach(
          () =>
            void (node = new UnaryOperationExpression({
              operator: '+',
              operand: {value: 0},
            })),
        );

        it('without raws', () => expect(node.toString()).toBe('+ 0'));

        it('with between', () => {
          node.raws.between = '/**/';
          expect(node.toString()).toBe('+/**/0');
        });
      });
    });

    describe('not', () => {
      beforeEach(
        () =>
          void (node = new UnaryOperationExpression({
            operator: 'not',
            operand: {text: 'foo'},
          })),
      );

      it('without raws', () => expect(node.toString()).toBe('not foo'));

      it('with between', () => {
        node.raws.between = '/**/';
        expect(node.toString()).toBe('not/**/foo');
      });
    });

    describe('minus', () => {
      describe('with an identifier', () => {
        beforeEach(
          () =>
            void (node = new UnaryOperationExpression({
              operator: '-',
              operand: {text: 'foo'},
            })),
        );

        it('without raws', () => expect(node.toString()).toBe('- foo'));

        it('with between', () => {
          node.raws.between = '/**/';
          expect(node.toString()).toBe('-/**/foo');
        });
      });

      describe('with a number', () => {
        beforeEach(
          () =>
            void (node = new UnaryOperationExpression({
              operator: '-',
              operand: {value: 0},
            })),
        );

        it('without raws', () => expect(node.toString()).toBe('- 0'));

        it('with between', () => {
          node.raws.between = '/**/';
          expect(node.toString()).toBe('-/**/0');
        });
      });

      describe('with a function call', () => {
        beforeEach(
          () =>
            void (node = new UnaryOperationExpression({
              operator: '-',
              operand: {name: 'foo', arguments: []},
            })),
        );

        it('without raws', () => expect(node.toString()).toBe('- foo()'));

        it('with between', () => {
          node.raws.between = '/**/';
          expect(node.toString()).toBe('-/**/foo()');
        });
      });

      describe('with a parenthesized expression', () => {
        beforeEach(
          () =>
            void (node = new UnaryOperationExpression({
              operator: '-',
              operand: {inParens: {text: 'foo'}},
            })),
        );

        it('without raws', () => expect(node.toString()).toBe('-(foo)'));

        it('with between', () => {
          node.raws.between = '/**/';
          expect(node.toString()).toBe('-/**/(foo)');
        });
      });
    });
  });

  describe('clone', () => {
    let original: UnaryOperationExpression;
    beforeEach(() => {
      original = utils.parseExpression('+foo');
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: UnaryOperationExpression;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('operator', () => expect(clone.operator).toBe('+'));

        it('operand', () =>
          expect(clone).toHaveStringExpression('operand', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['operand', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('operator', () => {
        it('defined', () =>
          expect(original.clone({operator: '-'}).operator).toBe('-'));

        it('undefined', () =>
          expect(original.clone({operator: undefined}).operator).toBe('+'));
      });

      describe('operand', () => {
        it('defined', () =>
          expect(
            original.clone({operand: {text: 'zip'}}),
          ).toHaveStringExpression('operand', 'zip'));

        it('undefined', () =>
          expect(original.clone({operand: undefined})).toHaveStringExpression(
            'operand',
            'foo',
          ));
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {between: '/**/'}}).raws).toEqual({
            between: '/**/',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            between: '  ',
          }));
      });
    });
  });

  it('toJSON', () => expect(utils.parseExpression('+foo')).toMatchSnapshot());
});
