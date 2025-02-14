// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {MapEntry, MapExpression, StringExpression} from '../..';
import * as utils from '../../../test/utils';

describe('a map entry', () => {
  let node: MapEntry;
  beforeEach(
    () =>
      void (node = new MapEntry({
        key: {text: 'foo'},
        value: {text: 'bar'},
      })),
  );

  function describeNode(description: string, create: () => MapEntry): void {
    describe(description, () => {
      beforeEach(() => (node = create()));

      it('has a sassType', () =>
        expect(node.sassType.toString()).toBe('map-entry'));

      it('has a key', () => expect(node).toHaveStringExpression('key', 'foo'));

      it('has a value', () =>
        expect(node).toHaveStringExpression('value', 'bar'));
    });
  }

  describeNode(
    'parsed',
    () => (utils.parseExpression('(foo: bar)') as MapExpression).nodes[0],
  );

  describe('constructed manually', () => {
    describe('with an array', () => {
      describeNode(
        'with two Expressions',
        () =>
          new MapEntry([
            new StringExpression({text: 'foo'}),
            new StringExpression({text: 'bar'}),
          ]),
      );

      describeNode(
        'with two ExpressionProps',
        () => new MapEntry([{text: 'foo'}, {text: 'bar'}]),
      );

      describeNode(
        'with mixed Expressions and ExpressionProps',
        () =>
          new MapEntry([{text: 'foo'}, new StringExpression({text: 'bar'})]),
      );
    });

    describe('with an object', () => {
      describeNode(
        'with two Expressions',
        () =>
          new MapEntry({
            key: new StringExpression({text: 'foo'}),
            value: new StringExpression({text: 'bar'}),
          }),
      );

      describeNode(
        'with ExpressionProps',
        () => new MapEntry({key: {text: 'foo'}, value: {text: 'bar'}}),
      );
    });
  });

  it('assigned a new key', () => {
    const old = node.key;
    node.key = {text: 'baz'};
    expect(old.parent).toBeUndefined();
    expect(node).toHaveStringExpression('key', 'baz');
  });

  it('assigned a new value', () => {
    const old = node.value;
    node.value = {text: 'baz'};
    expect(old.parent).toBeUndefined();
    expect(node).toHaveStringExpression('value', 'baz');
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(
          new MapEntry({
            key: {text: 'foo'},
            value: {text: 'bar'},
          }).toString(),
        ).toBe('foo: bar'));

      // raws.before is only used as part of a MapExpression
      it('ignores before', () =>
        expect(
          new MapEntry({
            key: {text: 'foo'},
            value: {text: 'bar'},
            raws: {before: '/**/'},
          }).toString(),
        ).toBe('foo: bar'));

      it('with between', () =>
        expect(
          new MapEntry({
            key: {text: 'foo'},
            value: {text: 'bar'},
            raws: {between: ' : '},
          }).toString(),
        ).toBe('foo : bar'));

      // raws.after is only used as part of a Configuration
      it('ignores after', () =>
        expect(
          new MapEntry({
            key: {text: 'foo'},
            value: {text: 'bar'},
            raws: {after: '/**/'},
          }).toString(),
        ).toBe('foo: bar'));
    });
  });

  describe('clone()', () => {
    let original: MapEntry;
    beforeEach(() => {
      original = (utils.parseExpression('(foo: bar)') as MapExpression)
        .nodes[0];
      original.raws.between = ' : ';
    });

    describe('with no overrides', () => {
      let clone: MapEntry;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('key', () => expect(clone).toHaveStringExpression('key', 'foo'));

        it('value', () => expect(clone).toHaveStringExpression('value', 'bar'));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['key', 'value', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {before: '  '}}).raws).toEqual({
            before: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            between: ' : ',
          }));
      });

      describe('key', () => {
        it('defined', () =>
          expect(original.clone({key: {text: 'baz'}})).toHaveStringExpression(
            'key',
            'baz',
          ));

        it('undefined', () =>
          expect(original.clone({key: undefined})).toHaveStringExpression(
            'key',
            'foo',
          ));
      });

      describe('value', () => {
        it('defined', () =>
          expect(original.clone({value: {text: 'baz'}})).toHaveStringExpression(
            'value',
            'baz',
          ));

        it('undefined', () =>
          expect(original.clone({value: undefined})).toHaveStringExpression(
            'value',
            'bar',
          ));
      });
    });
  });

  it('toJSON', () =>
    expect(
      (utils.parseExpression('(baz: qux)') as MapExpression).nodes[0],
    ).toMatchSnapshot());
});
