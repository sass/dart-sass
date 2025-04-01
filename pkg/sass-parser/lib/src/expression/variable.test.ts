// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {VariableExpression} from '../..';
import * as utils from '../../../test/utils';

describe('a variable expression', () => {
  let node: VariableExpression;

  describe('with no namespace', () => {
    function describeNode(
      description: string,
      create: () => VariableExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType variable', () =>
          expect(node.sassType).toBe('variable'));

        it('has no namespace', () => expect(node.namespace).toBe(undefined));

        it('has a name', () => expect(node.variableName).toBe('foo'));
      });
    }

    describeNode('parsed', () => utils.parseExpression('$foo'));

    describeNode(
      'constructed manually',
      () => new VariableExpression({variableName: 'foo'}),
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({variableName: 'foo'}),
    );
  });

  describe('with a namespace', () => {
    function describeNode(
      description: string,
      create: () => VariableExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType variable', () =>
          expect(node.sassType).toBe('variable'));

        it('has a namespace', () => expect(node.namespace).toBe('bar'));

        it('has a name', () => expect(node.variableName).toBe('foo'));
      });
    }

    describeNode('parsed', () => utils.parseExpression('bar.$foo'));

    describeNode(
      'constructed manually',
      () =>
        new VariableExpression({
          namespace: 'bar',
          variableName: 'foo',
        }),
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({
        namespace: 'bar',
        variableName: 'foo',
      }),
    );
  });

  describe('assigned new namespace', () => {
    it('defined', () => {
      node = utils.parseExpression('bar.$foo');
      node.namespace = 'baz';
      expect(node.namespace).toBe('baz');
    });

    it('undefined', () => {
      node = utils.parseExpression('bar.$foo');
      node.namespace = undefined;
      expect(node.namespace).toBe(undefined);
    });
  });

  it('assigned new name', () => {
    node = utils.parseExpression('$foo');
    node.variableName = 'baz';
    expect(node.variableName).toBe('baz');
  });

  describe('stringifies', () => {
    describe('with default raws', () => {
      it('with no namespace', () =>
        expect(new VariableExpression({variableName: 'foo'}).toString()).toBe(
          '$foo',
        ));

      describe('with a namespace', () => {
        it("that's an identifier", () =>
          expect(
            new VariableExpression({
              namespace: 'bar',
              variableName: 'foo',
            }).toString(),
          ).toBe('bar.$foo'));

        it("that's not an identifier", () =>
          expect(
            new VariableExpression({
              namespace: 'b r',
              variableName: 'foo',
            }).toString(),
          ).toBe('b\\20r.$foo'));
      });
    });

    it("with a name that's not an identifier", () =>
      expect(new VariableExpression({variableName: 'f o'}).toString()).toBe(
        '$f\\20o',
      ));

    it('with matching namespace', () =>
      expect(
        new VariableExpression({
          namespace: 'bar',
          variableName: 'foo',
          raws: {namespace: {value: 'bar', raw: 'b\\61r'}},
        }).toString(),
      ).toBe('b\\61r.$foo'));

    it('with non-matching namespace', () =>
      expect(
        new VariableExpression({
          namespace: 'zip',
          variableName: 'foo',
          raws: {namespace: {value: 'bar', raw: 'b\\61r'}},
        }).toString(),
      ).toBe('zip.$foo'));

    it('with matching name', () =>
      expect(
        new VariableExpression({
          variableName: 'foo',
          raws: {variableName: {value: 'foo', raw: 'f\\6fo'}},
        }).toString(),
      ).toBe('$f\\6fo'));

    it('with non-matching name', () =>
      expect(
        new VariableExpression({
          variableName: 'zip',
          raws: {variableName: {value: 'foo', raw: 'f\\6fo'}},
        }).toString(),
      ).toBe('$zip'));
  });

  describe('clone', () => {
    let original: VariableExpression;

    beforeEach(() => {
      original = utils.parseExpression('bar.$foo');
      // TODO: remove this once raws are properly parsed
      original.raws.variableName = {value: 'foo', raw: 'f\\6fo'};
    });

    describe('with no overrides', () => {
      let clone: VariableExpression;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('namespace', () => expect(clone.namespace).toBe('bar'));

        it('name', () => expect(clone.variableName).toBe('foo'));

        it('raws', () =>
          expect(clone.raws).toEqual({
            variableName: {value: 'foo', raw: 'f\\6fo'},
          }));

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
          expect(
            original.clone({raws: {namespace: {value: 'bar', raw: 'b\\61r'}}})
              .raws,
          ).toEqual({namespace: {value: 'bar', raw: 'b\\61r'}}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            variableName: {value: 'foo', raw: 'f\\6fo'},
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

      describe('variableName', () => {
        it('defined', () =>
          expect(original.clone({variableName: 'zip'}).variableName).toBe(
            'zip',
          ));

        it('undefined', () =>
          expect(original.clone({variableName: undefined}).variableName).toBe(
            'foo',
          ));
      });
    });
  });

  describe('toJSON', () => {
    it('without a namespace', () =>
      expect(utils.parseExpression('$foo')).toMatchSnapshot());

    it('with a namespace', () =>
      expect(utils.parseExpression('bar.$foo')).toMatchSnapshot());
  });
});
