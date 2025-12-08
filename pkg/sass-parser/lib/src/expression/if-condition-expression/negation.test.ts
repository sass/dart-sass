// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  IfConditionNegation,
  IfConditionSass,
  VariableExpression,
} from '../../..';
import * as utils from '../../../../test/utils';
import {BooleanExpression} from '../boolean';

describe('an if() condition negatoin', () => {
  let node: IfConditionNegation;
  beforeEach(() => {
    node = new IfConditionNegation({value: true});
  });

  function describeNode(
    description: string,
    create: () => IfConditionNegation,
  ): void {
    describe(description, () => {
      beforeEach(() => (node = create()));

      it('has a sassType', () =>
        expect(node.sassType.toString()).toBe('if-condition-negation'));

      it('has a negated', () =>
        expect(node).toHaveNode('negated', 'sass(true)', 'if-condition-sass'));
    });
  }

  describeNode('parsed', () =>
    utils.parseIfConditionExpression('not sass(true)'),
  );

  describe('constructed manually', () => {
    describeNode(
      'with an IfConditionExpression',
      () => new IfConditionNegation(new IfConditionSass({value: true})),
    );

    describeNode(
      'with IfConditionExpressionProps',
      () => new IfConditionNegation({expression: {value: true}}),
    );

    describeNode(
      'with an Expression',
      () => new IfConditionNegation(new BooleanExpression({value: true})),
    );

    describeNode(
      'with ExpressionProps',
      () => new IfConditionNegation({value: true}),
    );

    describe('with an object', () => {
      describeNode(
        'with an IfConditionExpression',
        () =>
          new IfConditionNegation({
            negated: new IfConditionSass({value: true}),
          }),
      );

      describeNode(
        'with IfConditionExpressionProps',
        () =>
          new IfConditionNegation({
            negated: {expression: {value: true}},
          }),
      );

      describeNode(
        'with an Expression',
        () =>
          new IfConditionNegation({
            negated: new BooleanExpression({value: true}),
          }),
      );

      describeNode(
        'with ExpressionProps',
        () => new IfConditionNegation({negated: {value: true}}),
      );
    });
  });

  describe('constructed from IfConditionExpressionProps', () => {
    describeNode('with an IfConditionExpression', () =>
      utils.fromIfConditionExpressionProps({
        negated: new IfConditionSass({value: true}),
      }),
    );

    describeNode('with IfConditionExpressionProps', () =>
      utils.fromIfConditionExpressionProps({
        negated: {expression: {value: true}},
      }),
    );

    describeNode('with an Expression', () =>
      utils.fromIfConditionExpressionProps({
        negated: new BooleanExpression({value: true}),
      }),
    );

    describeNode('with ExpressionProps', () =>
      utils.fromIfConditionExpressionProps({negated: {value: true}}),
    );
  });

  describe('assigned a new negated', () => {
    it('IfConditionExpression', () => {
      const old = node.negated;
      const condition = new IfConditionSass({variableName: 'baz'});
      node.negated = condition;
      expect(old.parent).toBeUndefined();
      expect(node.negated).toBe(condition);
      expect(node).toHaveNode('negated', 'sass($baz)');
    });

    it('IfConditionExpressionProps', () => {
      const old = node.negated;
      node.negated = {expression: {variableName: 'baz'}};
      expect(old.parent).toBeUndefined();
      expect(node).toHaveNode('negated', 'sass($baz)');
    });

    it('Expression', () => {
      const old = node.negated;
      const condition = new VariableExpression({variableName: 'baz'});
      node.negated = condition;
      expect(old.parent).toBeUndefined();
      expect((node.negated as IfConditionSass).expression).toBe(condition);
      expect(node).toHaveNode('negated', 'sass($baz)');
    });

    it('ExpressionProps', () => {
      const old = node.negated;
      node.negated = {variableName: 'baz'};
      expect(old.parent).toBeUndefined();
      expect(node).toHaveNode('negated', 'sass($baz)');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(node.toString()).toBe('not sass(true)'));

      it('with not', () => {
        node.raws.not = 'NOT';
        expect(node.toString()).toBe('NOT sass(true)');
      });

      it('with beforeClose', () => {
        node.raws.between = '  ';
        expect(node.toString()).toBe('not  sass(true)');
      });
    });
  });

  describe('clone()', () => {
    beforeEach(() => {
      node.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: IfConditionNegation;
      beforeEach(() => void (clone = node.clone()));

      describe('has the same properties:', () => {
        it('negated', () =>
          expect(clone).toHaveNode(
            'negated',
            'sass(true)',
            'if-condition-sass',
          ));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(node));

        for (const attr of ['negated', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(node[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(node.clone({raws: {not: 'NOT'}}).raws).toEqual({
            not: 'NOT',
          }));

        it('undefined', () =>
          expect(node.clone({raws: undefined}).raws).toEqual({
            between: '  ',
          }));
      });

      describe('negated', () => {
        it('defined', () =>
          expect(node.clone({negated: {variableName: 'baz'}})).toHaveNode(
            'negated',
            'sass($baz)',
            'if-condition-sass',
          ));

        it('undefined', () =>
          expect(node.clone({negated: undefined})).toHaveNode(
            'negated',
            'sass(true)',
            'if-condition-sass',
          ));
      });
    });
  });

  it('toJSON', () =>
    expect(
      utils.parseIfConditionExpression('not sass(true)'),
    ).toMatchSnapshot());
});
