// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {GenericAtRule, StringExpression, WhileRule, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a @while rule', () => {
  let node: WhileRule;
  describe('with empty children', () => {
    function describeNode(description: string, create: () => WhileRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('while'));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('whileCondition', 'foo'));

        it('has matching params', () => expect(node.params).toBe('foo'));

        it('has empty nodes', () => expect(node.nodes).toEqual([]));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@while foo {}').nodes[0] as WhileRule
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@while foo').nodes[0] as WhileRule
    );

    describeNode(
      'constructed manually',
      () =>
        new WhileRule({
          whileCondition: {text: 'foo'},
        })
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        whileCondition: {text: 'foo'},
      })
    );
  });

  describe('with a child', () => {
    function describeNode(description: string, create: () => WhileRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('while'));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('whileCondition', 'foo'));

        it('has matching params', () => expect(node.params).toBe('foo'));

        it('has a child node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0]).toBeInstanceOf(GenericAtRule);
          expect(node.nodes[0]).toHaveProperty('name', 'child');
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@while foo {@child}').nodes[0] as WhileRule
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@while foo\n  @child').nodes[0] as WhileRule
    );

    describeNode(
      'constructed manually',
      () =>
        new WhileRule({
          whileCondition: {text: 'foo'},
          nodes: [{name: 'child'}],
        })
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        whileCondition: {text: 'foo'},
        nodes: [{name: 'child'}],
      })
    );
  });

  describe('throws an error when assigned a new', () => {
    beforeEach(
      () => void (node = new WhileRule({whileCondition: {text: 'foo'}}))
    );

    it('name', () => expect(() => (node.name = 'bar')).toThrow());

    it('params', () => expect(() => (node.params = 'true')).toThrow());
  });

  describe('assigned a new expression', () => {
    beforeEach(() => {
      node = scss.parse('@while foo {}').nodes[0] as WhileRule;
    });

    it("removes the old expression's parent", () => {
      const oldExpression = node.whileCondition;
      node.whileCondition = {text: 'bar'};
      expect(oldExpression.parent).toBeUndefined();
    });

    it("assigns the new expression's parent", () => {
      const expression = new StringExpression({text: 'bar'});
      node.whileCondition = expression;
      expect(expression.parent).toBe(node);
    });

    it('assigns the expression explicitly', () => {
      const expression = new StringExpression({text: 'bar'});
      node.whileCondition = expression;
      expect(node.whileCondition).toBe(expression);
    });

    it('assigns the expression as ExpressionProps', () => {
      node.whileCondition = {text: 'bar'};
      expect(node).toHaveStringExpression('whileCondition', 'bar');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(
          new WhileRule({
            whileCondition: {text: 'foo'},
          }).toString()
        ).toBe('@while foo {}'));

      it('with afterName', () =>
        expect(
          new WhileRule({
            whileCondition: {text: 'foo'},
            raws: {afterName: '/**/'},
          }).toString()
        ).toBe('@while/**/foo {}'));

      it('with between', () =>
        expect(
          new WhileRule({
            whileCondition: {text: 'foo'},
            raws: {between: '/**/'},
          }).toString()
        ).toBe('@while foo/**/{}'));
    });
  });

  describe('clone', () => {
    let original: WhileRule;
    beforeEach(() => {
      original = scss.parse('@while foo {}').nodes[0] as WhileRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: WhileRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('foo'));

        it('whileCondition', () =>
          expect(clone).toHaveStringExpression('whileCondition', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['whileCondition', 'raws'] as const) {
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

      describe('whileCondition', () => {
        describe('defined', () => {
          let clone: WhileRule;
          beforeEach(() => {
            clone = original.clone({whileCondition: {text: 'bar'}});
          });

          it('changes params', () => expect(clone.params).toBe('bar'));

          it('changes whileCondition', () =>
            expect(clone).toHaveStringExpression('whileCondition', 'bar'));
        });

        describe('undefined', () => {
          let clone: WhileRule;
          beforeEach(() => {
            clone = original.clone({whileCondition: undefined});
          });

          it('preserves params', () => expect(clone.params).toBe('foo'));

          it('preserves whileCondition', () =>
            expect(clone).toHaveStringExpression('whileCondition', 'foo'));
        });
      });
    });
  });

  it('toJSON', () =>
    expect(scss.parse('@while foo {}').nodes[0]).toMatchSnapshot());
});
