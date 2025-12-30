// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {IfConditionSass} from '../../..';
import * as utils from '../../../../test/utils';
import {BooleanExpression} from '../boolean';

describe('a Sass if() condition', () => {
  let node: IfConditionSass;
  beforeEach(() => {
    node = new IfConditionSass({value: true});
  });

  function describeNode(
    description: string,
    create: () => IfConditionSass,
  ): void {
    describe(description, () => {
      beforeEach(() => (node = create()));

      it('has a sassType', () =>
        expect(node.sassType.toString()).toBe('if-condition-sass'));

      it('has an expression', () =>
        expect(node).toHaveNode('expression', 'true', 'boolean'));
    });
  }

  describeNode('parsed', () => utils.parseIfConditionExpression('sass(true)'));

  describe('constructed manually', () => {
    describeNode(
      'with an Expression',
      () => new IfConditionSass(new BooleanExpression({value: true})),
    );

    describeNode(
      'with ExpressionProps',
      () => new IfConditionSass({value: true}),
    );

    describe('with an object', () => {
      describeNode(
        'with an Expression',
        () =>
          new IfConditionSass({
            expression: new BooleanExpression({value: true}),
          }),
      );

      describeNode(
        'with ExpressionProps',
        () => new IfConditionSass({expression: {value: true}}),
      );
    });
  });

  describe('constructed from IfConditionExpressionProps', () => {
    describeNode('with an Expression', () =>
      utils.fromIfConditionExpressionProps(
        new BooleanExpression({value: true}),
      ),
    );

    describeNode('with ExpressionProps', () =>
      utils.fromIfConditionExpressionProps({value: true}),
    );
  });

  it('assigned a new expression', () => {
    const old = node.expression;
    node.expression = {text: 'baz'};
    expect(old.parent).toBeUndefined();
    expect(node).toHaveStringExpression('expression', 'baz');
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () => expect(node.toString()).toBe('sass(true)'));

      it('with afterOpen', () => {
        node.raws.afterOpen = '  ';
        expect(node.toString()).toBe('sass(  true)');
      });

      it('with beforeClose', () => {
        node.raws.beforeClose = '  ';
        expect(node.toString()).toBe('sass(true  )');
      });
    });
  });

  describe('clone()', () => {
    beforeEach(() => {
      node.raws.afterOpen = '  ';
    });

    describe('with no overrides', () => {
      let clone: IfConditionSass;
      beforeEach(() => void (clone = node.clone()));

      describe('has the same properties:', () => {
        it('expression', () =>
          expect(clone).toHaveNode('expression', 'true', 'boolean'));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(node));

        for (const attr of ['expression', 'raws'] as const) {
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

      describe('expression', () => {
        it('defined', () =>
          expect(
            node.clone({expression: {text: 'baz'}}),
          ).toHaveStringExpression('expression', 'baz'));

        it('undefined', () =>
          expect(node.clone({expression: undefined})).toHaveNode(
            'expression',
            'true',
            'boolean',
          ));
      });
    });
  });

  it('toJSON', () =>
    expect(utils.parseIfConditionExpression('sass(true)')).toMatchSnapshot());
});
