// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {EachRule, GenericAtRule, StringExpression, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('an @each rule', () => {
  let node: EachRule;
  describe('with empty children', () => {
    function describeNode(description: string, create: () => EachRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('each'));

        it('has variables', () =>
          expect(node.variables).toEqual(['foo', 'bar']));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('eachExpression', 'baz'));

        it('has matching params', () =>
          expect(node.params).toBe('$foo, $bar in baz'));

        it('has empty nodes', () => expect(node.nodes).toEqual([]));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@each $foo, $bar in baz {}').nodes[0] as EachRule
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@each $foo, $bar in baz').nodes[0] as EachRule
    );

    describeNode(
      'constructed manually',
      () =>
        new EachRule({
          variables: ['foo', 'bar'],
          eachExpression: {text: 'baz'},
        })
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        variables: ['foo', 'bar'],
        eachExpression: {text: 'baz'},
      })
    );
  });

  describe('with a child', () => {
    function describeNode(description: string, create: () => EachRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('each'));

        it('has variables', () =>
          expect(node.variables).toEqual(['foo', 'bar']));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('eachExpression', 'baz'));

        it('has matching params', () =>
          expect(node.params).toBe('$foo, $bar in baz'));

        it('has a child node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0]).toBeInstanceOf(GenericAtRule);
          expect(node.nodes[0]).toHaveProperty('name', 'child');
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@each $foo, $bar in baz {@child}').nodes[0] as EachRule
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@each $foo, $bar in baz\n  @child').nodes[0] as EachRule
    );

    describeNode(
      'constructed manually',
      () =>
        new EachRule({
          variables: ['foo', 'bar'],
          eachExpression: {text: 'baz'},
          nodes: [{name: 'child'}],
        })
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        variables: ['foo', 'bar'],
        eachExpression: {text: 'baz'},
        nodes: [{name: 'child'}],
      })
    );
  });

  describe('throws an error when assigned a new', () => {
    beforeEach(
      () =>
        void (node = new EachRule({
          variables: ['foo', 'bar'],
          eachExpression: {text: 'baz'},
        }))
    );

    it('name', () => expect(() => (node.name = 'qux')).toThrow());

    it('params', () =>
      expect(() => (node.params = '$zip, $zap in qux')).toThrow());
  });

  describe('assigned a new expression', () => {
    beforeEach(() => {
      node = scss.parse('@each $foo, $bar in baz {}').nodes[0] as EachRule;
    });

    it("removes the old expression's parent", () => {
      const oldExpression = node.eachExpression;
      node.eachExpression = {text: 'qux'};
      expect(oldExpression.parent).toBeUndefined();
    });

    it("assigns the new expression's parent", () => {
      const expression = new StringExpression({text: 'qux'});
      node.eachExpression = expression;
      expect(expression.parent).toBe(node);
    });

    it('assigns the expression explicitly', () => {
      const expression = new StringExpression({text: 'qux'});
      node.eachExpression = expression;
      expect(node.eachExpression).toBe(expression);
    });

    it('assigns the expression as ExpressionProps', () => {
      node.eachExpression = {text: 'qux'};
      expect(node).toHaveStringExpression('eachExpression', 'qux');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(
          new EachRule({
            variables: ['foo', 'bar'],
            eachExpression: {text: 'baz'},
          }).toString()
        ).toBe('@each $foo, $bar in baz {}'));

      it('with afterName', () =>
        expect(
          new EachRule({
            variables: ['foo', 'bar'],
            eachExpression: {text: 'baz'},
            raws: {afterName: '/**/'},
          }).toString()
        ).toBe('@each/**/$foo, $bar in baz {}'));

      it('with afterVariables', () =>
        expect(
          new EachRule({
            variables: ['foo', 'bar'],
            eachExpression: {text: 'baz'},
            raws: {afterVariables: ['/**/,', '/* */']},
          }).toString()
        ).toBe('@each $foo/**/,$bar/* */in baz {}'));

      it('with afterIn', () =>
        expect(
          new EachRule({
            variables: ['foo', 'bar'],
            eachExpression: {text: 'baz'},
            raws: {afterIn: '/**/'},
          }).toString()
        ).toBe('@each $foo, $bar in/**/baz {}'));
    });
  });

  describe('clone', () => {
    let original: EachRule;
    beforeEach(() => {
      original = scss.parse('@each $foo, $bar in baz {}').nodes[0] as EachRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: EachRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('$foo, $bar in baz'));

        it('variables', () => expect(clone.variables).toEqual(['foo', 'bar']));

        it('eachExpression', () =>
          expect(clone).toHaveStringExpression('eachExpression', 'baz'));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['variables', 'eachExpression', 'raws'] as const) {
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

      describe('variables', () => {
        describe('defined', () => {
          let clone: EachRule;
          beforeEach(() => {
            clone = original.clone({variables: ['zip', 'zap']});
          });

          it('changes params', () =>
            expect(clone.params).toBe('$zip, $zap in baz'));

          it('changes variables', () =>
            expect(clone.variables).toEqual(['zip', 'zap']));
        });

        describe('undefined', () => {
          let clone: EachRule;
          beforeEach(() => {
            clone = original.clone({variables: undefined});
          });

          it('preserves params', () =>
            expect(clone.params).toBe('$foo, $bar in baz'));

          it('preserves variables', () =>
            expect(clone.variables).toEqual(['foo', 'bar']));
        });
      });

      describe('eachExpression', () => {
        describe('defined', () => {
          let clone: EachRule;
          beforeEach(() => {
            clone = original.clone({eachExpression: {text: 'qux'}});
          });

          it('changes params', () =>
            expect(clone.params).toBe('$foo, $bar in qux'));

          it('changes eachExpression', () =>
            expect(clone).toHaveStringExpression('eachExpression', 'qux'));
        });

        describe('undefined', () => {
          let clone: EachRule;
          beforeEach(() => {
            clone = original.clone({eachExpression: undefined});
          });

          it('preserves params', () =>
            expect(clone.params).toBe('$foo, $bar in baz'));

          it('preserves eachExpression', () =>
            expect(clone).toHaveStringExpression('eachExpression', 'baz'));
        });
      });
    });
  });

  it('toJSON', () =>
    expect(
      scss.parse('@each $foo, $bar in baz {}').nodes[0]
    ).toMatchSnapshot());
});
