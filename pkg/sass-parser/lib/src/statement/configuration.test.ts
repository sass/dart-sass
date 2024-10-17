// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  Configuration,
  ConfiguredVariable,
  StringExpression,
  UseRule,
  sass,
  scss,
} from '../..';

describe('a configuration map', () => {
  let node: Configuration;
  beforeEach(() => (node = new Configuration()));

  describe('empty', () => {
    function describeNode(
      description: string,
      create: () => Configuration
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('configuration'));

        it('has no contents', () => {
          expect(node.size).toBe(0);
          expect([...node.variables()]).toEqual([]);
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () => (scss.parse('@use "foo"').nodes[0] as UseRule).configuration
    );

    describeNode(
      'parsed as Sass',
      () => (sass.parse('@use "foo"').nodes[0] as UseRule).configuration
    );

    describe('constructed manually', () => {
      describeNode('no args', () => new Configuration());

      describeNode('variables array', () => new Configuration({variables: []}));

      describeNode(
        'variables record',
        () => new Configuration({variables: {}})
      );
    });

    describeNode(
      'constructed from props',
      () =>
        new UseRule({useUrl: 'foo', configuration: {variables: []}})
          .configuration
    );
  });

  describe('with a variable', () => {
    function describeNode(
      description: string,
      create: () => Configuration
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('configuration'));

        it('contains the variable', () => {
          expect(node.size).toBe(1);
          const variable = [...node.variables()][0];
          expect(variable.variable).toEqual('bar');
          expect(variable).toHaveStringExpression('expression', 'baz');
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@use "foo" with ($bar: "baz")').nodes[0] as UseRule)
          .configuration
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@use "foo" with ($bar: "baz")').nodes[0] as UseRule)
          .configuration
    );

    describe('constructed manually', () => {
      describeNode(
        'variables array',
        () =>
          new Configuration({
            variables: [{variable: 'bar', expression: {text: 'baz', quotes: true}}],
          })
      );

      describeNode(
        'variables record',
        () => new Configuration({variables: {bar: {text: 'baz', quotes: true}}})
      );
    });

    describeNode(
      'constructed from props',
      () =>
        new UseRule({
          useUrl: 'foo',
          configuration: {variables: {bar: {text: 'baz', quotes: true}}},
        }).configuration
    );
  });

  describe('add()', () => {
    test('with a ConfiguredVariable', () => {
      const variable = new ConfiguredVariable({
        variable: 'foo',
        expression: {text: 'bar', quotes: true},
      });
      expect(node.add(variable)).toBe(node);
      expect(node.size).toBe(1);
      expect([...node.variables()][0]).toBe(variable);
      expect(variable.parent).toBe(node);
    });

    test('with a ConfiguredVariableProps', () => {
      node.add({variable: 'foo', expression: {text: 'bar', quotes: true}});
      expect(node.size).toBe(1);
      const variable = node.get('foo');
      expect(variable?.variable).toBe('foo');
      expect(variable).toHaveStringExpression('expression', 'bar');
      expect(variable?.parent).toBe(node);
    });

    test('overwrites on old variable', () => {
      node.add({variable: 'foo', expression: {text: 'old', quotes: true}});
      const old = node.get('foo');
      expect(old?.parent).toBe(node);

      node.add({variable: 'foo', expression: {text: 'new', quotes: true}});
      expect(node.size).toBe(1);
      expect(old?.parent).toBeUndefined();
      expect(node.get('foo')).toHaveStringExpression('expression', 'new');
    });
  });

  test('clear() removes all variables', () => {
    node.add({variable: 'foo', expression: {text: 'bar', quotes: true}});
    node.add({variable: 'baz', expression: {text: 'bang', quotes: true}});
    const foo = node.get('foo');
    const bar = node.get('bar');
    node.clear();

    expect(node.size).toBe(0);
    expect([...node.variables()]).toEqual([]);
    expect(foo?.parent).toBeUndefined();
    expect(bar?.parent).toBeUndefined();
  });

  describe('delete()', () => {
    beforeEach(() => {
      node.add({variable: 'foo', expression: {text: 'bar', quotes: true}});
      node.add({variable: 'baz', expression: {text: 'bang', quotes: true}});
    });

    test('removes a matching variable', () => {
      const foo = node.get('foo');
      expect(node.delete('foo')).toBe(true);
      expect(foo?.parent).toBeUndefined();
      expect(node.size).toBe(1);
      expect(node.get('foo')).toBeUndefined();
    });

    test("doesn't remove a non-matching variable", () => {
      expect(node.delete('bang')).toBe(false);
      expect(node.size).toBe(2);
    });
  });

  describe('get()', () => {
    beforeEach(() => {
      node.add({variable: 'foo', expression: {text: 'bar', quotes: true}});
    });

    test('returns a variable in the configuration', () => {
      const variable = node.get('foo');
      expect(variable?.variable).toBe('foo');
      expect(variable).toHaveStringExpression('expression', 'bar');
    });

    test('returns undefined for a variable not in the configuration', () => {
      expect(node.get('bar')).toBeUndefined();
    });
  });

  describe('has()', () => {
    beforeEach(() => {
      node.add({variable: 'foo', expression: {text: 'bar', quotes: true}});
    });

    test('returns true for a variable in the configuration', () =>
      expect(node.has('foo')).toBe(true));

    test('returns false for a variable not in the configuration', () =>
      expect(node.has('bar')).toBe(false));
  });

  describe('set()', () => {
    beforeEach(() => {
      node.add({variable: 'foo', expression: {text: 'bar', quotes: true}});
    });

    describe('adds a new variable', () => {
      function describeVariable(
        description: string,
        create: () => Configuration
      ): void {
        it(description, () => {
          expect(create()).toBe(node);
          expect(node.size).toBe(2);
          const variable = node.get('baz');
          expect(variable?.parent).toBe(node);
          expect(variable?.variable).toBe('baz');
          expect(variable).toHaveStringExpression('expression', 'bang');
        });
      }

      describeVariable('with Expression', () =>
        node.set('baz', new StringExpression({text: 'bang', quotes: true}))
      );

      describeVariable('with ExpressionProps', () =>
        node.set('baz', {text: 'bang', quotes: true})
      );

      describeVariable('with ConfiguredVariableObjectProps', () =>
        node.set('baz', {expression: {text: 'bang', quotes: true}})
      );
    });

    test('overwrites an existing variable', () => {
      const foo = node.get('foo');
      node.set('foo', {text: 'bang', quotes: true});
      expect(foo?.parent).toBeUndefined();
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('empty', () => expect(new Configuration().toString()).toBe('()'));

        it('with variables', () =>
          expect(
            new Configuration({
              variables: {
                foo: {text: 'bar', quotes: true},
                baz: {text: 'bang', quotes: true},
              },
            }).toString()
          ).toBe('($foo: "bar", $baz: "bang")'));
      });

      it('with comma: true', () =>
        expect(
          new Configuration({
            raws: {comma: true},
            variables: {
              foo: {text: 'bar', quotes: true},
              baz: {text: 'bang', quotes: true},
            },
          }).toString()
        ).toBe('($foo: "bar", $baz: "bang",)'));

      it('with comma: true and afterValue', () =>
        expect(
          new Configuration({
            raws: {comma: true},
            variables: {
              foo: {text: 'bar', quotes: true},
              baz: {
                expression: {text: 'bang', quotes: true},
                raws: {afterValue: '/**/'},
              },
            },
          }).toString()
        ).toBe('($foo: "bar", $baz: "bang"/**/,)'));

      it('with after', () =>
        expect(
          new Configuration({
            raws: {after: '/**/'},
            variables: {
              foo: {text: 'bar', quotes: true},
              baz: {text: 'bang', quotes: true},
            },
          }).toString()
        ).toBe('($foo: "bar", $baz: "bang"/**/)'));

      it('with after and afterValue', () =>
        expect(
          new Configuration({
            raws: {after: '/**/'},
            variables: {
              foo: {text: 'bar', quotes: true},
              baz: {
                expression: {text: 'bang', quotes: true},
                raws: {afterValue: '  '},
              },
            },
          }).toString()
        ).toBe('($foo: "bar", $baz: "bang"  /**/)'));

      it('with afterValue and a guard', () =>
        expect(
          new Configuration({
            variables: {
              foo: {text: 'bar', quotes: true},
              baz: {
                expression: {text: 'bang', quotes: true},
                raws: {afterValue: '/**/'},
                guarded: true,
              },
            },
          }).toString()
        ).toBe('($foo: "bar", $baz: "bang" !default/**/)'));
    });
  });

  describe('clone', () => {
    let original: Configuration;
    beforeEach(() => {
      original = (
        scss.parse('@use "foo" with ($foo: "bar", $baz: "bang")')
          .nodes[0] as UseRule
      ).configuration;
      // TODO: remove this once raws are properly parsed
      original.raws.after = '  ';
    });

    describe('with no overrides', () => {
      let clone: Configuration;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('variables', () => {
          expect(clone.size).toBe(2);
          const variables = [...clone.variables()];
          expect(variables[0]?.variable).toBe('foo');
          expect(variables[0]?.parent).toBe(clone);
          expect(variables[0]).toHaveStringExpression('expression', 'bar');
          expect(variables[1]?.variable).toBe('baz');
          expect(variables[1]?.parent).toBe(clone);
          expect(variables[1]).toHaveStringExpression('expression', 'bang');
        });

        it('raws', () => expect(clone.raws.after).toBe('  '));
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
          expect(original.clone({raws: {comma: true}}).raws).toEqual({
            comma: true,
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            after: '  ',
          }));
      });

      describe('variables', () => {
        it('defined', () => {
          const clone = original.clone({
            variables: {zip: {text: 'zap', quotes: true}},
          });
          expect(clone.size).toBe(1);
          const variables = [...clone.variables()];
          expect(variables[0]?.variable).toBe('zip');
          expect(variables[0]?.parent).toBe(clone);
          expect(variables[0]).toHaveStringExpression('expression', 'zap');
        });

        it('undefined', () => {
          const clone = original.clone({variables: undefined});
          expect(clone.size).toBe(2);
          const variables = [...clone.variables()];
          expect(variables[0]?.variable).toBe('foo');
          expect(variables[0]?.parent).toBe(clone);
          expect(variables[0]).toHaveStringExpression('expression', 'bar');
          expect(variables[1]?.variable).toBe('baz');
          expect(variables[1]?.parent).toBe(clone);
          expect(variables[1]).toHaveStringExpression('expression', 'bang');
        });
      });
    });
  });

  // Can't JSON-serialize this until we implement Configuration.source.span
  it.skip('toJSON', () =>
    expect(
      (scss.parse('@use "foo" with ($baz: "qux")').nodes[0] as UseRule)
        .configuration
    ).toMatchSnapshot());
});
