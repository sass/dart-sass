// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {IfConditionRaw, Interpolation} from '../../..';
import * as utils from '../../../../test/utils';

describe('a raw if() condition', () => {
  let node: IfConditionRaw;
  beforeEach(() => {
    node = new IfConditionRaw({
      rawInterpolation: [{text: 'media(screen)', quotes: true}],
    });
  });

  function describeNode(
    description: string,
    create: () => IfConditionRaw,
  ): void {
    describe(description, () => {
      beforeEach(() => (node = create()));

      it('has a sassType', () =>
        expect(node.sassType.toString()).toBe('if-condition-raw'));

      it('has a rawInterpolation', () =>
        expect(node).toHaveInterpolation(
          'rawInterpolation',
          '#{"media(screen)"}',
        ));
    });
  }

  describeNode('parsed', () =>
    utils.parseIfConditionExpression('#{"media(screen)"}'),
  );

  describe('constructed manually', () => {
    describeNode(
      'with Interpolation',
      () =>
        new IfConditionRaw({
          rawInterpolation: new Interpolation([
            {text: 'media(screen)', quotes: true},
          ]),
        }),
    );

    describeNode(
      'with InterpolationProps',
      () =>
        new IfConditionRaw({
          rawInterpolation: [{text: 'media(screen)', quotes: true}],
        }),
    );
  });

  describe('constructed from IfConditionExpressionProps', () => {
    describeNode('with Interpolation', () =>
      utils.fromIfConditionExpressionProps({
        rawInterpolation: new Interpolation([
          {text: 'media(screen)', quotes: true},
        ]),
      }),
    );

    describeNode('with InterpolationProps', () =>
      utils.fromIfConditionExpressionProps({
        rawInterpolation: [{text: 'media(screen)', quotes: true}],
      }),
    );
  });

  describe('assigned a new rawInterpolation', () => {
    it('Interpolation', () => {
      const old = node.rawInterpolation;
      const rawInterpolation = new Interpolation('supports(a: b)');
      node.rawInterpolation = rawInterpolation;
      expect(old.parent).toBeUndefined();
      expect(node.rawInterpolation).toBe(rawInterpolation);
      expect(node).toHaveInterpolation('rawInterpolation', 'supports(a: b)');
    });

    it('InterpolationProps as a string', () => {
      const old = node.rawInterpolation;
      node.rawInterpolation = 'supports(a: b)';
      expect(old.parent).toBeUndefined();
      expect(node).toHaveInterpolation('rawInterpolation', 'supports(a: b)');
    });

    it('InterpolationProps as an object', () => {
      const old = node.rawInterpolation;
      node.rawInterpolation = {nodes: ['supports(a: b)']};
      expect(old.parent).toBeUndefined();
      expect(node).toHaveInterpolation('rawInterpolation', 'supports(a: b)');
    });
  });

  it('stringifies', () => expect(node.toString()).toBe('#{"media(screen)"}'));

  describe('clone()', () => {
    describe('with no overrides', () => {
      let clone: IfConditionRaw;
      beforeEach(() => void (clone = node.clone()));

      describe('has the same properties:', () => {
        it('rawInterpolation', () =>
          expect(clone).toHaveInterpolation(
            'rawInterpolation',
            '#{"media(screen)"}',
          ));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(node));

        for (const attr of ['rawInterpolation', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(node[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('rawInterpolation', () => {
        it('defined', () =>
          expect(
            node.clone({rawInterpolation: 'supports(a: b)'}),
          ).toHaveInterpolation('rawInterpolation', 'supports(a: b)'));

        it('undefined', () =>
          expect(node.clone({rawInterpolation: undefined})).toHaveInterpolation(
            'rawInterpolation',
            '#{"media(screen)"}',
          ));
      });
    });
  });

  it('toJSON', () =>
    expect(
      utils.parseIfConditionExpression('#{"media(screen)"}'),
    ).toMatchSnapshot());
});
