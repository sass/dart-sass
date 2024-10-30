// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {DebugRule, StringExpression, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a @debug rule', () => {
  let node: DebugRule;
  function describeNode(description: string, create: () => DebugRule): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has a name', () => expect(node.name.toString()).toBe('debug'));

      it('has an expression', () =>
        expect(node).toHaveStringExpression('debugExpression', 'foo'));

      it('has matching params', () => expect(node.params).toBe('foo'));

      it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
    });
  }

  describeNode(
    'parsed as SCSS',
    () => scss.parse('@debug foo').nodes[0] as DebugRule
  );

  describeNode(
    'parsed as Sass',
    () => sass.parse('@debug foo').nodes[0] as DebugRule
  );

  describeNode(
    'constructed manually',
    () =>
      new DebugRule({
        debugExpression: {text: 'foo'},
      })
  );

  describeNode('constructed from ChildProps', () =>
    utils.fromChildProps({
      debugExpression: {text: 'foo'},
    })
  );

  it('throws an error when assigned a new name', () =>
    expect(
      () =>
        (new DebugRule({
          debugExpression: {text: 'foo'},
        }).name = 'bar')
    ).toThrow());

  describe('assigned a new expression', () => {
    beforeEach(() => {
      node = scss.parse('@debug foo').nodes[0] as DebugRule;
    });

    it('sets an empty string expression as undefined params', () => {
      node.params = undefined;
      expect(node.params).toBe('');
      expect(node).toHaveStringExpression('debugExpression', '');
    });

    it('sets an empty string expression as empty string params', () => {
      node.params = '';
      expect(node.params).toBe('');
      expect(node).toHaveStringExpression('debugExpression', '');
    });

    it("removes the old expression's parent", () => {
      const oldExpression = node.debugExpression;
      node.debugExpression = {text: 'bar'};
      expect(oldExpression.parent).toBeUndefined();
    });

    it("assigns the new expression's parent", () => {
      const expression = new StringExpression({text: 'bar'});
      node.debugExpression = expression;
      expect(expression.parent).toBe(node);
    });

    it('assigns the expression explicitly', () => {
      const expression = new StringExpression({text: 'bar'});
      node.debugExpression = expression;
      expect(node.debugExpression).toBe(expression);
    });

    it('assigns the expression as ExpressionProps', () => {
      node.debugExpression = {text: 'bar'};
      expect(node).toHaveStringExpression('debugExpression', 'bar');
    });

    it('assigns the expression as params', () => {
      node.params = 'bar';
      expect(node).toHaveStringExpression('debugExpression', 'bar');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(
          new DebugRule({
            debugExpression: {text: 'foo'},
          }).toString()
        ).toBe('@debug foo;'));

      it('with afterName', () =>
        expect(
          new DebugRule({
            debugExpression: {text: 'foo'},
            raws: {afterName: '/**/'},
          }).toString()
        ).toBe('@debug/**/foo;'));

      it('with between', () =>
        expect(
          new DebugRule({
            debugExpression: {text: 'foo'},
            raws: {between: '/**/'},
          }).toString()
        ).toBe('@debug foo/**/;'));
    });
  });

  describe('clone', () => {
    let original: DebugRule;
    beforeEach(() => {
      original = scss.parse('@debug foo').nodes[0] as DebugRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: DebugRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('foo'));

        it('debugExpression', () =>
          expect(clone).toHaveStringExpression('debugExpression', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['debugExpression', 'raws'] as const) {
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

      describe('debugExpression', () => {
        describe('defined', () => {
          let clone: DebugRule;
          beforeEach(() => {
            clone = original.clone({debugExpression: {text: 'bar'}});
          });

          it('changes params', () => expect(clone.params).toBe('bar'));

          it('changes debugExpression', () =>
            expect(clone).toHaveStringExpression('debugExpression', 'bar'));
        });

        describe('undefined', () => {
          let clone: DebugRule;
          beforeEach(() => {
            clone = original.clone({debugExpression: undefined});
          });

          it('preserves params', () => expect(clone.params).toBe('foo'));

          it('preserves debugExpression', () =>
            expect(clone).toHaveStringExpression('debugExpression', 'foo'));
        });
      });
    });
  });

  it('toJSON', () =>
    expect(scss.parse('@debug foo').nodes[0]).toMatchSnapshot());
});
