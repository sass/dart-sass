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

        it('has a name', () => expect(node.variable).toBe('foo'));

        it('has a value', () =>
          expect(node).toHaveStringExpression('expression', 'bar'));

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

        it('has a name', () => expect(node.variable).toBe('foo'));

        it('has a value', () =>
          expect(node).toHaveStringExpression('expression', 'bar'));

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

  it('assigned a new variable', () => {
    node.variable = 'baz';
    expect(node.variable).toBe('baz');
  });

  it('assigned a new expression', () => {
    const old = node.expression;
    node.expression = {text: 'baz', quotes: true};
    expect(old.parent).toBeUndefined();
    expect(node).toHaveStringExpression('expression', 'baz');
  });

  it('assigned a new guarded', () => {
    node.guarded = true;
    expect(node.guarded).toBe(true);
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('unguarded', () =>
          expect(
            new ConfiguredVariable({
              name: 'foo',
              value: {text: 'bar', quotes: true},
            }).toString()
          ).toBe('$foo: "bar"'));

        it('guarded', () =>
          expect(
            new ConfiguredVariable({
              name: 'foo',
              value: {text: 'bar', quotes: true},
              guarded: true,
            }).toString()
          ).toBe('$foo: "bar" !default'));

        it('with a non-identifier name', () =>
          expect(
            new ConfiguredVariable({
              name: 'f o',
              value: {text: 'bar', quotes: true},
            }).toString()
          ).toBe('$f\\20o: "bar"'));
      });

      // raws.before is only used as part of a Configuration
      it('ignores before', () =>
        expect(
          new ConfiguredVariable({
            name: 'foo',
            value: {text: 'bar', quotes: true},
            raws: {before: '/**/'},
          }).toString()
        ).toBe('$foo: "bar"'));

      it('with matching name', () =>
        expect(
          new ConfiguredVariable({
            name: 'foo',
            value: {text: 'bar', quotes: true},
            raws: {name: {raw: 'f\\6fo', value: 'foo'}},
          }).toString()
        ).toBe('$f\\6fo: "bar"'));

      it('with non-matching name', () =>
        expect(
          new ConfiguredVariable({
            name: 'foo',
            value: {text: 'bar', quotes: true},
            raws: {name: {raw: 'f\\41o', value: 'fao'}},
          }).toString()
        ).toBe('$foo: "bar"'));

      it('with between', () =>
        expect(
          new ConfiguredVariable({
            name: 'foo',
            value: {text: 'bar', quotes: true},
            raws: {between: ' : '},
          }).toString()
        ).toBe('$foo : "bar"'));

      it('with beforeGuard and a guard', () =>
        expect(
          new ConfiguredVariable({
            name: 'foo',
            value: {text: 'bar', quotes: true},
            guarded: true,
            raws: {beforeGuard: '/**/'},
          }).toString()
        ).toBe('$foo: "bar"/**/!default'));

      it('with beforeGuard and no guard', () =>
        expect(
          new ConfiguredVariable({
            name: 'foo',
            value: {text: 'bar', quotes: true},
            raws: {beforeGuard: '/**/'},
          }).toString()
        ).toBe('$foo: "bar"'));

      // raws.before is only used as part of a Configuration
      describe('ignores afterValue', () => {
        it('with no guard', () =>
          expect(
            new ConfiguredVariable({
              name: 'foo',
              value: {text: 'bar', quotes: true},
              raws: {afterValue: '/**/'},
            }).toString()
          ).toBe('$foo: "bar"'));

        it('with a guard', () =>
          expect(
            new ConfiguredVariable({
              name: 'foo',
              value: {text: 'bar', quotes: true},
              guarded: true,
              raws: {afterValue: '/**/'},
            }).toString()
          ).toBe('$foo: "bar" !default'));
      });
    });
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
        it('variable', () => expect(clone.variable).toBe('foo'));

        it('expression', () => expect(clone).toHaveStringExpression('expression', 'bar'));

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

      describe('variable', () => {
        it('defined', () =>
          expect(original.clone({name: 'baz'}).variable).toBe('baz'));

        it('undefined', () =>
          expect(original.clone({name: undefined}).variable).toBe('foo'));
      });

      describe('expression', () => {
        it('defined', () =>
          expect(
            original.clone({expression: {text: 'baz', quotes: true}})
          ).toHaveStringExpression('expression', 'baz'));

        it('undefined', () =>
          expect(original.clone({expression: undefined})).toHaveStringExpression(
            'expression',
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
