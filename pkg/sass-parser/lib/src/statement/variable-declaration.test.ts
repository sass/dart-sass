// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {StringExpression, VariableDeclaration, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a variable declaration', () => {
  let node: VariableDeclaration;
  beforeEach(
    () =>
      void (node = new VariableDeclaration({
        variableName: 'foo',
        expression: {text: 'bar'},
      })),
  );

  describe('with no namespace and no flags', () => {
    function describeNode(
      description: string,
      create: () => VariableDeclaration,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('decl'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('variable-declaration'));

        it('has no namespace', () => expect(node.namespace).toBeUndefined());

        it('has a name', () => expect(node.variableName).toBe('foo'));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('expression', 'bar'));

        it('has a value', () => expect(node.value).toBe('bar'));

        it('is not guarded', () => expect(node.guarded).toBe(false));

        it('is not global', () => expect(node.global).toBe(false));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('$foo: bar').nodes[0] as VariableDeclaration,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('$foo: bar').nodes[0] as VariableDeclaration,
    );

    describe('constructed manually', () => {
      describeNode(
        'with an Expression',
        () =>
          new VariableDeclaration({
            variableName: 'foo',
            expression: new StringExpression({text: 'bar'}),
          }),
      );

      describeNode(
        'with child props',
        () =>
          new VariableDeclaration({
            variableName: 'foo',
            expression: {text: 'bar'},
          }),
      );

      describeNode(
        'with a value',
        () =>
          new VariableDeclaration({
            variableName: 'foo',
            value: 'bar',
          }),
      );
    });

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({variableName: 'foo', expression: {text: 'bar'}}),
    );
  });

  describe('with a namespace', () => {
    function describeNode(
      description: string,
      create: () => VariableDeclaration,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('decl'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('variable-declaration'));

        it('has a namespace', () => expect(node.namespace).toBe('baz'));

        it('has a name', () => expect(node.variableName).toBe('foo'));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('expression', 'bar'));

        it('has a value', () => expect(node.value).toBe('"bar"'));

        it('is not guarded', () => expect(node.guarded).toBe(false));

        it('is not global', () => expect(node.global).toBe(false));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('baz.$foo: "bar"').nodes[0] as VariableDeclaration,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('baz.$foo: "bar"').nodes[0] as VariableDeclaration,
    );

    describeNode(
      'constructed manually',
      () =>
        new VariableDeclaration({
          namespace: 'baz',
          variableName: 'foo',
          expression: new StringExpression({text: 'bar', quotes: true}),
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        namespace: 'baz',
        variableName: 'foo',
        expression: {text: 'bar', quotes: true},
      }),
    );
  });

  describe('guarded', () => {
    function describeNode(
      description: string,
      create: () => VariableDeclaration,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('decl'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('variable-declaration'));

        it('has no namespace', () => expect(node.namespace).toBeUndefined());

        it('has a name', () => expect(node.variableName).toBe('foo'));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('expression', 'bar'));

        it('has a value', () => expect(node.value).toBe('"bar"'));

        it('is guarded', () => expect(node.guarded).toBe(true));

        it('is not global', () => expect(node.global).toBe(false));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('$foo: "bar" !default').nodes[0] as VariableDeclaration,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('$foo: "bar" !default').nodes[0] as VariableDeclaration,
    );

    describeNode(
      'constructed manually',
      () =>
        new VariableDeclaration({
          variableName: 'foo',
          expression: new StringExpression({text: 'bar', quotes: true}),
          guarded: true,
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        variableName: 'foo',
        expression: {text: 'bar', quotes: true},
        guarded: true,
      }),
    );
  });

  describe('global', () => {
    function describeNode(
      description: string,
      create: () => VariableDeclaration,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('decl'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('variable-declaration'));

        it('has no namespace', () => expect(node.namespace).toBeUndefined());

        it('has a name', () => expect(node.variableName).toBe('foo'));

        it('has an expression', () =>
          expect(node).toHaveStringExpression('expression', 'bar'));

        it('has a value', () => expect(node.value).toBe('"bar"'));

        it('is not guarded', () => expect(node.guarded).toBe(false));

        it('is global', () => expect(node.global).toBe(true));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('$foo: "bar" !global').nodes[0] as VariableDeclaration,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('$foo: "bar" !global').nodes[0] as VariableDeclaration,
    );

    describeNode(
      'constructed manually',
      () =>
        new VariableDeclaration({
          variableName: 'foo',
          expression: new StringExpression({text: 'bar', quotes: true}),
          global: true,
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        variableName: 'foo',
        expression: {text: 'bar', quotes: true},
        global: true,
      }),
    );
  });

  it('throws an error when assigned a new prop', () =>
    expect(() => (node.prop = 'bar')).toThrow());

  it('assigned a new namespace', () => {
    node.namespace = 'baz';
    expect(node.namespace).toBe('baz');
    expect(node.prop).toBe('baz.$foo');
  });

  it('assigned a new variableName', () => {
    node.variableName = 'baz';
    expect(node.variableName).toBe('baz');
    expect(node.prop).toBe('$baz');
  });

  it('assigned a new expression', () => {
    const old = node.expression;
    node.expression = {text: 'baz'};
    expect(old.parent).toBeUndefined();
    expect(node).toHaveStringExpression('expression', 'baz');
  });

  it('assigned a value', () => {
    node.value = 'Helvetica, sans-serif';
    expect(node).toHaveStringExpression('expression', 'Helvetica, sans-serif');
  });

  it('is a variable', () => expect(node.variable).toBe(true));

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with no flags', () =>
          expect(
            new VariableDeclaration({
              variableName: 'foo',
              expression: {text: 'bar'},
            }).toString(),
          ).toBe('$foo: bar'));

        describe('with a namespace', () => {
          it("that's an identifier", () =>
            expect(
              new VariableDeclaration({
                namespace: 'baz',
                variableName: 'foo',
                expression: {text: 'bar'},
              }).toString(),
            ).toBe('baz.$foo: bar'));

          it("that's not an identifier", () =>
            expect(
              new VariableDeclaration({
                namespace: 'b z',
                variableName: 'foo',
                expression: {text: 'bar'},
              }).toString(),
            ).toBe('b\\20z.$foo: bar'));
        });

        it("with a name that's not an identifier", () =>
          expect(
            new VariableDeclaration({
              variableName: 'f o',
              expression: {text: 'bar'},
            }).toString(),
          ).toBe('$f\\20o: bar'));

        it('global', () =>
          expect(
            new VariableDeclaration({
              variableName: 'foo',
              expression: {text: 'bar'},
              global: true,
            }).toString(),
          ).toBe('$foo: bar !global'));

        it('guarded', () =>
          expect(
            new VariableDeclaration({
              variableName: 'foo',
              expression: {text: 'bar'},
              guarded: true,
            }).toString(),
          ).toBe('$foo: bar !default'));

        it('with both flags', () =>
          expect(
            new VariableDeclaration({
              variableName: 'foo',
              expression: {text: 'bar'},
              global: true,
              guarded: true,
            }).toString(),
          ).toBe('$foo: bar !default !global'));
      });

      describe('with a namespace raw', () => {
        it('that matches', () =>
          expect(
            new VariableDeclaration({
              namespace: 'baz',
              variableName: 'foo',
              expression: {text: 'bar'},
              raws: {namespace: {raw: 'b\\41z', value: 'baz'}},
            }).toString(),
          ).toBe('b\\41z.$foo: bar'));

        it("that doesn't match", () =>
          expect(
            new VariableDeclaration({
              namespace: 'baz',
              variableName: 'foo',
              expression: {text: 'bar'},
              raws: {namespace: {raw: 'z\\41p', value: 'zap'}},
            }).toString(),
          ).toBe('baz.$foo: bar'));
      });

      describe('with a variableName raw', () => {
        it('that matches', () =>
          expect(
            new VariableDeclaration({
              variableName: 'foo',
              expression: {text: 'bar'},
              raws: {variableName: {raw: 'f\\f3o', value: 'foo'}},
            }).toString(),
          ).toBe('$f\\f3o: bar'));

        it("that doesn't match", () =>
          expect(
            new VariableDeclaration({
              variableName: 'foo',
              expression: {text: 'bar'},
              raws: {namespace: {raw: 'z\\41p', value: 'zap'}},
            }).toString(),
          ).toBe('$foo: bar'));
      });

      it('with between', () =>
        expect(
          new VariableDeclaration({
            variableName: 'foo',
            expression: {text: 'bar'},
            raws: {between: '/**/:'},
          }).toString(),
        ).toBe('$foo/**/:bar'));

      describe('with a flags raw', () => {
        it('that matches both', () =>
          expect(
            new VariableDeclaration({
              variableName: 'foo',
              expression: {text: 'bar'},
              guarded: true,
              raws: {
                flags: {
                  raw: '/**/!default',
                  value: {guarded: true, global: false},
                },
              },
            }).toString(),
          ).toBe('$foo: bar/**/!default'));

        it('that matches only one', () =>
          expect(
            new VariableDeclaration({
              variableName: 'foo',
              expression: {text: 'bar'},
              guarded: true,
              raws: {
                flags: {
                  raw: '/**/!default !global',
                  value: {guarded: true, global: true},
                },
              },
            }).toString(),
          ).toBe('$foo: bar !default'));

        it('that matches neither', () =>
          expect(
            new VariableDeclaration({
              variableName: 'foo',
              expression: {text: 'bar'},
              guarded: true,
              raws: {
                flags: {
                  raw: '/**/!global',
                  value: {guarded: false, global: true},
                },
              },
            }).toString(),
          ).toBe('$foo: bar !default'));
      });

      describe('with an afterValue raw', () => {
        it('without flags', () =>
          expect(
            new VariableDeclaration({
              variableName: 'foo',
              expression: {text: 'bar'},
              raws: {afterValue: '/**/'},
            }).toString(),
          ).toBe('$foo: bar/**/'));

        it('with flags', () =>
          expect(
            new VariableDeclaration({
              variableName: 'foo',
              expression: {text: 'bar'},
              global: true,
              raws: {afterValue: '/**/'},
            }).toString(),
          ).toBe('$foo: bar !global/**/'));
      });
    });
  });

  describe('clone', () => {
    let original: VariableDeclaration;
    beforeEach(() => {
      original = scss.parse('baz.$foo: bar !default')
        .nodes[0] as VariableDeclaration;
      // TODO: remove this once raws are properly parsed
      original.raws.between = ' :';
    });

    describe('with no overrides', () => {
      let clone: VariableDeclaration;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('prop', () => expect(clone.prop).toBe('baz.$foo'));

        it('namespace', () => expect(clone.namespace).toBe('baz'));

        it('variableName', () => expect(clone.variableName).toBe('foo'));

        it('expression', () =>
          expect(clone).toHaveStringExpression('expression', 'bar'));

        it('global', () => expect(clone.global).toBe(false));

        it('guarded', () => expect(clone.guarded).toBe(true));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['expression', 'raws'] as const) {
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

      describe('namespace', () => {
        describe('defined', () => {
          let clone: VariableDeclaration;
          beforeEach(() => {
            clone = original.clone({namespace: 'zap'});
          });

          it('changes namespace', () => expect(clone.namespace).toBe('zap'));

          it('changes prop', () => expect(clone.prop).toBe('zap.$foo'));
        });

        describe('undefined', () => {
          let clone: VariableDeclaration;
          beforeEach(() => {
            clone = original.clone({namespace: undefined});
          });

          it('removes namespace', () =>
            expect(clone.namespace).toBeUndefined());

          it('changes prop', () => expect(clone.prop).toBe('$foo'));
        });
      });

      describe('variableName', () => {
        describe('defined', () => {
          let clone: VariableDeclaration;
          beforeEach(() => {
            clone = original.clone({variableName: 'zap'});
          });

          it('changes variableName', () =>
            expect(clone.variableName).toBe('zap'));

          it('changes prop', () => expect(clone.prop).toBe('baz.$zap'));
        });

        describe('undefined', () => {
          let clone: VariableDeclaration;
          beforeEach(() => {
            clone = original.clone({variableName: undefined});
          });

          it('preserves variableName', () =>
            expect(clone.variableName).toBe('foo'));

          it('preserves prop', () => expect(clone.prop).toBe('baz.$foo'));
        });
      });

      describe('expression', () => {
        it('defined changes expression', () =>
          expect(
            original.clone({expression: {text: 'zap'}}),
          ).toHaveStringExpression('expression', 'zap'));

        it('undefined preserves expression', () =>
          expect(
            original.clone({expression: undefined}),
          ).toHaveStringExpression('expression', 'bar'));
      });

      describe('guarded', () => {
        it('defined changes guarded', () =>
          expect(original.clone({guarded: false}).guarded).toBe(false));

        it('undefined preserves guarded', () =>
          expect(original.clone({guarded: undefined}).guarded).toBe(true));
      });

      describe('global', () => {
        it('defined changes global', () =>
          expect(original.clone({global: true}).global).toBe(true));

        it('undefined preserves global', () =>
          expect(original.clone({global: undefined}).global).toBe(false));
      });
    });
  });

  it('toJSON', () =>
    expect(scss.parse('baz.$foo: "bar"').nodes[0]).toMatchSnapshot());
});
