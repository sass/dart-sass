// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  FunctionRule,
  Parameter,
  ParameterList,
  StringExpression,
  sass,
  scss,
} from '..';

describe('a parameter', () => {
  let node: Parameter;
  beforeEach(
    () =>
      void (node = new Parameter({
        name: 'foo',
        defaultValue: {text: 'bar', quotes: true},
      })),
  );

  describe('with no default', () => {
    function describeNode(description: string, create: () => Parameter): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('parameter'));

        it('has a name', () => expect(node.name).toBe('foo'));

        it('has no default value', () =>
          expect(node.defaultValue).toBeUndefined());

        it('is not a rest parameter', () => expect(node.rest).toBe(false));
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@function a($foo) {}').nodes[0] as FunctionRule).parameters
          .nodes[0],
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@function a($foo)').nodes[0] as FunctionRule).parameters
          .nodes[0],
    );

    describe('constructed manually', () => {
      describeNode('with a string', () => new Parameter('foo'));

      describeNode('with an object', () => new Parameter({name: 'foo'}));
    });

    describe('constructed from properties', () => {
      describeNode(
        'a string',
        () => new ParameterList({nodes: ['foo']}).nodes[0],
      );

      describeNode(
        'an object',
        () => new ParameterList({nodes: [{name: 'foo'}]}).nodes[0],
      );
    });
  });

  describe('with a default', () => {
    function describeNode(description: string, create: () => Parameter): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('parameter'));

        it('has a name', () => expect(node.name).toBe('foo'));

        it('has a default value', () =>
          expect(node).toHaveStringExpression('defaultValue', 'bar'));

        it('is not a rest parameter', () => expect(node.rest).toBe(false));
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@function a($foo: "bar") {}').nodes[0] as FunctionRule)
          .parameters.nodes[0],
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@function a($foo: "bar")').nodes[0] as FunctionRule)
          .parameters.nodes[0],
    );

    describe('constructed manually', () => {
      describe('with an array', () => {
        describeNode(
          'with an Expression',
          () =>
            new Parameter([
              'foo',
              new StringExpression({text: 'bar', quotes: true}),
            ]),
        );

        describeNode(
          'with ExpressionProps',
          () => new Parameter(['foo', {text: 'bar', quotes: true}]),
        );

        describe('with an object', () => {
          describeNode(
            'with an expression',
            () =>
              new Parameter([
                'foo',
                {
                  defaultValue: new StringExpression({
                    text: 'bar',
                    quotes: true,
                  }),
                },
              ]),
          );

          describeNode(
            'with ExpressionProps',
            () =>
              new Parameter([
                'foo',
                {defaultValue: {text: 'bar', quotes: true}},
              ]),
          );
        });
      });

      describe('with an object', () => {
        describeNode(
          'with an expression',
          () =>
            new Parameter({
              name: 'foo',
              defaultValue: new StringExpression({text: 'bar', quotes: true}),
            }),
        );

        describeNode(
          'with ExpressionProps',
          () =>
            new Parameter({
              name: 'foo',
              defaultValue: {text: 'bar', quotes: true},
            }),
        );
      });
    });

    describe('constructed from properties', () => {
      describe('an array', () => {
        describeNode(
          'with ExpressionProps',
          () =>
            new ParameterList({
              nodes: [['foo', {text: 'bar', quotes: true}]],
            }).nodes[0],
        );

        describeNode(
          'with an Expression',
          () =>
            new ParameterList({
              nodes: [
                ['foo', new StringExpression({text: 'bar', quotes: true})],
              ],
            }).nodes[0],
        );

        describeNode(
          'with ParameterObjectProps',
          () =>
            new ParameterList({
              nodes: [['foo', {defaultValue: {text: 'bar', quotes: true}}]],
            }).nodes[0],
        );
      });

      describe('an object', () => {
        describeNode(
          'with ExpressionProps',
          () =>
            new ParameterList({
              nodes: [{name: 'foo', defaultValue: {text: 'bar', quotes: true}}],
            }).nodes[0],
        );

        describeNode(
          'with an Expression',
          () =>
            new ParameterList({
              nodes: [
                {
                  name: 'foo',
                  defaultValue: new StringExpression({
                    text: 'bar',
                    quotes: true,
                  }),
                },
              ],
            }).nodes[0],
        );
      });
    });
  });

  describe('as a rest parameter', () => {
    function describeNode(description: string, create: () => Parameter): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('parameter'));

        it('has a name', () => expect(node.name).toBe('foo'));

        it('has no default value', () =>
          expect(node.defaultValue).toBeUndefined());

        it('is a rest parameter', () => expect(node.rest).toBe(true));
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@function a($foo...) {}').nodes[0] as FunctionRule)
          .parameters.nodes[0],
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@function a($foo...)').nodes[0] as FunctionRule).parameters
          .nodes[0],
    );

    describeNode(
      'constructed manually',
      () => new Parameter({name: 'foo', rest: true}),
    );

    describeNode(
      'constructed from properties',
      () => new ParameterList({nodes: [{name: 'foo', rest: true}]}).nodes[0],
    );
  });

  it('assigned a new name', () => {
    node.name = 'baz';
    expect(node.name).toBe('baz');
  });

  describe('assigned a new default', () => {
    it('updates the default', () => {
      const old = node.defaultValue!;
      node.defaultValue = {text: 'baz'};
      expect(old.parent).toBeUndefined();
      expect(node).toHaveStringExpression('defaultValue', 'baz');
    });

    it('sets rest to false', () => {
      node.rest = true;
      node.defaultValue = {text: 'baz'};
      expect(node.rest).toBe(false);
    });

    it('leaves rest alone if defaultValue is undefined', () => {
      node.rest = true;
      node.defaultValue = undefined;
      expect(node.rest).toBe(true);
    });
  });

  describe('assigned rest = true', () => {
    it('updates the value of rest', () => {
      node.rest = true;
      expect(node.rest).toBe(true);
    });

    it('sets defaultValue to undefined', () => {
      node.rest = true;
      expect(node.defaultValue).toBe(undefined);
    });

    it('leaves defaultValue alone if rest is false', () => {
      node.rest = false;
      expect(node).toHaveStringExpression('defaultValue', 'bar');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with no default', () =>
          expect(new Parameter('foo').toString()).toBe('$foo'));

        it('with a default', () =>
          expect(
            new Parameter(['foo', {text: 'bar', quotes: true}]).toString(),
          ).toBe('$foo: "bar"'));

        it('with rest', () =>
          expect(new Parameter(['foo', {rest: true}]).toString()).toBe(
            '$foo...',
          ));

        it('with a non-identifier name', () =>
          expect(new Parameter('f o').toString()).toBe('$f\\20o'));
      });

      // raws.before is only used as part of a ParameterList
      it('ignores before', () =>
        expect(
          new Parameter({
            name: 'foo',
            raws: {before: '/**/'},
          }).toString(),
        ).toBe('$foo'));

      it('with matching name', () =>
        expect(
          new Parameter({
            name: 'foo',
            raws: {name: {raw: 'f\\6fo', value: 'foo'}},
          }).toString(),
        ).toBe('$f\\6fo'));

      it('with non-matching name', () =>
        expect(
          new Parameter({
            name: 'foo',
            raws: {name: {raw: 'f\\41o', value: 'fao'}},
          }).toString(),
        ).toBe('$foo'));

      it('with between', () =>
        expect(
          new Parameter({
            name: 'foo',
            defaultValue: {text: 'bar', quotes: true},
            raws: {between: ' : '},
          }).toString(),
        ).toBe('$foo : "bar"'));

      it('ignores between with no defaultValue', () =>
        expect(
          new Parameter({
            name: 'foo',
            raws: {between: ' : '},
          }).toString(),
        ).toBe('$foo'));

      it('with beforeRest', () =>
        expect(
          new Parameter({
            name: 'foo',
            rest: true,
            raws: {beforeRest: '/**/'},
          }).toString(),
        ).toBe('$foo/**/...'));

      it('ignores beforeRest with rest = false', () =>
        expect(
          new Parameter({
            name: 'foo',
            raws: {beforeRest: '/**/'},
          }).toString(),
        ).toBe('$foo'));

      // raws.before is only used as part of a Configuration
      describe('ignores after', () => {
        it('with no default', () =>
          expect(
            new Parameter({
              name: 'foo',
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('$foo'));

        it('with a default', () =>
          expect(
            new Parameter({
              name: 'foo',
              defaultValue: {text: 'bar', quotes: true},
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('$foo: "bar"'));

        it('with rest = true', () =>
          expect(
            new Parameter({
              name: 'foo',
              rest: true,
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('$foo...'));
      });
    });
  });

  describe('clone()', () => {
    let original: Parameter;
    beforeEach(() => {
      original = (
        scss.parse('@function x($foo: "bar") {}').nodes[0] as FunctionRule
      ).parameters.nodes[0];
      original.raws.between = ' : ';
    });

    describe('with no overrides', () => {
      let clone: Parameter;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('name', () => expect(clone.name).toBe('foo'));

        it('defaultValue', () =>
          expect(clone).toHaveStringExpression('defaultValue', 'bar'));

        it('rest', () => expect(clone.rest).toBe(false));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['defaultValue', 'raws'] as const) {
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

      describe('defaultValue', () => {
        it('defined', () =>
          expect(
            original.clone({defaultValue: {text: 'baz', quotes: true}}),
          ).toHaveStringExpression('defaultValue', 'baz'));

        it('undefined', () =>
          expect(
            original.clone({defaultValue: undefined}).defaultValue,
          ).toBeUndefined());
      });

      describe('rest', () => {
        it('defined', () =>
          expect(original.clone({rest: true}).rest).toBe(true));

        it('undefined', () =>
          expect(original.clone({rest: undefined}).rest).toBe(false));
      });
    });
  });

  describe('toJSON', () => {
    it('with a default', () =>
      expect(
        (scss.parse('@function x($baz: "qux") {}').nodes[0] as FunctionRule)
          .parameters.nodes[0],
      ).toMatchSnapshot());

    it('with no default', () =>
      expect(
        (scss.parse('@function x($baz) {}').nodes[0] as FunctionRule).parameters
          .nodes[0],
      ).toMatchSnapshot());

    it('with rest = true', () =>
      expect(
        (scss.parse('@function x($baz...) {}').nodes[0] as FunctionRule)
          .parameters.nodes[0],
      ).toMatchSnapshot());
  });
});
