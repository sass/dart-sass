// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {SassColor} from 'sass';

import {ColorExpression} from '../..';
import * as utils from '../../../test/utils';

const blue = new SassColor({space: 'rgb', red: 0, green: 0, blue: 255});

describe('a color expression', () => {
  let node: ColorExpression;

  describe('with no alpha', () => {
    function describeNode(
      description: string,
      create: () => ColorExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType color', () => expect(node.sassType).toBe('color'));

        it('is a color', () => expect(node.value).toEqual(blue));
      });
    }

    describe('parsed', () => {
      describeNode('hex', () => utils.parseExpression('#00f'));

      describeNode('keyword', () => utils.parseExpression('blue'));
    });

    describeNode(
      'constructed manually',
      () => new ColorExpression({value: blue}),
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({value: blue}),
    );
  });

  describe('with alpha', () => {
    function describeNode(
      description: string,
      create: () => ColorExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType color', () => expect(node.sassType).toBe('color'));

        it('is a color', () =>
          expect(node.value).toEqual(
            new SassColor({
              space: 'rgb',
              red: 10,
              green: 20,
              blue: 30,
              alpha: 0.4,
            }),
          ));
      });
    }

    describeNode('parsed', () => utils.parseExpression('#0a141E66'));

    describeNode(
      'constructed manually',
      () =>
        new ColorExpression({
          value: new SassColor({
            space: 'rgb',
            red: 10,
            green: 20,
            blue: 30,
            alpha: 0.4,
          }),
        }),
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({
        value: new SassColor({
          space: 'rgb',
          red: 10,
          green: 20,
          blue: 30,
          alpha: 0.4,
        }),
      }),
    );
  });

  describe('throws an error for non-RGB colors', () => {
    beforeEach(() => void (node = utils.parseExpression('#123')));

    it('in the constructor', () =>
      expect(
        () =>
          new ColorExpression({
            value: new SassColor({
              space: 'hsl',
              hue: 180,
              saturation: 50,
              lightness: 50,
            }),
          }),
      ).toThrow());

    it('in the property', () =>
      expect(() => {
        node.value = new SassColor({
          space: 'hsl',
          hue: 180,
          saturation: 50,
          lightness: 50,
        });
      }).toThrow());

    it('in clone', () =>
      expect(() =>
        node.clone({
          value: new SassColor({
            space: 'hsl',
            hue: 180,
            saturation: 50,
            lightness: 50,
          }),
        }),
      ).toThrow());
  });

  describe('assigned new', () => {
    beforeEach(() => void (node = utils.parseExpression('#123')));

    it('value', () => {
      node.value = new SassColor({
        space: 'rgb',
        red: 10,
        green: 20,
        blue: 30,
        alpha: 0.4,
      });
      expect(node.value).toEqual(
        new SassColor({
          space: 'rgb',
          red: 10,
          green: 20,
          blue: 30,
          alpha: 0.4,
        }),
      );
    });
  });

  describe('stringifies', () => {
    it('without alpha', () =>
      expect(utils.parseExpression('#abc').toString()).toBe('#aabbcc'));

    it('with alpha', () =>
      expect(utils.parseExpression('#abcd').toString()).toBe('#aabbccdd'));

    describe('raws', () => {
      it('with the same raw value as the expression', () =>
        expect(
          new ColorExpression({
            value: blue,
            raws: {value: {raw: 'blue', value: blue}},
          }).toString(),
        ).toBe('blue'));

      it('with a different raw value than the expression', () =>
        expect(
          new ColorExpression({
            value: new SassColor({space: 'rgb', red: 10, green: 20, blue: 30}),
            raws: {value: {raw: 'blue', value: blue}},
          }).toString(),
        ).toBe('#0a141e'));
    });
  });

  describe('clone', () => {
    let original: ColorExpression;

    beforeEach(() => {
      original = utils.parseExpression('#00f');
      // TODO: remove this once raws are properly parsed.
      original.raws.value = {raw: 'blue', value: blue};
    });

    describe('with no overrides', () => {
      let clone: ColorExpression;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('value', () => expect(clone.value).toEqual(blue));

        it('raws', () => {
          expect(clone.raws.value!.raw).toBe('blue');
          expect(clone.raws.value!.value).toEqual(blue);
        });

        it('source', () => expect(clone.source).toBe(original.source));
      });

      it('creates a new self', () => expect(clone).not.toBe(original));
    });

    describe('overrides', () => {
      describe('value', () => {
        it('defined', () =>
          expect(
            original.clone({
              value: new SassColor({
                space: 'rgb',
                red: 10,
                green: 20,
                blue: 30,
              }),
            }).value,
          ).toEqual(
            new SassColor({space: 'rgb', red: 10, green: 20, blue: 30}),
          ));

        it('undefined', () =>
          expect(original.clone({value: undefined}).value).toEqual(blue));
      });

      describe('raws', () => {
        it('defined', () =>
          expect(
            original.clone({raws: {value: {raw: '#0000FF', value: blue}}}).raws
              .value!.raw,
          ).toBe('#0000FF'));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws.value!.raw).toBe(
            'blue',
          ));
      });
    });
  });

  it('toJSON', () => expect(utils.parseExpression('#00f')).toMatchSnapshot());
});
