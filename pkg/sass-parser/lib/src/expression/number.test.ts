// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Value} from 'sass';
import {NumberExpression} from '../..';
import * as utils from '../../../test/utils';

describe('a number expression', () => {
  let node: NumberExpression;

  describe('unitless', () => {
    function describeNode(
      description: string,
      create: () => NumberExpression
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType number', () => expect(node.sassType).toBe('number'));

        it('is a number', () => expect(node.value).toBe(123));

        it('has no unit', () => expect(node.unit).toBeNull());
      });
    }

    describeNode('parsed', () => utils.parseExpression('123'));

    describeNode(
      'constructed manually',
      () =>
        new NumberExpression({
          value: 123,
        })
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({
        value: 123,
      })
    );
  });

  describe('with a unit', () => {
    function describeNode(
      description: string,
      create: () => NumberExpression
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType number', () => expect(node.sassType).toBe('number'));

        it('is a number', () => expect(node.value).toBe(123));

        it('has a unit', () => expect(node.unit).toBe('px'));
      });
    }

    describeNode('parsed', () => utils.parseExpression('123px'));

    describeNode(
      'constructed manually',
      () =>
        new NumberExpression({
          value: 123,
          unit: 'px',
        })
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({
        value: 123,
        unit: 'px',
      })
    );
  });

  describe('floating-point number', () => {
    describe('unitless', () => {
      beforeEach(() => void (node = utils.parseExpression('3.14')));

      it('value', () => expect(node.value).toBe(3.14));

      it('unit', () => expect(node.unit).toBeNull());
    });

    describe('with a unit', () => {
      beforeEach(() => void (node = utils.parseExpression('1.618px')));

      it('value', () => expect(node.value).toBe(1.618));

      it('unit', () => expect(node.unit).toBe('px'));
    });
  });

  describe('assigned new', () => {
    beforeEach(() => void (node = utils.parseExpression('123')));

    it('value', () => {
      node.value = 456;
      expect(node.value).toBe(456);
    });

    it('unit', () => {
      node.unit = 'px';
      expect(node.unit).toBe('px');
    });
  });

  describe('stringifies', () => {
    it('unitless', () =>
      expect(utils.parseExpression('123').toString()).toBe('123'));

    it('with a unit', () =>
      expect(utils.parseExpression('123px').toString()).toBe('123px'));

    it('floating-point number', () =>
      expect(utils.parseExpression('3.14').toString()).toBe('3.14'));

    it('respects raws', () =>
      expect(
        new NumberExpression({
          value: 123,
          raws: {value: '0123.0'},
        }).toString()
      ).toBe('0123.0'));
  });

  describe('clone', () => {
    let original: NumberExpression;

    beforeEach(() => {
      original = utils.parseExpression('123');
      // TODO: remove this once raws are properly parsed.
      original.raws.value = '0123.0';
    });

    describe('with no overrides', () => {
      let clone: NumberExpression;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('value', () => expect(clone.value).toBe(123));

        it('unit', () => expect(clone.unit).toBeNull());

        it('raws', () => expect(clone.raws).toEqual({value: '0123.0'}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));
      });
    });

    describe('overrides', () => {
      describe('value', () => {
        it('defined', () =>
          expect(original.clone({value: 123}).value).toBe(123));

        it('undefined', () =>
          expect(original.clone({value: undefined}).value).toBe(123));
      });

      describe('unit', () => {
        it('defined', () =>
          expect(original.clone({unit: 'px'}).unit).toBe('px'));

        it('undefined', () =>
          expect(original.clone({unit: undefined}).unit).toBeNull());
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {value: '1e3'}}).raws).toEqual({
            value: '1e3',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            value: '0123.0',
          }));
      });
    });
  });

  it('toJSON', () => expect(utils.parseExpression('123%')).toMatchSnapshot());
});
