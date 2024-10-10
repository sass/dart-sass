// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {ConfiguredVariable, StringExpression, UseRule, sass, scss} from '../..';

describe('a configured variable', () => {
  let node: ConfiguredVariable;
  beforeEach(
    () =>
      void (node = new ConfiguredVariable({
        name: 'foo',
        value: {text: 'bar', quotes: true},
      }))
  );

  describe('unguarded', () => {
    function describeNode(
      description: string,
      create: () => ConfiguredVariable
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('configured-variable'));

        it('has a name', () => expect(node.name).toBe('foo'));

        it('has a value', () =>
          expect(node).toHaveStringExpression('value', 'bar'));

        it("isn't guarded", () => expect(node.guarded).toBe(false));
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (
          scss.parse('@use "baz" with ($foo: "bar")').nodes[0] as UseRule
        ).configuration.get('foo')!
    );

    describeNode(
      'parsed as Sass',
      () =>
        (
          sass.parse('@use "baz" with ($foo: "bar")').nodes[0] as UseRule
        ).configuration.get('foo')!
    );

    describe('constructed manually', () => {
      describe('with an array', () => {
        describeNode(
          'with an Expression',
          () =>
            new ConfiguredVariable([
              'foo',
              new StringExpression({text: 'bar', quotes: true}),
            ])
        );

        describeNode(
          'with ExpressionProps',
          () => new ConfiguredVariable(['foo', {text: 'bar', quotes: true}])
        );

        describe('with an object', () => {
          describeNode(
            'with an expression',
            () =>
              new ConfiguredVariable([
                'foo',
                {value: new StringExpression({text: 'bar', quotes: true})},
              ])
          );

          describeNode(
            'with ExpressionProps',
            () =>
              new ConfiguredVariable([
                'foo',
                {value: {text: 'bar', quotes: true}},
              ])
          );
        });
      });

      describe('with an object', () => {
        describeNode(
          'with an expression',
          () =>
            new ConfiguredVariable({
              name: 'foo',
              value: new StringExpression({text: 'bar', quotes: true}),
            })
        );

        describeNode(
          'with ExpressionProps',
          () =>
            new ConfiguredVariable({
              name: 'foo',
              value: {text: 'bar', quotes: true},
            })
        );
      });
    });
  });

  describe('guarded', () => {
    function describeNode(
      description: string,
      create: () => ConfiguredVariable
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('configured-variable'));

        it('has a name', () => expect(node.name).toBe('foo'));

        it('has a value', () =>
          expect(node).toHaveStringExpression('value', 'bar'));

        it('is guarded', () => expect(node.guarded).toBe(true));
      });
    }

    // We can re-enable these once ForwardRule exists.
    // describeNode(
    //   'parsed as SCSS',
    //   () =>
    //     (
    //       scss.parse('@forward "baz" with ($foo: "bar" !default)')
    //         .nodes[0] as ForwardRule
    //     ).configuration.get('foo')!
    // );
    //
    // describeNode(
    //   'parsed as Sass',
    //   () =>
    //     (
    //       sass.parse('@forward "baz" with ($foo: "bar" !default)')
    //         .nodes[0] as ForwardRule
    //     ).configuration.get('foo')!
    // );

    describe('constructed manually', () => {
      describe('with an array', () => {
        describeNode(
          'with an expression',
          () =>
            new ConfiguredVariable([
              'foo',
              {
                value: new StringExpression({text: 'bar', quotes: true}),
                guarded: true,
              },
            ])
        );

        describeNode(
          'with ExpressionProps',
          () =>
            new ConfiguredVariable([
              'foo',
              {value: {text: 'bar', quotes: true}, guarded: true},
            ])
        );
      });

      describe('with an object', () => {
        describeNode(
          'with an expression',
          () =>
            new ConfiguredVariable({
              name: 'foo',
              value: new StringExpression({text: 'bar', quotes: true}),
              guarded: true,
            })
        );

        describeNode(
          'with ExpressionProps',
          () =>
            new ConfiguredVariable({
              name: 'foo',
              value: {text: 'bar', quotes: true},
              guarded: true,
            })
        );
      });
    });
  });

  it('assigned a new name', () => {
    node.name = 'baz';
    expect(node.name).toBe('baz');
  });

  it('assigned a new value', () => {
    const old = node.value;
    node.value = {text: 'baz', quotes: true};
    expect(old.parent).toBeUndefined();
    expect(node).toHaveStringExpression('value', 'baz');
    expect(node.value.parent).toBe(node);
  });

  it('assigned a new guarded', () => {
    node.guarded = true;
    expect(node.guarded).toBe(true);
  });

  describe('clone()', () => {
    let original: ConfiguredVariable;
    beforeEach(() => {
      original = (
        scss.parse('@use "foo" with ($foo: "bar")').nodes[0] as UseRule
      ).configuration.get('foo')!;
      original.raws.between = ' : ';
    });

    describe('with no overrides', () => {
      let clone: ConfiguredVariable;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('name', () => expect(clone.name).toBe('foo'));

        it('value', () => expect(clone).toHaveStringExpression('value', 'bar'));

        it('guarded', () => expect(clone.guarded).toBe(false));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['value', 'raws'] as const) {
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

      describe('name', () => {
        it('defined', () =>
          expect(original.clone({name: 'baz'}).name).toBe('baz'));

        it('undefined', () =>
          expect(original.clone({name: undefined}).name).toBe('foo'));
      });

      describe('value', () => {
        it('defined', () =>
          expect(
            original.clone({value: {text: 'baz', quotes: true}})
          ).toHaveStringExpression('value', 'baz'));

        it('undefined', () =>
          expect(original.clone({value: undefined})).toHaveStringExpression(
            'value',
            'bar'
          ));
      });

      describe('guarded', () => {
        it('defined', () =>
          expect(original.clone({guarded: true}).guarded).toBe(true));

        it('undefined', () =>
          expect(original.clone({guarded: undefined}).guarded).toBe(false));
      });
    });
  });

  it('toJSON', () =>
    expect(
      (
        scss.parse('@use "foo" with ($baz: "qux")').nodes[0] as UseRule
      ).configuration.get('baz')
    ).toMatchSnapshot());
});
