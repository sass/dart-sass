// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {ArgumentList, FunctionExpression} from '../..';
import * as utils from '../../../test/utils';

describe('a function expression', () => {
  let node: FunctionExpression;

  describe('with no namespace', () => {
    function describeNode(
      description: string,
      create: () => FunctionExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType function-call', () =>
          expect(node.sassType).toBe('function-call'));

        it('has no namespace', () => expect(node.namespace).toBe(undefined));

        it('has a name', () => expect(node.name).toBe('foo'));

        it('has an argument', () =>
          expect(node.arguments.nodes[0]).toHaveStringExpression(
            'value',
            'bar',
          ));
      });
    }

    describeNode('parsed', () => utils.parseExpression('foo(bar)'));

    describeNode(
      'constructed manually',
      () => new FunctionExpression({name: 'foo', arguments: [{text: 'bar'}]}),
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({name: 'foo', arguments: [{text: 'bar'}]}),
    );
  });

  describe('with a namespace', () => {
    function describeNode(
      description: string,
      create: () => FunctionExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType function-call', () =>
          expect(node.sassType).toBe('function-call'));

        it('has a namespace', () => expect(node.namespace).toBe('baz'));

        it('has a name', () => expect(node.name).toBe('foo'));

        it('has an argument', () =>
          expect(node.arguments.nodes[0]).toHaveStringExpression(
            'value',
            'bar',
          ));
      });
    }

    describeNode('parsed', () => utils.parseExpression('baz.foo(bar)'));

    describeNode(
      'constructed manually',
      () =>
        new FunctionExpression({
          namespace: 'baz',
          name: 'foo',
          arguments: [{text: 'bar'}],
        }),
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({
        namespace: 'baz',
        name: 'foo',
        arguments: [{text: 'bar'}],
      }),
    );
  });

  describe('if()', () => {
    beforeEach(() => void (node = utils.parseExpression('if(cond, bar, baz)')));

    it('has sassType function-call', () =>
      expect(node.sassType).toBe('function-call'));

    it('has no namespace', () => expect(node.namespace).toBe(undefined));

    it('has a name', () => expect(node.name).toBe('if'));

    it('has three arguments', () => {
      expect(node.arguments.nodes[0]).toHaveStringExpression('value', 'cond');
      expect(node.arguments.nodes[1]).toHaveStringExpression('value', 'bar');
      expect(node.arguments.nodes[2]).toHaveStringExpression('value', 'baz');
    });
  });

  describe('assigned new namespace', () => {
    it('defined', () => {
      node = utils.parseExpression('foo(bar)');
      node.namespace = 'baz';
      expect(node.namespace).toBe('baz');
    });

    it('undefined', () => {
      node = utils.parseExpression('baz.foo(bar)');
      node.namespace = undefined;
      expect(node.namespace).toBe(undefined);
    });
  });

  it('assigned new name', () => {
    node = utils.parseExpression('foo(bar)');
    node.name = 'baz';
    expect(node.name).toBe('baz');
  });

  describe('assigned new arguments', () => {
    beforeEach(() => void (node = utils.parseExpression('foo(bar)')));

    it("removes the old arguments' parent", () => {
      const oldArguments = node.arguments;
      node.arguments = [{text: 'qux'}];
      expect(oldArguments.parent).toBeUndefined();
    });

    it("assigns the new arguments' parent", () => {
      const args = new ArgumentList([{text: 'qux'}]);
      node.arguments = args;
      expect(args.parent).toBe(node);
    });

    it('assigns the arguments explicitly', () => {
      const args = new ArgumentList([{text: 'qux'}]);
      node.arguments = args;
      expect(node.arguments).toBe(args);
    });

    it('assigns the expression as ArgumentProps', () => {
      node.arguments = [{text: 'qux'}];
      expect(node.arguments.nodes[0]).toHaveStringExpression('value', 'qux');
      expect(node.arguments.parent).toBe(node);
    });
  });

  describe('stringifies', () => {
    describe('with default raws', () => {
      it('with no namespace', () =>
        expect(
          new FunctionExpression({
            name: 'foo',
            arguments: [{text: 'bar'}],
          }).toString(),
        ).toBe('foo(bar)'));

      it('with a namespace', () =>
        expect(
          new FunctionExpression({
            namespace: 'baz',
            name: 'foo',
            arguments: [{text: 'bar'}],
          }).toString(),
        ).toBe('baz.foo(bar)'));
    });

    it('with matching namespace', () =>
      expect(
        new FunctionExpression({
          namespace: 'baz',
          name: 'foo',
          arguments: [{text: 'bar'}],
          raws: {namespace: {value: 'baz', raw: 'b\\61z'}},
        }).toString(),
      ).toBe('b\\61z.foo(bar)'));

    it('with non-matching namespace', () =>
      expect(
        new FunctionExpression({
          namespace: 'zip',
          name: 'foo',
          arguments: [{text: 'bar'}],
          raws: {namespace: {value: 'baz', raw: 'b\\61z'}},
        }).toString(),
      ).toBe('zip.foo(bar)'));

    it('with matching name', () =>
      expect(
        new FunctionExpression({
          name: 'foo',
          arguments: [{text: 'bar'}],
          raws: {name: {value: 'foo', raw: 'f\\6fo'}},
        }).toString(),
      ).toBe('f\\6fo(bar)'));

    it('with non-matching name', () =>
      expect(
        new FunctionExpression({
          name: 'zip',
          arguments: [{text: 'bar'}],
          raws: {name: {value: 'foo', raw: 'f\\6fo'}},
        }).toString(),
      ).toBe('zip(bar)'));
  });

  describe('clone', () => {
    let original: FunctionExpression;

    beforeEach(() => {
      original = utils.parseExpression('baz.foo(bar)');
      // TODO: remove this once raws are properly parsed
      original.raws.name = {value: 'foo', raw: 'f\\6fo'};
    });

    describe('with no overrides', () => {
      let clone: FunctionExpression;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('namespace', () => expect(clone.namespace).toBe('baz'));

        it('name', () => expect(clone.name).toBe('foo'));

        it('arguments', () => {
          expect(clone.arguments.nodes[0]).toHaveStringExpression(
            'value',
            'bar',
          );
          expect(clone.arguments.parent).toBe(clone);
        });

        it('raws', () =>
          expect(clone.raws).toEqual({name: {value: 'foo', raw: 'f\\6fo'}}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['arguments', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(
            original.clone({raws: {namespace: {value: 'baz', raw: 'b\\61z'}}})
              .raws,
          ).toEqual({namespace: {value: 'baz', raw: 'b\\61z'}}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            name: {value: 'foo', raw: 'f\\6fo'},
          }));
      });

      describe('namespace', () => {
        it('defined', () =>
          expect(original.clone({namespace: 'zip'}).namespace).toBe('zip'));

        it('undefined', () =>
          expect(original.clone({namespace: undefined}).namespace).toBe(
            undefined,
          ));
      });

      describe('name', () => {
        it('defined', () =>
          expect(original.clone({name: 'zip'}).name).toBe('zip'));

        it('undefined', () =>
          expect(original.clone({name: undefined}).name).toBe('foo'));
      });

      describe('arguments', () => {
        it('defined', () => {
          const clone = original.clone({arguments: [{text: 'qux'}]});
          expect(clone.arguments.nodes[0]).toHaveStringExpression(
            'value',
            'qux',
          );
          expect(clone.arguments.parent).toBe(clone);
        });

        it('undefined', () =>
          expect(
            original.clone({arguments: undefined}).arguments.nodes[0],
          ).toHaveStringExpression('value', 'bar'));
      });
    });
  });

  describe('toJSON', () => {
    it('without a namespace', () =>
      expect(utils.parseExpression('foo(bar)')).toMatchSnapshot());

    it('with a namespace', () =>
      expect(utils.parseExpression('baz.foo(bar)')).toMatchSnapshot());

    it('if()', () =>
      expect(utils.parseExpression('if(cond, true, false)')).toMatchSnapshot());
  });
});
