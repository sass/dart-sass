// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {GenericAtRule, IfRule, StringExpression, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('an @if rule', () => {
  let node: IfRule;
  describe('with empty children', () => {
    function describeNode(description: string, create: () => IfRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('if'));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('ifCondition', 'foo'));

        it('has matching params', () => expect(node.params).toBe('foo'));

        it('has empty nodes', () => expect(node.nodes).toEqual([]));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@if foo {}').nodes[0] as IfRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@if foo').nodes[0] as IfRule,
    );

    describeNode(
      'constructed manually',
      () => new IfRule({ifCondition: {text: 'foo'}}),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({ifCondition: {text: 'foo'}}),
    );
  });

  describe('with a child', () => {
    function describeNode(description: string, create: () => IfRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('if'));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('ifCondition', 'foo'));

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
      () => scss.parse('@if foo {@child}').nodes[0] as IfRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@if foo\n  @child').nodes[0] as IfRule,
    );

    describeNode(
      'constructed manually',
      () =>
        new IfRule({
          ifCondition: {text: 'foo'},
          nodes: [{name: 'child'}],
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        ifCondition: {text: 'foo'},
        nodes: [{name: 'child'}],
      }),
    );
  });

  describe('throws an error when assigned a new', () => {
    beforeEach(() => void (node = new IfRule({ifCondition: {text: 'foo'}})));

    it('name', () => expect(() => (node.name = 'bar')).toThrow());

    it('params', () => expect(() => (node.params = 'true')).toThrow());
  });

  describe('assigned a new expression', () => {
    beforeEach(() => {
      node = scss.parse('@if foo {}').nodes[0] as IfRule;
    });

    it("removes the old expression's parent", () => {
      const oldExpression = node.ifCondition;
      node.ifCondition = {text: 'bar'};
      expect(oldExpression.parent).toBeUndefined();
    });

    it("assigns the new expression's parent", () => {
      const expression = new StringExpression({text: 'bar'});
      node.ifCondition = expression;
      expect(expression.parent).toBe(node);
    });

    it('assigns the expression explicitly', () => {
      const expression = new StringExpression({text: 'bar'});
      node.ifCondition = expression;
      expect(node.ifCondition).toBe(expression);
    });

    it('assigns the expression as ExpressionProps', () => {
      node.ifCondition = {text: 'bar'};
      expect(node).toHaveStringExpression('ifCondition', 'bar');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(
          new IfRule({
            ifCondition: {text: 'foo'},
          }).toString(),
        ).toBe('@if foo {}'));

      it('with afterName', () =>
        expect(
          new IfRule({
            ifCondition: {text: 'foo'},
            raws: {afterName: '/**/'},
          }).toString(),
        ).toBe('@if/**/foo {}'));

      it('with between', () =>
        expect(
          new IfRule({
            ifCondition: {text: 'foo'},
            raws: {between: '/**/'},
          }).toString(),
        ).toBe('@if foo/**/{}'));
    });
  });

  describe('clone', () => {
    let original: IfRule;
    beforeEach(() => {
      original = scss.parse('@if foo {}').nodes[0] as IfRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: IfRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('foo'));

        it('ifCondition', () =>
          expect(clone).toHaveStringExpression('ifCondition', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['ifCondition', 'raws'] as const) {
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

      describe('ifCondition', () => {
        describe('defined', () => {
          let clone: IfRule;
          beforeEach(() => {
            clone = original.clone({ifCondition: {text: 'bar'}});
          });

          it('changes params', () => expect(clone.params).toBe('bar'));

          it('changes ifCondition', () =>
            expect(clone).toHaveStringExpression('ifCondition', 'bar'));
        });

        describe('undefined', () => {
          let clone: IfRule;
          beforeEach(() => {
            clone = original.clone({ifCondition: undefined});
          });

          it('preserves params', () => expect(clone.params).toBe('foo'));

          it('preserves ifCondition', () =>
            expect(clone).toHaveStringExpression('ifCondition', 'foo'));
        });
      });
    });
  });

  it('toJSON', () =>
    expect(scss.parse('@if foo {}').nodes[0]).toMatchSnapshot());
});
