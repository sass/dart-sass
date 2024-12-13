// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  Declaration,
  Interpolation,
  Rule,
  StringExpression,
  sass,
  scss,
} from '../..';
import * as utils from '../../../test/utils';

describe('a property declaration', () => {
  let node: Declaration;
  beforeEach(
    () =>
      void (node = new Declaration({
        prop: 'foo',
        expression: {text: 'bar'},
      })),
  );

  describe('with no children', () => {
    function describeNode(
      description: string,
      create: () => Declaration,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('decl'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('decl'));

        it('has propInterpolation', () =>
          expect(node).toHaveInterpolation('propInterpolation', 'foo'));

        it('has a prop', () => expect(node.prop).toBe('foo'));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('expression', 'bar'));

        it('has a value', () => expect(node.value).toBe('bar'));

        it('has no nodes', () => expect(node.nodes).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('a {foo: bar}').nodes[0] as Rule).nodes[0] as Declaration,
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('a\n  foo: bar').nodes[0] as Rule).nodes[0] as Declaration,
    );

    describe('constructed manually', () => {
      describeNode(
        'with prop and value',
        () =>
          new Declaration({
            prop: 'foo',
            value: 'bar',
          }),
      );

      describe('with propInterpolation', () => {
        describeNode(
          "that's a string",
          () =>
            new Declaration({
              propInterpolation: 'foo',
              value: 'bar',
            }),
        );

        describeNode(
          "that's child props",
          () =>
            new Declaration({
              propInterpolation: {nodes: ['foo']},
              value: 'bar',
            }),
        );

        describeNode(
          "that's an explicit Interpolation",
          () =>
            new Declaration({
              propInterpolation: new Interpolation('foo'),
              value: 'bar',
            }),
        );
      });

      describe('with an expression', () => {
        describeNode(
          "that's child props",
          () =>
            new Declaration({
              prop: 'foo',
              expression: {text: 'bar'},
            }),
        );

        describeNode(
          "that's an Expression",
          () =>
            new Declaration({
              prop: 'foo',
              expression: new StringExpression({text: 'bar'}),
            }),
        );
      });
    });

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({prop: 'foo', value: 'bar'}),
    );
  });

  describe('with a value and children', () => {
    function describeNode(
      description: string,
      create: () => Declaration,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('decl'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('decl'));

        it('has propInterpolation', () =>
          expect(node).toHaveInterpolation('propInterpolation', 'foo'));

        it('has a prop', () => expect(node.prop).toBe('foo'));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('expression', 'bar'));

        it('has a value', () => expect(node.value).toBe('bar'));

        it('has nodes', () => expect(node.nodes).toHaveLength(1));
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('a {foo: bar {baz: bang}}').nodes[0] as Rule)
          .nodes[0] as Declaration,
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('a\n  foo: bar\n    baz: bang').nodes[0] as Rule)
          .nodes[0] as Declaration,
    );

    describeNode(
      'constructed manually',
      () =>
        new Declaration({
          prop: 'foo',
          value: 'bar',
          nodes: [{name: 'baz'}],
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({prop: 'foo', value: 'bar', nodes: [{name: 'baz'}]}),
    );
  });

  it('assigned a new prop', () => {
    node.prop = 'baz';
    expect(node.prop).toBe('baz');
    expect(node).toHaveInterpolation('propInterpolation', 'baz');
  });

  it('assigned a new propInterpolation', () => {
    node.propInterpolation = 'baz';
    expect(node.prop).toBe('baz');
    expect(node).toHaveInterpolation('propInterpolation', 'baz');
  });

  it('assigned a new expression', () => {
    const old = node.expression!;
    node.expression = {text: 'baz'};
    expect(old.parent).toBeUndefined();
    expect(node).toHaveStringExpression('expression', 'baz');
    expect(node.value).toBe('baz');
  });

  it('assigned a value', () => {
    node.value = 'Helvetica, sans-serif';
    expect(node).toHaveStringExpression('expression', 'Helvetica, sans-serif');
    expect(node.value).toBe('Helvetica, sans-serif');
  });

  it('is not a variable without --', () => expect(node.variable).toBe(false));

  it('is a variable with --', () => {
    node.prop = '--foo';
    expect(node.variable).toBe(true);
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with no children', () =>
          expect(new Declaration({prop: 'foo', value: 'bar'}).toString()).toBe(
            'foo: bar',
          ));

        it('with a value and children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              nodes: [{prop: 'baz', value: 'bang'}],
            }).toString(),
          ).toBe('foo: bar {\n    baz: bang\n}'));

        it('with only children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              nodes: [{prop: 'baz', value: 'bang'}],
            }).toString(),
          ).toBe('foo: {\n    baz: bang\n}'));
      });

      describe('with before', () => {
        it('on its own', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              raws: {before: '/**/'},
            }).toString(),
          ).toBe('foo: bar'));

        it('as a child', () =>
          expect(
            new Rule({
              selector: 'foo',
              nodes: [{prop: 'bar', value: 'baz', raws: {before: '/**/'}}],
            }).toString(),
          ).toBe('foo {/**/bar: baz\n}'));
      });

      describe('with between', () => {
        it('with no children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              raws: {between: ':/**/'},
            }).toString(),
          ).toBe('foo:/**/bar'));

        it('with a value and children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              nodes: [{prop: 'baz', value: 'bang'}],
              raws: {between: ':/**/'},
            }).toString(),
          ).toBe('foo:/**/bar {\n    baz: bang\n}'));

        it('with no value and children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              nodes: [{prop: 'baz', value: 'bang'}],
              raws: {between: ':/**/'},
            }).toString(),
          ).toBe('foo:/**/ {\n    baz: bang\n}'));
      });

      it('ignores important', () =>
        expect(
          new Declaration({
            prop: 'foo',
            value: 'bar !important',
            raws: {important: '!IMPORTANT'},
          }).toString(),
        ).toBe('foo: bar !important'));

      it('ignores value', () =>
        expect(
          new Declaration({
            prop: 'foo',
            value: 'bar',
            raws: {value: {value: 'bar', raw: 'BAR'}},
          }).toString(),
        ).toBe('foo: bar'));

      describe('with afterValue', () => {
        it('with no children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              raws: {afterValue: '/**/'},
            }).toString(),
          ).toBe('foo: bar/**/'));

        it('with a value and children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              nodes: [{prop: 'baz', value: 'bang'}],
              raws: {afterValue: '/**/'},
            }).toString(),
          ).toBe('foo: bar/**/{\n    baz: bang\n}'));

        it('with no value and children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              nodes: [{prop: 'baz', value: 'bang'}],
              raws: {afterValue: '/**/'},
            }).toString(),
          ).toBe('foo:/**/{\n    baz: bang\n}'));
      });

      describe('with after', () => {
        it('without children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('foo: bar'));

        it('with children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              nodes: [{prop: 'baz', value: 'bang'}],
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('foo: bar {\n    baz: bang/**/}'));
      });

      describe('with ownSemicolon', () => {
        it('without children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              raws: {ownSemicolon: ';'},
            }).toString(),
          ).toBe('foo: bar'));

        it('with children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              nodes: [{prop: 'baz', value: 'bang'}],
              raws: {ownSemicolon: ';'},
            }).toString(),
          ).toBe('foo: bar {\n    baz: bang\n};'));
      });

      describe('with semicolon', () => {
        it('without children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              raws: {semicolon: true},
            }).toString(),
          ).toBe('foo: bar'));

        it('with children', () =>
          expect(
            new Declaration({
              prop: 'foo',
              value: 'bar',
              nodes: [{prop: 'baz', value: 'bang'}],
              raws: {semicolon: true},
            }).toString(),
          ).toBe('foo: bar {\n    baz: bang;\n}'));
      });
    });
  });

  describe('clone', () => {
    let original: Declaration;
    beforeEach(() => {
      original = (scss.parse('a {foo: bar {baz: bang}}').nodes[0] as Rule)
        .nodes[0] as Declaration;
      // TODO: remove this once raws are properly parsed
      original.raws.between = ' :';
    });

    describe('with no overrides', () => {
      let clone: Declaration;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('prop', () => expect(clone.prop).toBe('foo'));

        it('propInterpolation', () =>
          expect(clone).toHaveInterpolation('propInterpolation', 'foo'));

        it('expression', () =>
          expect(clone).toHaveStringExpression('expression', 'bar'));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of [
          'propInterpolation',
          'expression',
          'raws',
        ] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {afterValue: '  '}}).raws).toEqual({
            afterValue: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            between: ' :',
          }));
      });

      describe('propInterpolation', () => {
        describe('defined', () => {
          let clone: Declaration;
          beforeEach(() => {
            clone = original.clone({propInterpolation: 'zap'});
          });

          it('changes variableName', () =>
            expect(clone).toHaveInterpolation('propInterpolation', 'zap'));

          it('changes prop', () => expect(clone.prop).toBe('zap'));
        });

        describe('undefined', () => {
          let clone: Declaration;
          beforeEach(() => {
            clone = original.clone({propInterpolation: undefined});
          });

          it('preserves variableName', () =>
            expect(clone).toHaveInterpolation('propInterpolation', 'foo'));

          it('preserves prop', () => expect(clone.prop).toBe('foo'));
        });
      });

      describe('expression', () => {
        it('defined changes expression', () =>
          expect(
            original.clone({expression: {text: 'zap'}}),
          ).toHaveStringExpression('expression', 'zap'));

        it('undefined removes expression', () =>
          expect(
            original.clone({expression: undefined}).expression,
          ).toBeUndefined());
      });
    });
  });

  describe('toJSON', () => {
    it('with expression and nodes', () =>
      expect(
        (scss.parse('a {foo: bar {baz: bang}}').nodes[0] as Rule).nodes[0],
      ).toMatchSnapshot());

    it('with expression and no nodes', () =>
      expect(
        (scss.parse('a {foo: bar}').nodes[0] as Rule).nodes[0],
      ).toMatchSnapshot());

    it('with no expression and nodes', () =>
      expect(
        (scss.parse('a {foo: {baz: bang}}').nodes[0] as Rule).nodes[0],
      ).toMatchSnapshot());
  });
});
