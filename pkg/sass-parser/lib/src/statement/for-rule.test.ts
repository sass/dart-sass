// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {ForRule, GenericAtRule, StringExpression, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('an @for rule', () => {
  let node: ForRule;
  describe('with empty children', () => {
    function describeNode(description: string, create: () => ForRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('for'));

        it('has a variable', () => expect(node.variable).toBe('foo'));

        it('has a to', () => expect(node.to).toBe('through'));

        it('has a from expression', () =>
          expect(node).toHaveStringExpression('fromExpression', 'bar'));

        it('has a to expression', () =>
          expect(node).toHaveStringExpression('toExpression', 'baz'));

        it('has matching params', () =>
          expect(node.params).toBe('$foo from bar through baz'));

        it('has empty nodes', () => expect(node.nodes).toEqual([]));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@for $foo from bar through baz {}').nodes[0] as ForRule
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@for $foo from bar through baz').nodes[0] as ForRule
    );

    describeNode(
      'constructed manually',
      () =>
        new ForRule({
          variable: 'foo',
          to: 'through',
          fromExpression: {text: 'bar'},
          toExpression: {text: 'baz'},
        })
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        variable: 'foo',
        to: 'through',
        fromExpression: {text: 'bar'},
        toExpression: {text: 'baz'},
      })
    );
  });

  describe('with a child', () => {
    function describeNode(description: string, create: () => ForRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('for'));

        it('has a variable', () => expect(node.variable).toBe('foo'));

        it('has a to', () => expect(node.to).toBe('through'));

        it('has a from expression', () =>
          expect(node).toHaveStringExpression('fromExpression', 'bar'));

        it('has a to expression', () =>
          expect(node).toHaveStringExpression('toExpression', 'baz'));

        it('has matching params', () =>
          expect(node.params).toBe('$foo from bar through baz'));

        it('has a child node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0]).toBeInstanceOf(GenericAtRule);
          expect(node.nodes[0]).toHaveProperty('name', 'child');
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        scss.parse('@for $foo from bar through baz {@child}')
          .nodes[0] as ForRule
    );

    describeNode(
      'parsed as Sass',
      () =>
        sass.parse('@for $foo from bar through baz\n  @child')
          .nodes[0] as ForRule
    );

    describeNode(
      'constructed manually',
      () =>
        new ForRule({
          variable: 'foo',
          to: 'through',
          fromExpression: {text: 'bar'},
          toExpression: {text: 'baz'},
          nodes: [{name: 'child'}],
        })
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        variable: 'foo',
        to: 'through',
        fromExpression: {text: 'bar'},
        toExpression: {text: 'baz'},
        nodes: [{name: 'child'}],
      })
    );
  });

  describe('throws an error when assigned a new', () => {
    beforeEach(
      () =>
        void (node = new ForRule({
          variable: 'foo',
          fromExpression: {text: 'bar'},
          toExpression: {text: 'baz'},
        }))
    );

    it('name', () => expect(() => (node.name = 'qux')).toThrow());

    it('params', () =>
      expect(() => (node.params = '$zip from zap to qux')).toThrow());
  });

  describe('assigned a new from expression', () => {
    beforeEach(() => {
      node = scss.parse('@for $foo from bar to baz {}').nodes[0] as ForRule;
    });

    it("removes the old expression's parent", () => {
      const oldExpression = node.fromExpression;
      node.fromExpression = {text: 'qux'};
      expect(oldExpression.parent).toBeUndefined();
    });

    it("assigns the new expression's parent", () => {
      const expression = new StringExpression({text: 'qux'});
      node.fromExpression = expression;
      expect(expression.parent).toBe(node);
    });

    it('assigns the expression explicitly', () => {
      const expression = new StringExpression({text: 'qux'});
      node.fromExpression = expression;
      expect(node.fromExpression).toBe(expression);
    });

    it('assigns the expression as ExpressionProps', () => {
      node.fromExpression = {text: 'qux'};
      expect(node).toHaveStringExpression('fromExpression', 'qux');
    });
  });

  describe('assigned a new to expression', () => {
    beforeEach(() => {
      node = scss.parse('@for $foo from bar to baz {}').nodes[0] as ForRule;
    });

    it("removes the old expression's parent", () => {
      const oldExpression = node.toExpression;
      node.toExpression = {text: 'qux'};
      expect(oldExpression.parent).toBeUndefined();
    });

    it("assigns the new expression's parent", () => {
      const expression = new StringExpression({text: 'qux'});
      node.toExpression = expression;
      expect(expression.parent).toBe(node);
    });

    it('assigns the expression explicitly', () => {
      const expression = new StringExpression({text: 'qux'});
      node.toExpression = expression;
      expect(node.toExpression).toBe(expression);
    });

    it('assigns the expression as ExpressionProps', () => {
      node.toExpression = {text: 'qux'};
      expect(node).toHaveStringExpression('toExpression', 'qux');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(
          new ForRule({
            variable: 'foo',
            fromExpression: {text: 'bar'},
            toExpression: {text: 'baz'},
          }).toString()
        ).toBe('@for $foo from bar to baz {}'));

      it('with afterName', () =>
        expect(
          new ForRule({
            variable: 'foo',
            fromExpression: {text: 'bar'},
            toExpression: {text: 'baz'},
            raws: {afterName: '/**/'},
          }).toString()
        ).toBe('@for/**/$foo from bar to baz {}'));

      it('with afterVariable', () =>
        expect(
          new ForRule({
            variable: 'foo',
            fromExpression: {text: 'bar'},
            toExpression: {text: 'baz'},
            raws: {afterVariable: '/**/'},
          }).toString()
        ).toBe('@for $foo/**/from bar to baz {}'));

      it('with afterFrom', () =>
        expect(
          new ForRule({
            variable: 'foo',
            fromExpression: {text: 'bar'},
            toExpression: {text: 'baz'},
            raws: {afterFrom: '/**/'},
          }).toString()
        ).toBe('@for $foo from/**/bar to baz {}'));

      it('with afterFromExpression', () =>
        expect(
          new ForRule({
            variable: 'foo',
            fromExpression: {text: 'bar'},
            toExpression: {text: 'baz'},
            raws: {afterFromExpression: '/**/'},
          }).toString()
        ).toBe('@for $foo from bar/**/to baz {}'));

      it('with afterTo', () =>
        expect(
          new ForRule({
            variable: 'foo',
            fromExpression: {text: 'bar'},
            toExpression: {text: 'baz'},
            raws: {afterTo: '/**/'},
          }).toString()
        ).toBe('@for $foo from bar to/**/baz {}'));
    });
  });

  describe('clone', () => {
    let original: ForRule;
    beforeEach(() => {
      original = scss.parse('@for $foo from bar to baz {}').nodes[0] as ForRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: ForRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('$foo from bar to baz'));

        it('variable', () => expect(clone.variable).toBe('foo'));

        it('to', () => expect(clone.to).toBe('to'));

        it('fromExpression', () =>
          expect(clone).toHaveStringExpression('fromExpression', 'bar'));

        it('toExpression', () =>
          expect(clone).toHaveStringExpression('toExpression', 'baz'));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of [
          'fromExpression',
          'toExpression',
          'raws',
        ] as const) {
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

      describe('variable', () => {
        describe('defined', () => {
          let clone: ForRule;
          beforeEach(() => {
            clone = original.clone({variable: 'zip'});
          });

          it('changes params', () =>
            expect(clone.params).toBe('$zip from bar to baz'));

          it('changes variable', () => expect(clone.variable).toBe('zip'));
        });

        describe('undefined', () => {
          let clone: ForRule;
          beforeEach(() => {
            clone = original.clone({variable: undefined});
          });

          it('preserves params', () =>
            expect(clone.params).toBe('$foo from bar to baz'));

          it('preserves variable', () => expect(clone.variable).toBe('foo'));
        });
      });

      describe('to', () => {
        describe('defined', () => {
          let clone: ForRule;
          beforeEach(() => {
            clone = original.clone({to: 'through'});
          });

          it('changes params', () =>
            expect(clone.params).toBe('$foo from bar through baz'));

          it('changes tos', () => expect(clone.to).toBe('through'));
        });

        describe('undefined', () => {
          let clone: ForRule;
          beforeEach(() => {
            clone = original.clone({to: undefined});
          });

          it('preserves params', () =>
            expect(clone.params).toBe('$foo from bar to baz'));

          it('preserves tos', () => expect(clone.to).toBe('to'));
        });
      });

      describe('fromExpression', () => {
        describe('defined', () => {
          let clone: ForRule;
          beforeEach(() => {
            clone = original.clone({fromExpression: {text: 'qux'}});
          });

          it('changes params', () =>
            expect(clone.params).toBe('$foo from qux to baz'));

          it('changes fromExpression', () =>
            expect(clone).toHaveStringExpression('fromExpression', 'qux'));
        });

        describe('undefined', () => {
          let clone: ForRule;
          beforeEach(() => {
            clone = original.clone({fromExpression: undefined});
          });

          it('preserves params', () =>
            expect(clone.params).toBe('$foo from bar to baz'));

          it('preserves fromExpression', () =>
            expect(clone).toHaveStringExpression('fromExpression', 'bar'));
        });
      });

      describe('toExpression', () => {
        describe('defined', () => {
          let clone: ForRule;
          beforeEach(() => {
            clone = original.clone({toExpression: {text: 'qux'}});
          });

          it('changes params', () =>
            expect(clone.params).toBe('$foo from bar to qux'));

          it('changes toExpression', () =>
            expect(clone).toHaveStringExpression('toExpression', 'qux'));
        });

        describe('undefined', () => {
          let clone: ForRule;
          beforeEach(() => {
            clone = original.clone({toExpression: undefined});
          });

          it('preserves params', () =>
            expect(clone.params).toBe('$foo from bar to baz'));

          it('preserves toExpression', () =>
            expect(clone).toHaveStringExpression('toExpression', 'baz'));
        });
      });
    });
  });

  it('toJSON', () =>
    expect(
      scss.parse('@for $foo from bar to baz {}').nodes[0]
    ).toMatchSnapshot());
});
