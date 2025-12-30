// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  IfConditionParenthesized,
  IfConditionSass,
  VariableExpression,
} from '../../..';
import * as utils from '../../../../test/utils';
import {BooleanExpression} from '../boolean';

describe('a parenthesized if() condition', () => {
  let node: IfConditionParenthesized;
  beforeEach(() => {
    node = new IfConditionParenthesized({value: true});
  });

  function describeNode(
    description: string,
    create: () => IfConditionParenthesized,
  ): void {
    describe(description, () => {
      beforeEach(() => (node = create()));

      it('has a sassType', () =>
        expect(node.sassType.toString()).toBe('if-condition-parenthesized'));

      it('has a parenthesized', () =>
        expect(node).toHaveNode(
          'parenthesized',
          'sass(true)',
          'if-condition-sass',
        ));
    });
  }

  describeNode('parsed', () =>
    utils.parseIfConditionExpression('(sass(true))'),
  );

  describe('constructed manually', () => {
    describeNode(
      'with an IfConditionExpression',
      () => new IfConditionParenthesized(new IfConditionSass({value: true})),
    );

    describeNode(
      'with IfConditionExpressionProps',
      () => new IfConditionParenthesized({expression: {value: true}}),
    );

    describeNode(
      'with an Expression',
      () => new IfConditionParenthesized(new BooleanExpression({value: true})),
    );

    describeNode(
      'with ExpressionProps',
      () => new IfConditionParenthesized({value: true}),
    );

    describe('with an object', () => {
      describeNode(
        'with an IfConditionExpression',
        () =>
          new IfConditionParenthesized({
            parenthesized: new IfConditionSass({value: true}),
          }),
      );

      describeNode(
        'with IfConditionExpressionProps',
        () =>
          new IfConditionParenthesized({
            parenthesized: {expression: {value: true}},
          }),
      );

      describeNode(
        'with an Expression',
        () =>
          new IfConditionParenthesized({
            parenthesized: new BooleanExpression({value: true}),
          }),
      );

      describeNode(
        'with ExpressionProps',
        () => new IfConditionParenthesized({parenthesized: {value: true}}),
      );
    });
  });

  describe('constructed from IfConditionExpressionProps', () => {
    describeNode('with an IfConditionExpression', () =>
      utils.fromIfConditionExpressionProps({
        parenthesized: new IfConditionSass({value: true}),
      }),
    );

    describeNode('with IfConditionExpressionProps', () =>
      utils.fromIfConditionExpressionProps({
        parenthesized: {expression: {value: true}},
      }),
    );

    describeNode('with an Expression', () =>
      utils.fromIfConditionExpressionProps({
        parenthesized: new BooleanExpression({value: true}),
      }),
    );

    describeNode('with ExpressionProps', () =>
      utils.fromIfConditionExpressionProps({parenthesized: {value: true}}),
    );
  });

  describe('assigned a new parenthesized', () => {
    it('IfConditionExpression', () => {
      const old = node.parenthesized;
      const condition = new IfConditionSass({variableName: 'baz'});
      node.parenthesized = condition;
      expect(old.parent).toBeUndefined();
      expect(node.parenthesized).toBe(condition);
      expect(node).toHaveNode('parenthesized', 'sass($baz)');
    });

    it('IfConditionExpressionProps', () => {
      const old = node.parenthesized;
      node.parenthesized = {expression: {variableName: 'baz'}};
      expect(old.parent).toBeUndefined();
      expect(node).toHaveNode('parenthesized', 'sass($baz)');
    });

    it('Expression', () => {
      const old = node.parenthesized;
      const condition = new VariableExpression({variableName: 'baz'});
      node.parenthesized = condition;
      expect(old.parent).toBeUndefined();
      expect((node.parenthesized as IfConditionSass).expression).toBe(
        condition,
      );
      expect(node).toHaveNode('parenthesized', 'sass($baz)');
    });

    it('ExpressionProps', () => {
      const old = node.parenthesized;
      node.parenthesized = {variableName: 'baz'};
      expect(old.parent).toBeUndefined();
      expect(node).toHaveNode('parenthesized', 'sass($baz)');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(node.toString()).toBe('(sass(true))'));

      it('with afterOpen', () => {
        node.raws.afterOpen = '  ';
        expect(node.toString()).toBe('(  sass(true))');
      });

      it('with beforeClose', () => {
        node.raws.beforeClose = '  ';
        expect(node.toString()).toBe('(sass(true)  )');
      });
    });
  });

  describe('clone()', () => {
    beforeEach(() => {
      node.raws.afterOpen = '  ';
    });

    describe('with no overrides', () => {
      let clone: IfConditionParenthesized;
      beforeEach(() => void (clone = node.clone()));

      describe('has the same properties:', () => {
        it('parenthesized', () =>
          expect(clone).toHaveNode(
            'parenthesized',
            'sass(true)',
            'if-condition-sass',
          ));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(node));

        for (const attr of ['parenthesized', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(node[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(node.clone({raws: {beforeClose: '  '}}).raws).toEqual({
            beforeClose: '  ',
          }));

        it('undefined', () =>
          expect(node.clone({raws: undefined}).raws).toEqual({
            afterOpen: '  ',
          }));
      });

      describe('parenthesized', () => {
        it('defined', () =>
          expect(node.clone({parenthesized: {variableName: 'baz'}})).toHaveNode(
            'parenthesized',
            'sass($baz)',
            'if-condition-sass',
          ));

        it('undefined', () =>
          expect(node.clone({parenthesized: undefined})).toHaveNode(
            'parenthesized',
            'sass(true)',
            'if-condition-sass',
          ));
      });
    });
  });

  it('toJSON', () =>
    expect(utils.parseIfConditionExpression('(sass(true))')).toMatchSnapshot());
});
