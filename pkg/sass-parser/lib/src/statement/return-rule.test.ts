// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {FunctionRule, ReturnRule, StringExpression, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a @return rule', () => {
  let node: ReturnRule;
  function describeNode(description: string, create: () => ReturnRule): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has a name', () => expect(node.name.toString()).toBe('return'));

      it('has an expression', () =>
        expect(node).toHaveStringExpression('returnExpression', 'foo'));

      it('has matching params', () => expect(node.params).toBe('foo'));

      it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
    });
  }

  describeNode(
    'parsed as SCSS',
    () =>
      (scss.parse('@function x() {@return foo}').nodes[0] as FunctionRule)
        .nodes[0] as ReturnRule,
  );

  describeNode(
    'parsed as Sass',
    () =>
      (sass.parse('@function x()\n  @return foo').nodes[0] as FunctionRule)
        .nodes[0] as ReturnRule,
  );

  describeNode(
    'constructed manually',
    () =>
      new ReturnRule({
        returnExpression: {text: 'foo'},
      }),
  );

  describeNode('constructed from ChildProps', () =>
    utils.fromChildProps({
      returnExpression: {text: 'foo'},
    }),
  );

  it('throws an error when assigned a new name', () =>
    expect(
      () =>
        (new ReturnRule({
          returnExpression: {text: 'foo'},
        }).name = 'bar'),
    ).toThrow());

  describe('assigned a new expression', () => {
    beforeEach(() => {
      node = (
        scss.parse('@function x() {@return foo}').nodes[0] as FunctionRule
      ).nodes[0] as ReturnRule;
    });

    it('sets an empty string expression as undefined params', () => {
      node.params = undefined;
      expect(node.params).toBe('');
      expect(node).toHaveStringExpression('returnExpression', '');
    });

    it('sets an empty string expression as empty string params', () => {
      node.params = '';
      expect(node.params).toBe('');
      expect(node).toHaveStringExpression('returnExpression', '');
    });

    it("removes the old expression's parent", () => {
      const oldExpression = node.returnExpression;
      node.returnExpression = {text: 'bar'};
      expect(oldExpression.parent).toBeUndefined();
    });

    it("assigns the new expression's parent", () => {
      const expression = new StringExpression({text: 'bar'});
      node.returnExpression = expression;
      expect(expression.parent).toBe(node);
    });

    it('assigns the expression explicitly', () => {
      const expression = new StringExpression({text: 'bar'});
      node.returnExpression = expression;
      expect(node.returnExpression).toBe(expression);
    });

    it('assigns the expression as ExpressionProps', () => {
      node.returnExpression = {text: 'bar'};
      expect(node).toHaveStringExpression('returnExpression', 'bar');
    });

    it('assigns the expression as params', () => {
      node.params = 'bar';
      expect(node).toHaveStringExpression('returnExpression', 'bar');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(
          new ReturnRule({
            returnExpression: {text: 'foo'},
          }).toString(),
        ).toBe('@return foo'));

      it('with afterName', () =>
        expect(
          new ReturnRule({
            returnExpression: {text: 'foo'},
            raws: {afterName: '/**/'},
          }).toString(),
        ).toBe('@return/**/foo'));

      it('with between', () =>
        expect(
          new ReturnRule({
            returnExpression: {text: 'foo'},
            raws: {between: '/**/'},
          }).toString(),
        ).toBe('@return foo/**/'));
    });
  });

  describe('clone', () => {
    let original: ReturnRule;
    beforeEach(() => {
      original = (
        scss.parse('@function x() {@return foo}').nodes[0] as FunctionRule
      ).nodes[0] as ReturnRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: ReturnRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('foo'));

        it('returnExpression', () =>
          expect(clone).toHaveStringExpression('returnExpression', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['returnExpression', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {afterName: '  '}}).raws).toEqual({
            afterName: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            between: '  ',
          }));
      });

      describe('returnExpression', () => {
        describe('defined', () => {
          let clone: ReturnRule;
          beforeEach(() => {
            clone = original.clone({returnExpression: {text: 'bar'}});
          });

          it('changes params', () => expect(clone.params).toBe('bar'));

          it('changes returnExpression', () =>
            expect(clone).toHaveStringExpression('returnExpression', 'bar'));
        });

        describe('undefined', () => {
          let clone: ReturnRule;
          beforeEach(() => {
            clone = original.clone({returnExpression: undefined});
          });

          it('preserves params', () => expect(clone.params).toBe('foo'));

          it('preserves returnExpression', () =>
            expect(clone).toHaveStringExpression('returnExpression', 'foo'));
        });
      });
    });
  });

  it('toJSON', () =>
    expect(
      (scss.parse('@function x() {@return foo}').nodes[0] as FunctionRule)
        .nodes[0],
    ).toMatchSnapshot());
});
