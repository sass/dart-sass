// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {ElseRule, GenericAtRule, StringExpression, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('an @else rule', () => {
  let node: ElseRule;
  describe('with no expression and empty children', () => {
    function describeNode(description: string, create: () => ElseRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('else'));

        it('has no expression', () =>
          expect(node.elseCondition).toBeUndefined());

        it('has empty params', () => expect(node.params).toBe(''));

        it('has empty nodes', () => expect(node.nodes).toEqual([]));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@if foo {} @else {}').nodes[1] as ElseRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@if foo\n@else').nodes[1] as ElseRule,
    );

    describeNode('constructed manually', () => new ElseRule());

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({elseCondition: undefined}),
    );
  });

  describe('with an expression and empty children', () => {
    function describeNode(description: string, create: () => ElseRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('else'));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('elseCondition', 'foo'));

        it('has matching params', () => expect(node.params).toBe('if foo'));

        it('has empty nodes', () => expect(node.nodes).toEqual([]));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@if bar {} @else if foo {}').nodes[1] as ElseRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@if bar\n@else if foo').nodes[1] as ElseRule,
    );

    describeNode(
      'constructed manually',
      () => new ElseRule({elseCondition: {text: 'foo'}}),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({elseCondition: {text: 'foo'}}),
    );
  });

  describe('with no expression and a child', () => {
    function describeNode(description: string, create: () => ElseRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('else'));

        it('has an expression', () =>
          expect(node.elseCondition).toBeUndefined());

        it('has empty params', () => expect(node.params).toBe(''));

        it('has a child node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0]).toBeInstanceOf(GenericAtRule);
          expect(node.nodes[0]).toHaveProperty('name', 'child');
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@if foo {} @else {@child}').nodes[1] as ElseRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@if foo\n@else\n  @child').nodes[1] as ElseRule,
    );

    describeNode(
      'constructed manually',
      () => new ElseRule({nodes: [{name: 'child'}]}),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        elseCondition: undefined,
        nodes: [{name: 'child'}],
      }),
    );
  });

  describe('throws an error when assigned a new', () => {
    beforeEach(() => void (node = new ElseRule()));

    it('name', () => expect(() => (node.name = 'bar')).toThrow());

    it('params', () => expect(() => (node.params = 'true')).toThrow());
  });

  describe('assigned a new expression', () => {
    beforeEach(() => {
      node = scss.parse('@if foo {} @else if bar {}').nodes[1] as ElseRule;
    });

    it("removes the old expression's parent", () => {
      const oldExpression = node.elseCondition!;
      node.elseCondition = {text: 'bar'};
      expect(oldExpression.parent).toBeUndefined();
    });

    it("assigns the new expression's parent", () => {
      const expression = new StringExpression({text: 'bar'});
      node.elseCondition = expression;
      expect(expression.parent).toBe(node);
    });

    it('assigns the expression explicitly', () => {
      const expression = new StringExpression({text: 'bar'});
      node.elseCondition = expression;
      expect(node.elseCondition).toBe(expression);
    });

    it('assigns the expression as ExpressionProps', () => {
      node.elseCondition = {text: 'bar'};
      expect(node).toHaveStringExpression('elseCondition', 'bar');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with no expression', () => {
        it('with default raws', () =>
          expect(new ElseRule().toString()).toBe('@else {}'));

        it('with afterName', () =>
          expect(new ElseRule({raws: {afterName: '/**/'}}).toString()).toBe(
            '@else/**/ {}',
          ));

        it('with afterIf', () =>
          expect(new ElseRule({raws: {afterIf: '/**/'}}).toString()).toBe(
            '@else {}',
          ));

        it('with between', () =>
          expect(
            new ElseRule({
              raws: {between: '/**/'},
            }).toString(),
          ).toBe('@else/**/{}'));
      });

      describe('with an expression', () => {
        it('with default raws', () =>
          expect(
            new ElseRule({
              elseCondition: {text: 'foo'},
            }).toString(),
          ).toBe('@else if foo {}'));

        it('with afterName', () =>
          expect(
            new ElseRule({
              elseCondition: {text: 'foo'},
              raws: {afterName: '/**/'},
            }).toString(),
          ).toBe('@else/**/if foo {}'));

        it('with afterIf', () =>
          expect(
            new ElseRule({
              elseCondition: {text: 'foo'},
              raws: {afterIf: '/**/'},
            }).toString(),
          ).toBe('@else if/**/foo {}'));

        it('with between', () =>
          expect(
            new ElseRule({
              elseCondition: {text: 'foo'},
              raws: {between: '/**/'},
            }).toString(),
          ).toBe('@else if foo/**/{}'));
      });
    });
  });

  describe('clone', () => {
    let original: ElseRule;
    beforeEach(() => {
      original = scss.parse('@if bar {} @else if foo {}').nodes[1] as ElseRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: ElseRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('if foo'));

        it('elseCondition', () =>
          expect(clone).toHaveStringExpression('elseCondition', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['elseCondition', 'raws'] as const) {
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

      describe('elseCondition', () => {
        describe('defined', () => {
          let clone: ElseRule;
          beforeEach(() => {
            clone = original.clone({elseCondition: {text: 'bar'}});
          });

          it('changes params', () => expect(clone.params).toBe('if bar'));

          it('changes elseCondition', () =>
            expect(clone).toHaveStringExpression('elseCondition', 'bar'));
        });

        describe('undefined', () => {
          let clone: ElseRule;
          beforeEach(() => {
            clone = original.clone({elseCondition: undefined});
          });

          it('changes params', () => expect(clone.params).toBe(''));

          it('changes elseCondition', () =>
            expect(clone.elseCondition).toBeUndefined());
        });
      });
    });
  });

  describe('toJSON', () => {
    it('with no expression', () =>
      expect(scss.parse('@if foo {} @else {}').nodes[1]).toMatchSnapshot());

    it('with an expression', () =>
      expect(
        scss.parse('@if foo {} @else if bar {}').nodes[1],
      ).toMatchSnapshot());
  });
});
