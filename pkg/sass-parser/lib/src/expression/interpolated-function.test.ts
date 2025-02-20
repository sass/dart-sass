// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  ArgumentList,
  InterpolatedFunctionExpression,
  Interpolation,
} from '../..';
import * as utils from '../../../test/utils';

describe('an interpolated function expression', () => {
  let node: InterpolatedFunctionExpression;

  function describeNode(
    description: string,
    create: () => InterpolatedFunctionExpression,
  ): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has sassType interpolated-function-call', () =>
        expect(node.sassType).toBe('interpolated-function-call'));

      it('has a name', () =>
        expect(node).toHaveInterpolation('name', 'f#{o}o'));

      it('has an argument', () =>
        expect(node.arguments.nodes[0]).toHaveStringExpression('value', 'bar'));
    });
  }

  describeNode('parsed', () => utils.parseExpression('f#{o}o(bar)'));

  describeNode(
    'constructed manually',
    () =>
      new InterpolatedFunctionExpression({
        name: ['f', {text: 'o'}, 'o'],
        arguments: [{text: 'bar'}],
      }),
  );

  describeNode('constructed from ExpressionProps', () =>
    utils.fromExpressionProps({
      name: ['f', {text: 'o'}, 'o'],
      arguments: [{text: 'bar'}],
    }),
  );

  describe('assigned new name', () => {
    beforeEach(() => void (node = utils.parseExpression('f#{o}o(bar)')));

    it("removes the old name's parent", () => {
      const oldName = node.name;
      node.name = [{text: 'baz'}];
      expect(oldName.parent).toBeUndefined();
    });

    it("assigns the new name's parent", () => {
      const name = new Interpolation([{text: 'baz'}]);
      node.name = name;
      expect(name.parent).toBe(node);
    });

    it('assigns the name explicitly', () => {
      const name = new Interpolation([{text: 'baz'}]);
      node.name = name;
      expect(node.name).toBe(name);
    });

    it('assigns the expression as InterpolationProps', () => {
      node.name = [{text: 'baz'}];
      expect(node).toHaveInterpolation('name', '#{baz}');
    });
  });

  describe('assigned new arguments', () => {
    beforeEach(() => void (node = utils.parseExpression('f#{o}o(bar)')));

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

  it('stringifies', () =>
    expect(
      new InterpolatedFunctionExpression({
        name: ['f', {text: 'o'}, 'o'],
        arguments: [{text: 'bar'}],
      }).toString(),
    ).toBe('f#{o}o(bar)'));

  describe('clone', () => {
    let original: InterpolatedFunctionExpression;
    beforeEach(() => void (original = utils.parseExpression('f#{o}o(bar)')));

    describe('with no overrides', () => {
      let clone: InterpolatedFunctionExpression;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('name', () => expect(clone).toHaveInterpolation('name', 'f#{o}o'));

        it('arguments', () => {
          expect(clone.arguments.nodes[0]).toHaveStringExpression(
            'value',
            'bar',
          );
          expect(clone.arguments.parent).toBe(clone);
        });

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {}}).raws).toEqual({}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({}));
      });

      describe('name', () => {
        it('defined', () =>
          expect(original.clone({name: [{text: 'zip'}]})).toHaveInterpolation(
            'name',
            '#{zip}',
          ));

        it('undefined', () =>
          expect(original.clone({name: undefined})).toHaveInterpolation(
            'name',
            'f#{o}o',
          ));
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

  it('toJSON', () =>
    expect(utils.parseExpression('f#{o}o(bar)')).toMatchSnapshot());
});
