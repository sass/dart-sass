// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Configuration, UseRule, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a @use rule', () => {
  let node: UseRule;
  describe('with just a URL', () => {
    function describeNode(description: string, create: () => UseRule): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('atrule'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('use-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('use'));

        it('has a url', () => expect(node.useUrl).toBe('foo'));

        it('has a default namespace', () => expect(node.namespace).toBe('foo'));

        it('has an empty configuration', () => {
          expect(node.configuration.size).toBe(0);
          expect(node.configuration.parent).toBe(node);
        });

        it('has matching params', () => expect(node.params).toBe('"foo"'));

        it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@use "foo"').nodes[0] as UseRule
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@use "foo"').nodes[0] as UseRule
    );

    describeNode(
      'constructed manually',
      () =>
        new UseRule({
          useUrl: 'foo',
        })
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        useUrl: 'foo',
      })
    );
  });

  describe('with no namespace', () => {
    function describeNode(description: string, create: () => UseRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('atrule'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('use-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('use'));

        it('has a url', () => expect(node.useUrl).toBe('foo'));

        it('has a null namespace', () => expect(node.namespace).toBeNull());

        it('has an empty configuration', () => {
          expect(node.configuration.size).toBe(0);
          expect(node.configuration.parent).toBe(node);
        });

        it('has matching params', () => expect(node.params).toBe('"foo" as *'));

        it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@use "foo" as *').nodes[0] as UseRule
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@use "foo" as *').nodes[0] as UseRule
    );

    describeNode(
      'constructed manually',
      () =>
        new UseRule({
          useUrl: 'foo',
          namespace: null,
        })
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        useUrl: 'foo',
        namespace: null,
      })
    );
  });

  describe('with explicit namespace and configuration', () => {
    function describeNode(description: string, create: () => UseRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('atrule'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('use-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('use'));

        it('has a url', () => expect(node.useUrl).toBe('foo'));

        it('has an explicit', () => expect(node.namespace).toBe('bar'));

        it('has an empty configuration', () => {
          expect(node.configuration.size).toBe(1);
          expect(node.configuration.parent).toBe(node);
          const variables = [...node.configuration.variables()];
          expect(variables[0].name).toBe('baz');
          expect(variables[0]).toHaveStringExpression('value', 'qux');
        });

        it('has matching params', () =>
          expect(node.params).toBe('"foo" as bar with ($baz: "qux")'));

        it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        scss.parse('@use "foo" as bar with ($baz: "qux")').nodes[0] as UseRule
    );

    describeNode(
      'parsed as Sass',
      () =>
        sass.parse('@use "foo" as bar with ($baz: "qux")').nodes[0] as UseRule
    );

    describeNode(
      'constructed manually',
      () =>
        new UseRule({
          useUrl: 'foo',
          namespace: 'bar',
          configuration: {
            variables: {baz: {text: 'qux', quotes: true}},
          },
        })
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        useUrl: 'foo',
        namespace: 'bar',
        configuration: {
          variables: {baz: {text: 'qux', quotes: true}},
        },
      })
    );
  });

  describe('throws an error when assigned a new', () => {
    beforeEach(() => void (node = new UseRule({useUrl: 'foo'})));

    it('name', () => expect(() => (node.name = 'bar')).toThrow());

    it('params', () => expect(() => (node.params = 'bar')).toThrow());
  });

  it('assigned a new url', () => {
    node = new UseRule({useUrl: 'foo'});
    node.useUrl = 'bar';
    expect(node.useUrl).toBe('bar');
    expect(node.params).toBe('"bar" as foo');
    expect(node.defaultNamespace).toBe('bar');
  });

  it('assigned a new namespace', () => {
    node = new UseRule({useUrl: 'foo'});
    node.namespace = 'bar';
    expect(node.namespace).toBe('bar');
    expect(node.params).toBe('"foo" as bar');
    expect(node.defaultNamespace).toBe('foo');
  });

  it('assigned a new configuration', () => {
    node = new UseRule({useUrl: 'foo'});
    node.configuration = new Configuration({
      variables: {bar: {text: 'baz', quotes: true}},
    });
    expect(node.configuration.size).toBe(1);
    expect(node.params).toBe('"foo" with ($bar: "baz")');
  });

  describe('defaultNamespace', () => {
    describe('is null for', () => {
      it('a URL without a pathname', () =>
        expect(
          new UseRule({useUrl: 'https://example.org'}).defaultNamespace
        ).toBeNull());

      it('a URL with a slash pathname', () =>
        expect(
          new UseRule({useUrl: 'https://example.org/'}).defaultNamespace
        ).toBeNull());

      it('a basename that starts with .', () =>
        expect(new UseRule({useUrl: '.foo'}).defaultNamespace).toBeNull());

      it('a fragment', () =>
        expect(new UseRule({useUrl: '#foo'}).defaultNamespace).toBeNull());

      it('a path that ends in /', () =>
        expect(new UseRule({useUrl: 'foo/'}).defaultNamespace).toBeNull());

      it('an invalid identifier', () =>
        expect(new UseRule({useUrl: '123'}).defaultNamespace).toBeNull());
    });

    it('the basename', () =>
      expect(new UseRule({useUrl: 'foo/bar/baz'}).defaultNamespace).toBe(
        'baz'
      ));

    it('without an extension', () =>
      expect(new UseRule({useUrl: 'foo.scss'}).defaultNamespace).toBe('foo'));

    it('the basename of an HTTP URL', () =>
      expect(
        new UseRule({useUrl: 'http://example.org/foo/bar/baz'}).defaultNamespace
      ).toBe('baz'));

    it('the basename of a file: URL', () =>
      expect(
        new UseRule({useUrl: 'file:///foo/bar/baz'}).defaultNamespace
      ).toBe('baz'));

    it('the basename of an unknown scheme URL', () =>
      expect(new UseRule({useUrl: 'foo:bar/bar/qux'}).defaultNamespace).toBe(
        'qux'
      ));

    it('a sass: URL', () =>
      expect(new UseRule({useUrl: 'sass:foo'}).defaultNamespace).toBe('foo'));
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with a non-default namespace', () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              namespace: 'bar',
            }).toString()
          ).toBe('@use "foo" as bar;'));

        it('with a non-identifier namespace', () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              namespace: ' ',
            }).toString()
          ).toBe('@use "foo" as \\20 ;'));

        it('with no namespace', () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              namespace: null,
            }).toString()
          ).toBe('@use "foo" as *;'));

        it('with configuration', () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              configuration: {
                variables: {bar: {text: 'baz', quotes: true}},
              },
            }).toString()
          ).toBe('@use "foo" with ($bar: "baz");'));
      });

      describe('with a URL raw', () => {
        it('that matches', () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              raws: {url: {raw: "'foo'", value: 'foo'}},
            }).toString()
          ).toBe("@use 'foo';"));

        it("that doesn't match", () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              raws: {url: {raw: "'bar'", value: 'bar'}},
            }).toString()
          ).toBe('@use "foo";'));
      });

      describe('with a namespace raw', () => {
        it('that matches a string', () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              raws: {namespace: {raw: '  as  foo', value: 'foo'}},
            }).toString()
          ).toBe('@use "foo"  as  foo;'));

        it('that matches null', () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              namespace: null,
              raws: {namespace: {raw: '  as  *', value: null}},
            }).toString()
          ).toBe('@use "foo"  as  *;'));

        it("that doesn't match", () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              raws: {url: {raw: '  as  bar', value: 'bar'}},
            }).toString()
          ).toBe('@use "foo";'));
      });

      describe('with beforeWith', () => {
        it('and a configuration', () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              configuration: {
                variables: {bar: {text: 'baz', quotes: true}},
              },
              raws: {beforeWith: '/**/'},
            }).toString()
          ).toBe('@use "foo"/**/with ($bar: "baz");'));

        it('and no configuration', () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              raws: {beforeWith: '/**/'},
            }).toString()
          ).toBe('@use "foo";'));
      });

      describe('with afterWith', () => {
        it('and a configuration', () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              configuration: {
                variables: {bar: {text: 'baz', quotes: true}},
              },
              raws: {afterWith: '/**/'},
            }).toString()
          ).toBe('@use "foo" with/**/($bar: "baz");'));

        it('and no configuration', () =>
          expect(
            new UseRule({
              useUrl: 'foo',
              raws: {afterWith: '/**/'},
            }).toString()
          ).toBe('@use "foo";'));
      });
    });
  });

  describe('clone', () => {
    let original: UseRule;
    beforeEach(() => {
      original = scss.parse('@use "foo" as bar with ($baz: "qux")')
        .nodes[0] as UseRule;
      // TODO: remove this once raws are properly parsed
      original.raws.beforeWith = '  ';
    });

    describe('with no overrides', () => {
      let clone: UseRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () =>
          expect(clone.params).toBe('"foo" as bar  with ($baz: "qux")'));

        it('url', () => expect(clone.useUrl).toBe('foo'));

        it('namespace', () => expect(clone.namespace).toBe('bar'));

        it('configuration', () => {
          expect(clone.configuration.size).toBe(1);
          expect(clone.configuration.parent).toBe(clone);
          const variables = [...clone.configuration.variables()];
          expect(variables[0].name).toBe('baz');
          expect(variables[0]).toHaveStringExpression('value', 'qux');
        });

        it('raws', () => expect(clone.raws).toEqual({beforeWith: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['configuration', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {afterWith: '  '}}).raws).toEqual({
            afterWith: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            beforeWith: '  ',
          }));
      });

      describe('useUrl', () => {
        describe('defined', () => {
          let clone: UseRule;
          beforeEach(() => {
            clone = original.clone({useUrl: 'flip'});
          });

          it('changes useUrl', () => expect(clone.useUrl).toBe('flip'));

          it('changes params', () =>
            expect(clone.params).toBe('"flip" as bar  with ($baz: "qux")'));
        });

        describe('undefined', () => {
          let clone: UseRule;
          beforeEach(() => {
            clone = original.clone({useUrl: undefined});
          });

          it('preserves useUrl', () => expect(clone.useUrl).toBe('foo'));

          it('preserves params', () =>
            expect(clone.params).toBe('"foo" as bar  with ($baz: "qux")'));
        });
      });

      describe('namespace', () => {
        describe('defined', () => {
          let clone: UseRule;
          beforeEach(() => {
            clone = original.clone({namespace: 'flip'});
          });

          it('changes namespace', () => expect(clone.namespace).toBe('flip'));

          it('changes params', () =>
            expect(clone.params).toBe('"foo" as flip  with ($baz: "qux")'));
        });

        describe('null', () => {
          let clone: UseRule;
          beforeEach(() => {
            clone = original.clone({namespace: null});
          });

          it('changes namespace', () => expect(clone.namespace).toBeNull());

          it('changes params', () =>
            expect(clone.params).toBe('"foo" as *  with ($baz: "qux")'));
        });

        describe('undefined', () => {
          let clone: UseRule;
          beforeEach(() => {
            clone = original.clone({namespace: undefined});
          });

          it('preserves namespace', () => expect(clone.namespace).toBe('bar'));

          it('preserves params', () =>
            expect(clone.params).toBe('"foo" as bar  with ($baz: "qux")'));
        });
      });

      describe('configuration', () => {
        describe('defined', () => {
          let clone: UseRule;
          beforeEach(() => {
            clone = original.clone({configuration: new Configuration()});
          });

          it('changes configuration', () =>
            expect(clone.configuration.size).toBe(0));

          it('changes params', () => expect(clone.params).toBe('"foo" as bar'));
        });

        describe('undefined', () => {
          let clone: UseRule;
          beforeEach(() => {
            clone = original.clone({configuration: undefined});
          });

          it('preserves configuration', () => {
            expect(clone.configuration.size).toBe(1);
            expect(clone.configuration.parent).toBe(clone);
            const variables = [...clone.configuration.variables()];
            expect(variables[0].name).toBe('baz');
            expect(variables[0]).toHaveStringExpression('value', 'qux');
          });

          it('preserves params', () =>
            expect(clone.params).toBe('"foo" as bar  with ($baz: "qux")'));
        });
      });
    });
  });

  // Can't JSON-serialize this until we implement Configuration.source.span
  it.skip('toJSON', () =>
    expect(
      scss.parse('@use "foo" as bar with ($baz: "qux")').nodes[0]
    ).toMatchSnapshot());
});
