// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  Argument,
  ArgumentList,
  IncludeRule,
  StringExpression,
  sass,
  scss,
} from '..';

describe('an argument', () => {
  let node: Argument;
  beforeEach(
    () =>
      void (node = new Argument({
        name: 'foo',
        value: {text: 'bar', quotes: true},
      })),
  );

  describe('with no name', () => {
    function describeNode(description: string, create: () => Argument): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () => expect(node.sassType).toBe('argument'));

        it('has no name', () => expect(node.name).toBeUndefined());

        it('has a value', () =>
          expect(node).toHaveStringExpression('value', 'bar'));

        it('is not a rest parameter', () => expect(node.rest).toBe(false));
      });
    }

    describeNode('parsed as SCSS', () => {
      const rule = scss.parse('@include a(bar)').nodes[0] as IncludeRule;
      return rule.arguments.nodes[0];
    });

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@include a(bar)').nodes[0] as IncludeRule).arguments
          .nodes[0],
    );

    describe('constructed manually', () => {
      describeNode(
        'with an expression',
        () => new Argument(new StringExpression({text: 'bar'})),
      );

      describe('with ArgumentProps', () => {
        describeNode(
          'with an expression',
          () => new Argument({value: new StringExpression({text: 'bar'})}),
        );

        describeNode(
          'with ExpressionProps',
          () => new Argument({value: {text: 'bar'}}),
        );
      });

      describeNode('with ExpressionProps', () => new Argument({text: 'bar'}));
    });

    describe('constructed from properties', () => {
      describeNode(
        'with an expression',
        () => new ArgumentList([new StringExpression({text: 'bar'})]).nodes[0],
      );

      describe('with ArgumentProps', () => {
        describeNode(
          'with an expression',
          () =>
            new ArgumentList([{value: new StringExpression({text: 'bar'})}])
              .nodes[0],
        );

        describeNode(
          'with ExpressionProps',
          () => new ArgumentList([{value: {text: 'bar'}}]).nodes[0],
        );
      });

      describeNode(
        'with ExpressionProps',
        () => new ArgumentList({nodes: [{text: 'bar'}]}).nodes[0],
      );
    });
  });

  describe('with a name', () => {
    function describeNode(description: string, create: () => Argument): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('argument'));

        it('has a name', () => expect(node.name).toBe('foo'));

        it('has value', () =>
          expect(node).toHaveStringExpression('value', 'bar'));
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@include a($foo: "bar")').nodes[0] as IncludeRule)
          .arguments.nodes[0],
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@include a($foo: "bar")').nodes[0] as IncludeRule)
          .arguments.nodes[0],
    );

    describe('constructed manually', () => {
      describe('with an array', () => {
        describeNode(
          'with an expression',
          () => new Argument(['foo', new StringExpression({text: 'bar'})]),
        );

        describeNode(
          'with ExpressionProps',
          () => new Argument(['foo', {text: 'bar'}]),
        );

        describe('with ArgumentProps', () => {
          describeNode(
            'with an expression',
            () =>
              new Argument([
                'foo',
                {
                  value: new StringExpression({text: 'bar'}),
                },
              ]),
          );

          describeNode(
            'with ExpressionProps',
            () => new Argument(['foo', {value: {text: 'bar'}}]),
          );
        });
      });

      describe('with an object', () => {
        describeNode(
          'with an expression',
          () =>
            new Argument({
              name: 'foo',
              value: new StringExpression({text: 'bar'}),
            }),
        );

        describeNode(
          'with ExpressionProps',
          () => new Argument({name: 'foo', value: {text: 'bar'}}),
        );
      });
    });

    describe('constructed from properties', () => {
      describe('an array', () => {
        describeNode(
          'with ExpressionProps',
          () =>
            new ArgumentList({
              nodes: [['foo', {text: 'bar'}]],
            }).nodes[0],
        );

        describeNode(
          'with an Expression',
          () =>
            new ArgumentList({
              nodes: [['foo', new StringExpression({text: 'bar'})]],
            }).nodes[0],
        );

        describeNode(
          'with ArgumentObjectProps',
          () =>
            new ArgumentList({
              nodes: [['foo', {value: {text: 'bar'}}]],
            }).nodes[0],
        );
      });

      describe('an object', () => {
        describeNode(
          'with ExpressionProps',
          () =>
            new ArgumentList({
              nodes: [{name: 'foo', value: {text: 'bar'}}],
            }).nodes[0],
        );

        describeNode(
          'with an Expression',
          () =>
            new ArgumentList({
              nodes: [
                {
                  name: 'foo',
                  value: new StringExpression({text: 'bar'}),
                },
              ],
            }).nodes[0],
        );
      });
    });
  });

  describe('as a rest argument', () => {
    function describeNode(description: string, create: () => Argument): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('argument'));

        it('has no name', () => expect(node.name).toBeUndefined());

        it('has a value', () =>
          expect(node).toHaveStringExpression('value', 'bar'));

        it('is a rest argument', () => expect(node.rest).toBe(true));
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@include a(bar...)').nodes[0] as IncludeRule).arguments
          .nodes[0],
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@include a(bar...)').nodes[0] as IncludeRule).arguments
          .nodes[0],
    );

    describeNode(
      'constructed manually',
      () => new Argument({value: {text: 'bar'}, rest: true}),
    );

    describeNode(
      'constructed from properties',
      () =>
        new ArgumentList({nodes: [{value: {text: 'bar'}, rest: true}]})
          .nodes[0],
    );
  });

  describe('assigned a new name', () => {
    it('updates the name', () => {
      node.name = 'baz';
      expect(node.name).toBe('baz');
    });

    it('sets rest to false', () => {
      node.rest = true;
      node.name = 'baz';
      expect(node.rest).toBe(false);
    });

    it('leaves rest alone if name is undefined', () => {
      node.rest = true;
      node.name = undefined;
      expect(node.rest).toBe(true);
    });
  });

  describe('assigned a new rest', () => {
    it('updates the value of rest', () => {
      node.rest = true;
      expect(node.rest).toBe(true);
    });

    it('sets name to undefined', () => {
      node.rest = true;
      expect(node.name).toBe(undefined);
    });

    it('leaves defaultValue alone if rest is false', () => {
      node.rest = false;
      expect(node.name).toBe('foo');
    });
  });

  it('assigned a new value', () => {
    const old = node.value;
    node.value = {text: 'baz'};
    expect(old.parent).toBeUndefined();
    expect(node).toHaveStringExpression('value', 'baz');
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with no name', () =>
          expect(new Argument({text: 'bar'}).toString()).toBe('bar'));

        it('with a name', () =>
          expect(new Argument(['foo', {text: 'bar'}]).toString()).toBe(
            '$foo: bar',
          ));

        it('with rest = true', () =>
          expect(
            new Argument({value: {text: 'bar'}, rest: true}).toString(),
          ).toBe('bar...'));

        it('with a non-identifier name', () =>
          expect(new Argument(['f o', {text: 'bar'}]).toString()).toBe(
            '$f\\20o: bar',
          ));
      });

      // raws.before is only used as part of a ArgumentList
      it('ignores before', () =>
        expect(
          new Argument({
            value: {text: 'bar'},
            raws: {before: '/**/'},
          }).toString(),
        ).toBe('bar'));

      it('with matching name', () =>
        expect(
          new Argument({
            name: 'foo',
            value: {text: 'bar'},
            raws: {name: {raw: 'f\\6fo', value: 'foo'}},
          }).toString(),
        ).toBe('$f\\6fo: bar'));

      it('with non-matching name', () =>
        expect(
          new Argument({
            name: 'foo',
            value: {text: 'bar'},
            raws: {name: {raw: 'f\\41o', value: 'fao'}},
          }).toString(),
        ).toBe('$foo: bar'));

      it('with between', () =>
        expect(
          new Argument({
            name: 'foo',
            value: {text: 'bar'},
            raws: {between: ' : '},
          }).toString(),
        ).toBe('$foo : bar'));

      it('ignores between with no name', () =>
        expect(
          new Argument({
            value: {text: 'bar'},
            raws: {between: ' : '},
          }).toString(),
        ).toBe('bar'));

      it('with beforeRest', () =>
        expect(
          new Argument({
            value: {text: 'bar'},
            rest: true,
            raws: {beforeRest: '/**/'},
          }).toString(),
        ).toBe('bar/**/...'));

      it('ignores beforeRest with rest = false', () =>
        expect(
          new Argument({
            value: {text: 'bar'},
            raws: {beforeRest: '/**/'},
          }).toString(),
        ).toBe('bar'));

      // raws.before is only used as part of a Configuration
      describe('ignores after', () => {
        it('with rest = false', () =>
          expect(
            new Argument({
              value: {text: 'bar'},
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('bar'));

        it('with rest = true', () =>
          expect(
            new Argument({
              value: {text: 'bar'},
              rest: true,
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('bar...'));
      });
    });
  });

  describe('clone()', () => {
    let original: Argument;
    beforeEach(() => {
      original = (scss.parse('@include x($foo: bar)').nodes[0] as IncludeRule)
        .arguments.nodes[0];
      original.raws.between = ' : ';
    });

    describe('with no overrides', () => {
      let clone: Argument;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('name', () => expect(clone.name).toBe('foo'));

        it('value', () => expect(clone).toHaveStringExpression('value', 'bar'));

        it('rest', () => expect(clone.rest).toBe(false));
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
          expect(original.clone({name: undefined}).name).toBeUndefined());
      });

      describe('rest', () => {
        it('defined', () =>
          expect(original.clone({rest: true}).rest).toBe(true));

        it('undefined', () =>
          expect(original.clone({rest: undefined}).rest).toBe(false));
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

  describe('toJSON', () => {
    it('with a name', () =>
      expect(
        (scss.parse('@include x($baz: qux)').nodes[0] as IncludeRule).arguments
          .nodes[0],
      ).toMatchSnapshot());

    it('with no name', () =>
      expect(
        (scss.parse('@include x(qux)').nodes[0] as IncludeRule).arguments
          .nodes[0],
      ).toMatchSnapshot());

    it('with rest', () =>
      expect(
        (scss.parse('@include x(qux...)').nodes[0] as IncludeRule).arguments
          .nodes[0],
      ).toMatchSnapshot());
  });
});
