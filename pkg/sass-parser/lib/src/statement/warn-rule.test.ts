// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {StringExpression, WarnRule, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a @warn rule', () => {
  let node: WarnRule;
  function describeNode(description: string, create: () => WarnRule): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has a name', () => expect(node.name.toString()).toBe('warn'));

      it('has an expression', () =>
        expect(node).toHaveStringExpression('warnExpression', 'foo'));

      it('has matching params', () => expect(node.params).toBe('foo'));

      it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
    });
  }

  describeNode(
    'parsed as SCSS',
    () => scss.parse('@warn foo').nodes[0] as WarnRule,
  );

  describeNode(
    'parsed as Sass',
    () => sass.parse('@warn foo').nodes[0] as WarnRule,
  );

  describeNode(
    'constructed manually',
    () =>
      new WarnRule({
        warnExpression: {text: 'foo'},
      }),
  );

  describeNode('constructed from ChildProps', () =>
    utils.fromChildProps({
      warnExpression: {text: 'foo'},
    }),
  );

  it('throws an error when assigned a new name', () =>
    expect(
      () =>
        (new WarnRule({
          warnExpression: {text: 'foo'},
        }).name = 'bar'),
    ).toThrow());

  describe('assigned a new expression', () => {
    beforeEach(() => {
      node = scss.parse('@warn foo').nodes[0] as WarnRule;
    });

    it('sets an empty string expression as undefined params', () => {
      node.params = undefined;
      expect(node.params).toBe('');
      expect(node).toHaveStringExpression('warnExpression', '');
    });

    it('sets an empty string expression as empty string params', () => {
      node.params = '';
      expect(node.params).toBe('');
      expect(node).toHaveStringExpression('warnExpression', '');
    });

    it("removes the old expression's parent", () => {
      const oldExpression = node.warnExpression;
      node.warnExpression = {text: 'bar'};
      expect(oldExpression.parent).toBeUndefined();
    });

    it("assigns the new expression's parent", () => {
      const expression = new StringExpression({text: 'bar'});
      node.warnExpression = expression;
      expect(expression.parent).toBe(node);
    });

    it('assigns the expression explicitly', () => {
      const expression = new StringExpression({text: 'bar'});
      node.warnExpression = expression;
      expect(node.warnExpression).toBe(expression);
    });

    it('assigns the expression as ExpressionProps', () => {
      node.warnExpression = {text: 'bar'};
      expect(node).toHaveStringExpression('warnExpression', 'bar');
    });

    it('assigns the expression as params', () => {
      node.params = 'bar';
      expect(node).toHaveStringExpression('warnExpression', 'bar');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(
          new WarnRule({
            warnExpression: {text: 'foo'},
          }).toString(),
        ).toBe('@warn foo;'));

      it('with afterName', () =>
        expect(
          new WarnRule({
            warnExpression: {text: 'foo'},
            raws: {afterName: '/**/'},
          }).toString(),
        ).toBe('@warn/**/foo;'));

      it('with between', () =>
        expect(
          new WarnRule({
            warnExpression: {text: 'foo'},
            raws: {between: '/**/'},
          }).toString(),
        ).toBe('@warn foo/**/;'));
    });
  });

  describe('clone', () => {
    let original: WarnRule;
    beforeEach(() => {
      original = scss.parse('@warn foo').nodes[0] as WarnRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: WarnRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('foo'));

        it('warnExpression', () =>
          expect(clone).toHaveStringExpression('warnExpression', 'foo'));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['warnExpression', 'raws'] as const) {
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

      describe('warnExpression', () => {
        describe('defined', () => {
          let clone: WarnRule;
          beforeEach(() => {
            clone = original.clone({warnExpression: {text: 'bar'}});
          });

          it('changes params', () => expect(clone.params).toBe('bar'));

          it('changes warnExpression', () =>
            expect(clone).toHaveStringExpression('warnExpression', 'bar'));
        });

        describe('undefined', () => {
          let clone: WarnRule;
          beforeEach(() => {
            clone = original.clone({warnExpression: undefined});
          });

          it('preserves params', () => expect(clone.params).toBe('foo'));

          it('preserves warnExpression', () =>
            expect(clone).toHaveStringExpression('warnExpression', 'foo'));
        });
      });
    });
  });

  it('toJSON', () =>
    expect(scss.parse('@warn foo').nodes[0]).toMatchSnapshot());
});
