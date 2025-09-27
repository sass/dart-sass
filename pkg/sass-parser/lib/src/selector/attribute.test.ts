// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {AttributeSelector, Interpolation, QualifiedName} from '../..';
import {
  fromSimpleSelectorProps,
  parseSimpleSelector,
} from '../../../test/utils';

describe('a class selector', () => {
  let node: AttributeSelector;

  describe('with no value', () => {
    function describeNode(
      description: string,
      create: () => AttributeSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType attribute', () =>
          expect(node.sassType).toBe('attribute'));

        it('has an attribute', () => {
          expect(node.attribute.toString()).toEqual('foo');
          expect(node.attribute.sassType).toEqual('qualified-name');
          expect(node.attribute.parent).toBe(node);
        });

        it('has no operator', () => expect(node.operator).toBeUndefined());

        it('has no value', () => expect(node.value).toBeUndefined());

        it('has no modifier', () => expect(node.modifier).toBeUndefined());
      });
    }

    describeNode('parsed', () => parseSimpleSelector('[foo]'));

    describeNode(
      'constructed manually',
      () => new AttributeSelector({attribute: 'foo'}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({attribute: 'foo'}),
    );
  });

  describe('with an identifier value', () => {
    function describeNode(
      description: string,
      create: () => AttributeSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType attribute', () =>
          expect(node.sassType).toBe('attribute'));

        it('has an attribute', () =>
          expect(node).toHaveInterpolation('attribute', 'foo'));

        it('has an operator', () => expect(node.operator).toBe('='));

        it('has a value', () =>
          expect(node).toHaveInterpolation('value', 'bar'));

        it('has no modifier', () => expect(node.modifier).toBeUndefined());
      });
    }

    describeNode('parsed', () => parseSimpleSelector('[foo=bar]'));

    describeNode(
      'constructed manually',
      () =>
        new AttributeSelector({attribute: 'foo', operator: '=', value: 'bar'}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({attribute: 'foo', operator: '=', value: 'bar'}),
    );
  });

  describe('with a string value', () => {
    function describeNode(
      description: string,
      create: () => AttributeSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType attribute', () =>
          expect(node.sassType).toBe('attribute'));

        it('has an attribute', () =>
          expect(node).toHaveInterpolation('attribute', 'foo'));

        it('has an operator', () => expect(node.operator).toBe('='));

        it('has a value', () =>
          expect(node).toHaveInterpolation('value', '"\\0a"'));

        it('has no modifier', () => expect(node.modifier).toBeUndefined());
      });
    }

    describeNode('parsed', () => parseSimpleSelector('[foo="\\0a"]'));

    describeNode(
      'constructed manually',
      () =>
        new AttributeSelector({
          attribute: 'foo',
          operator: '=',
          value: '"\\0a"',
        }),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({
        attribute: 'foo',
        operator: '=',
        value: '"\\0a"',
      }),
    );
  });

  describe('with a modifier', () => {
    function describeNode(
      description: string,
      create: () => AttributeSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType attribute', () =>
          expect(node.sassType).toBe('attribute'));

        it('has an attribute', () =>
          expect(node).toHaveInterpolation('attribute', 'foo'));

        it('has an operator', () => expect(node.operator).toBe('='));

        it('has no value', () =>
          expect(node).toHaveInterpolation('value', 'bar'));

        it('has no modifier', () =>
          expect(node).toHaveInterpolation('modifier', 'baz'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('[foo=bar baz]'));

    describeNode(
      'constructed manually',
      () =>
        new AttributeSelector({
          attribute: 'foo',
          operator: '=',
          value: 'bar',
          modifier: 'baz',
        }),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({
        attribute: 'foo',
        operator: '=',
        value: 'bar',
        modifier: 'baz',
      }),
    );
  });

  describe('with interpolation', () => {
    function describeNode(
      description: string,
      create: () => AttributeSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType attribute', () =>
          expect(node.sassType).toBe('attribute'));

        it('has an attribute', () =>
          expect(node.attribute).toHaveStringExpression(0, 'foo'));

        it('has an operator', () => expect(node.operator).toBe('='));

        it('has a value', () =>
          expect(node.attribute).toHaveStringExpression(0, 'bar'));

        it('has a modifier', () =>
          expect(node.attribute).toHaveStringExpression(0, 'baz'));
      });
    }

    describeNode('parsed', () => parseSimpleSelector('[#{foo}=#{bar} #{baz}]'));

    describeNode(
      'constructed manually',
      () =>
        new AttributeSelector({
          attribute: [{text: 'foo'}],
          operator: '=',
          value: [{text: 'bar'}],
          modifier: [{text: 'baz'}],
        }),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({
        attribute: [{text: 'foo'}],
        operator: '=',
        value: [{text: 'bar'}],
        modifier: [{text: 'baz'}],
      }),
    );
  });

  describe('assigned new', () => {
    beforeEach(() => void (node = parseSimpleSelector('[foo=bar baz]')));

    describe('operator', () => {
      it('defined', () => {
        node.operator = '~=';
        expect(node.operator).toEqual('~=');
      });

      it('undefined', () => {
        node.operator = undefined;
        expect(node.operator).toBeUndefined();
      });
    });

    describe('attribute', () => {
      it("removes the old attribute's parent", () => {
        const oldAttribute = node.attribute;
        node.attribute = 'qux';
        expect(oldAttribute.parent).toBeUndefined();
      });

      it('assigns attribute explicitly', () => {
        const attribute = new QualifiedName('qux');
        node.attribute = attribute;
        expect(node.attribute).toBe(attribute);
        expect(node.attribute.parent).toBe(node);
      });

      it('assigns attribute as Interpolation', () => {
        const attribute = new Interpolation('qux');
        node.attribute = attribute;
        expect(node.attribute.sassType).toEqual('qualified-name');
        expect(node.attribute.toString()).toEqual('qux');
        expect(node.attribute.parent).toBe(node);
      });

      it('assigns attribute as InterpolationProps', () => {
        node.attribute = 'qux';
        expect(node).toHaveInterpolation('attribute', 'qux');
      });
    });

    describe('value', () => {
      it("removes the old value's parent", () => {
        const oldValue = node.value;
        node.value = 'qux';
        expect(oldValue!.parent).toBeUndefined();
      });

      it('assigns value explicitly', () => {
        const value = new Interpolation('qux');
        node.value = value;
        expect(node.value).toBe(value);
        expect(node).toHaveInterpolation('value', 'qux');
      });

      it('assigns value as InterpolationProps', () => {
        node.value = 'qux';
        expect(node).toHaveInterpolation('value', 'qux');
      });

      it('assigns undefined value', () => {
        const oldValue = node.value;
        node.value = undefined;
        expect(oldValue!.parent).toBeUndefined();
        expect(node.value).toBeUndefined();
      });
    });

    describe('modifier', () => {
      it("removes the old modifier's parent", () => {
        const oldModifier = node.modifier;
        node.modifier = 'qux';
        expect(oldModifier!.parent).toBeUndefined();
      });

      it('assigns modifier explicitly', () => {
        const modifier = new Interpolation('qux');
        node.modifier = modifier;
        expect(node.modifier).toBe(modifier);
        expect(node).toHaveInterpolation('modifier', 'qux');
      });

      it('assigns modifier as InterpolationProps', () => {
        node.modifier = 'qux';
        expect(node).toHaveInterpolation('modifier', 'qux');
      });

      it('assigns undefined modifier', () => {
        const oldModifier = node.modifier;
        node.modifier = undefined;
        expect(oldModifier!.parent).toBeUndefined();
        expect(node.modifier).toBeUndefined();
      });
    });
  });

  describe('stringifies', () => {
    describe('with no value', () => {
      it('with no raws', () =>
        expect(new AttributeSelector({attribute: 'foo'}).toString()).toBe(
          '[foo]',
        ));

      it('with afterOpen', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            raws: {afterOpen: '  '},
          }).toString(),
        ).toBe('[  foo]'));

      it('with beforeClose', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            raws: {afterOpen: '  '},
          }).toString(),
        ).toBe('[foo  ]'));

      it('ignores beforeOperator', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            raws: {beforeOperator: '  '},
          }).toString(),
        ).toBe('[foo]'));

      it('ignores afterOperator', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            raws: {afterOperator: '  '},
          }).toString(),
        ).toBe('[foo]'));

      it('ignores afterValue', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            raws: {afterValue: '  '},
          }).toString(),
        ).toBe('[foo]'));
    });

    describe('with a value', () => {
      it('with no raws', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
          }).toString(),
        ).toBe('[foo=bar]'));

      it('with afterOpen', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {afterOpen: '  '},
          }).toString(),
        ).toBe('[  foo=bar]'));

      it('with beforeClose', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {beforeClose: '  '},
          }).toString(),
        ).toBe('[foo=bar  ]'));

      it('with beforeOperator', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {beforeOperator: '  '},
          }).toString(),
        ).toBe('[foo  =bar]'));

      it('with afterOperator', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {afterOperator: '  '},
          }).toString(),
        ).toBe('[foo=  bar]'));

      it('with afterValue', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {afterValue: '  '},
          }).toString(),
        ).toBe('[foo=bar  ]'));

      it('with afterValue and beforeClose', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {afterValue: '  ', beforeClose: '/**/'},
          }).toString(),
        ).toBe('[foo=bar  /**/]'));
    });

    describe('with a modifier', () => {
      it('with no raws', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            modifier: 's',
          }).toString(),
        ).toBe('[foo=bar s]'));

      it('with afterOpen', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {afterOpen: '  '},
          }).toString(),
        ).toBe('[  foo=bar s]'));

      it('with beforeClose', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {beforeClose: '  '},
          }).toString(),
        ).toBe('[foo=bar s  ]'));

      it('with beforeOperator', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {beforeOperator: '  '},
          }).toString(),
        ).toBe('[foo  =bar s]'));

      it('with afterOperator', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {afterOperator: '  '},
          }).toString(),
        ).toBe('[foo=  bar s]'));

      it('with afterValue', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {afterValue: '  '},
          }).toString(),
        ).toBe('[foo=bar  s]'));

      it('with afterValue and beforeClose', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            value: 'bar',
            raws: {afterValue: '  ', beforeClose: '/**/'},
          }).toString(),
        ).toBe('[foo=bar  s/**/]'));
    });

    describe('with an operator but no value', () => {
      it('without a modifier', () =>
        expect(
          new AttributeSelector({attribute: 'foo', operator: '='}).toString(),
        ).toBe('[foo]'));

      it('with a modifier', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            operator: '=',
            modifier: 's',
          }).toString(),
        ).toBe('[foo]'));
    });

    describe('with a value but no operator', () => {
      it('without a modifier', () =>
        expect(
          new AttributeSelector({attribute: 'foo', value: 'bar'}).toString(),
        ).toBe('[foo]'));

      it('with a modifier', () =>
        expect(
          new AttributeSelector({
            attribute: 'foo',
            value: 'bar',
            modifier: 's',
          }).toString(),
        ).toBe('[foo]'));
    });
  });

  describe('clone', () => {
    let original: AttributeSelector;

    beforeEach(() => {
      original = parseSimpleSelector('[foo=bar baz]');
    });

    describe('with no overrides', () => {
      let clone: AttributeSelector;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('attribute', () => {
          expect(clone.attribute.toString()).toEqual('foo');
          expect(clone.attribute.parent).toBe(clone);
        });

        it('operator', () => expect(clone.operator).toEqual('='));

        it('value', () => expect(clone).toHaveInterpolation('value', 'bar'));

        it('modifier', () =>
          expect(clone).toHaveInterpolation('modifier', 'baz'));

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of [
          'attribute',
          'value',
          'modifier',
          'raws',
        ] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('attribute', () => {
        it('defined', () =>
          expect(original.clone({attribute: 'qux'})).toHaveInterpolation(
            'attribute',
            'qux',
          ));

        it('undefined', () =>
          expect(original.clone({attribute: undefined})).toHaveInterpolation(
            'attribute',
            'foo',
          ));
      });

      describe('operator', () => {
        it('defined', () =>
          expect(original.clone({operator: '~='}).operator).toEqual('~='));

        it('undefined', () =>
          expect(
            original.clone({operator: undefined}).operator,
          ).toBeUndefined());
      });

      describe('value', () => {
        it('defined', () =>
          expect(original.clone({value: 'qux'})).toHaveInterpolation(
            'value',
            'qux',
          ));

        it('undefined', () =>
          expect(original.clone({attribute: undefined}).value).toBeUndefined());
      });

      describe('modifier', () => {
        it('defined', () =>
          expect(original.clone({value: 'qux'})).toHaveInterpolation(
            'modifier',
            'qux',
          ));

        it('undefined', () =>
          expect(
            original.clone({attribute: undefined}).modifier,
          ).toBeUndefined());
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {}}).raws).toEqual({}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({}));
      });
    });
  });

  describe('toJSON', () => {
    it('with no value', () =>
      expect(parseSimpleSelector('[foo]')).toMatchSnapshot());

    it('with a value', () =>
      expect(parseSimpleSelector('[foo=bar]')).toMatchSnapshot());

    it('with a modifier', () =>
      expect(parseSimpleSelector('[foo=bar s]')).toMatchSnapshot());
  });
});
