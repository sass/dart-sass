// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {ErrorRule, StringExpression, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a @error rule', () => {
  let node: ErrorRule;
  function describeNode(description: string, create: () => ErrorRule): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has a name', () => expect(node.name.toString()).toBe('error'));

      it('has an expression', () =>
        expect(node).toHaveStringExpression('errorExpression', 'foo'));

      it('has matching params', () => expect(node.params).toBe('foo'));

      it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
    });
  }

  describeNode(
    'parsed as SCSS',
    () => scss.parse('@error foo').nodes[0] as ErrorRule
  );

  describeNode(
    'parsed as Sass',
    () => sass.parse('@error foo').nodes[0] as ErrorRule
  );

  describeNode(
    'constructed manually',
    () =>
      new ErrorRule({
        errorExpression: {text: 'foo'},
      })
  );

  describeNode('constructed from ChildProps', () =>
    utils.fromChildProps({
      errorExpression: {text: 'foo'},
    })
  );

  it('throws an error when assigned a new name', () =>
    expect(
      () =>
        (new ErrorRule({
          errorExpression: {text: 'foo'},
        }).name = 'bar')
    ).toThrow());

  describe('assigned a new expression', () => {
    beforeEach(() => {
      node = scss.parse('@error foo').nodes[0] as ErrorRule;
    });

    it('sets an empty string expression as undefined params', () => {
      node.params = undefined;
      expect(node.params).toBe('');
      expect(node).toHaveStringExpression('errorExpression', '');
    });

    it('sets an empty string expression as empty string params', () => {
      node.params = '';
      expect(node.params).toBe('');
      expect(node).toHaveStringExpression('errorExpression', '');
    });

    it("removes the old expression's parent", () => {
      const oldExpression = node.errorExpression;
      node.errorExpression = {text: 'bar'};
      expect(oldExpression.parent).toBeUndefined();
    });

    it("assigns the new expression's parent", () => {
      const expression = new StringExpression({text: 'bar'});
      node.errorExpression = expression;
      expect(expression.parent).toBe(node);
    });

    it('assigns the expression explicitly', () => {
      const expression = new StringExpression({text: 'bar'});
      node.errorExpression = expression;
      expect(node.errorExpression).toBe(expression);
    });

    it('assigns the expression as ExpressionProps', () => {
      node.errorExpression = {text: 'bar'};
      expect(node).toHaveStringExpression('errorExpression', 'bar');
    });

    it('assigns the expression as params', () => {
      node.params = 'bar';
      expect(node).toHaveStringExpression('errorExpression', 'bar');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(
          new ErrorRule({
            errorExpression: {text: 'foo'},
          }).toString()
        ).toBe('@error foo;'));

      it('with afterName', () =>
        expect(
          new ErrorRule({
            errorExpression: {text: 'foo'},
            raws: {afterName: '/**/'},
          }).toString()
        ).toBe('@error/**/foo;'));

      it('with between', () =>
        expect(
          new ErrorRule({
            errorExpression: {text: 'foo'},
            raws: {between: '/**/'},
          }).toString()
        ).toBe('@error foo/**/;'));
    });
  });

  describe('clone', () => {
    let original: ErrorRule;
    beforeEach(() => {
      original = scss.parse('@error foo').nodes[0] as ErrorRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: ErrorRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('foo'));

        it('errorExpression', () =>
          expect(clone).toHaveStringExpression('errorExpression', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['errorExpression', 'raws'] as const) {
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

      describe('errorExpression', () => {
        describe('defined', () => {
          let clone: ErrorRule;
          beforeEach(() => {
            clone = original.clone({errorExpression: {text: 'bar'}});
          });

          it('changes params', () => expect(clone.params).toBe('bar'));

          it('changes errorExpression', () =>
            expect(clone).toHaveStringExpression('errorExpression', 'bar'));
        });

        describe('undefined', () => {
          let clone: ErrorRule;
          beforeEach(() => {
            clone = original.clone({errorExpression: undefined});
          });

          it('preserves params', () => expect(clone.params).toBe('foo'));

          it('preserves errorExpression', () =>
            expect(clone).toHaveStringExpression('errorExpression', 'foo'));
        });
      });
    });
  });

  it('toJSON', () =>
    expect(scss.parse('@error foo').nodes[0]).toMatchSnapshot());
});
