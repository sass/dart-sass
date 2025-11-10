// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {IfConditionFunction, Interpolation} from '../../..';
import * as utils from '../../../../test/utils';

describe('an if() condition function', () => {
  let node: IfConditionFunction;
  beforeEach(() => {
    node = new IfConditionFunction({name: 'media', argument: 'screen'});
  });

  function describeNode(
    description: string,
    create: () => IfConditionFunction,
  ): void {
    describe(description, () => {
      beforeEach(() => (node = create()));

      it('has a sassType', () =>
        expect(node.sassType.toString()).toBe('if-condition-function'));

      it('has a name', () => expect(node).toHaveInterpolation('name', 'media'));

      it('has an argument', () =>
        expect(node).toHaveInterpolation('argument', 'screen'));
    });
  }

  describeNode('parsed', () =>
    utils.parseIfConditionExpression('media(screen)'),
  );

  describe('constructed manually', () => {
    describeNode(
      'with Interpolations',
      () =>
        new IfConditionFunction({
          name: new Interpolation('media'),
          argument: new Interpolation('screen'),
        }),
    );

    describeNode(
      'with InterpolationProps',
      () =>
        new IfConditionFunction({
          name: 'media',
          argument: 'screen',
        }),
    );
  });

  describe('constructed from IfConditionExpressionProps', () => {
    describeNode('with Interpolations', () =>
      utils.fromIfConditionExpressionProps({
        name: new Interpolation('media'),
        argument: new Interpolation('screen'),
      }),
    );

    describeNode('with InterpolationProps', () =>
      utils.fromIfConditionExpressionProps({
        name: 'media',
        argument: 'screen',
      }),
    );
  });

  describe('assigned a new name', () => {
    it('Interpolation', () => {
      const old = node.name;
      const name = new Interpolation('supports');
      node.name = name;
      expect(old.parent).toBeUndefined();
      expect(node.name).toBe(name);
      expect(node).toHaveInterpolation('name', 'supports');
    });

    it('InterpolationProps as a string', () => {
      const old = node.name;
      node.name = 'supports';
      expect(old.parent).toBeUndefined();
      expect(node).toHaveInterpolation('name', 'supports');
    });

    it('InterpolationProps as an object', () => {
      const old = node.name;
      node.name = {nodes: ['supports']};
      expect(old.parent).toBeUndefined();
      expect(node).toHaveInterpolation('name', 'supports');
    });
  });

  describe('assigned a new argument', () => {
    it('Interpolation', () => {
      const old = node.argument;
      const argument = new Interpolation('print');
      node.argument = argument;
      expect(old.parent).toBeUndefined();
      expect(node.argument).toBe(argument);
      expect(node).toHaveInterpolation('argument', 'print');
    });

    it('InterpolationProps as a string', () => {
      const old = node.argument;
      node.argument = 'print';
      expect(old.parent).toBeUndefined();
      expect(node).toHaveInterpolation('argument', 'print');
    });

    it('InterpolationProps as an object', () => {
      const old = node.argument;
      node.argument = {nodes: ['print']};
      expect(old.parent).toBeUndefined();
      expect(node).toHaveInterpolation('argument', 'print');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(node.toString()).toBe('media(screen)'));

      it('with afterOpen', () => {
        node.raws.afterOpen = '  ';
        expect(node.toString()).toBe('media(  screen)');
      });

      it('with beforeClose', () => {
        node.raws.beforeClose = '  ';
        expect(node.toString()).toBe('media(screen  )');
      });
    });
  });

  describe('clone()', () => {
    beforeEach(() => {
      node.raws.afterOpen = '  ';
    });

    describe('with no overrides', () => {
      let clone: IfConditionFunction;
      beforeEach(() => void (clone = node.clone()));

      describe('has the same properties:', () => {
        it('name', () => expect(clone).toHaveInterpolation('name', 'media'));

        it('argument', () =>
          expect(clone).toHaveInterpolation('argument', 'screen'));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(node));

        for (const attr of ['name', 'argument', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(node[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(node.clone({raws: {beforeClose: '/**/'}}).raws).toEqual({
            beforeClose: '/**/',
          }));

        it('undefined', () =>
          expect(node.clone({raws: undefined}).raws).toEqual({
            afterOpen: '  ',
          }));
      });

      describe('name', () => {
        it('defined', () =>
          expect(node.clone({name: 'supports'})).toHaveInterpolation(
            'name',
            'supports',
          ));

        it('undefined', () =>
          expect(node.clone({name: undefined})).toHaveInterpolation(
            'name',
            'media',
          ));
      });

      describe('argument', () => {
        it('defined', () =>
          expect(node.clone({argument: 'print'})).toHaveInterpolation(
            'argument',
            'print',
          ));

        it('undefined', () =>
          expect(node.clone({argument: undefined})).toHaveInterpolation(
            'argument',
            'screen',
          ));
      });
    });
  });

  it('toJSON', () =>
    expect(
      utils.parseIfConditionExpression('media(screen)'),
    ).toMatchSnapshot());
});
