// Copyright 2024 Google Inc. Forward of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Configuration, ForwardRule, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a @forward rule', () => {
  let node: ForwardRule;
  describe('with just a URL', () => {
    function describeNode(
      description: string,
      create: () => ForwardRule,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('atrule'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('forward-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('forward'));

        it('has a url', () => expect(node.forwardUrl).toBe('foo'));

        it('has an empty prefix', () => expect(node.prefix).toBe(''));

        it('has no show', () => expect(node.show).toBeUndefined());

        it('has no hide', () => expect(node.hide).toBeUndefined());

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
      () => scss.parse('@forward "foo"').nodes[0] as ForwardRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@forward "foo"').nodes[0] as ForwardRule,
    );

    describeNode(
      'constructed manually',
      () =>
        new ForwardRule({
          forwardUrl: 'foo',
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        forwardUrl: 'foo',
      }),
    );
  });

  describe('with a prefix', () => {
    function describeNode(
      description: string,
      create: () => ForwardRule,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('atrule'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('forward-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('forward'));

        it('has a url', () => expect(node.forwardUrl).toBe('foo'));

        it('has a prefix', () => expect(node.prefix).toBe('bar-'));

        it('has no show', () => expect(node.show).toBeUndefined());

        it('has no hide', () => expect(node.hide).toBeUndefined());

        it('has an empty configuration', () => {
          expect(node.configuration.size).toBe(0);
          expect(node.configuration.parent).toBe(node);
        });

        it('has matching params', () =>
          expect(node.params).toBe('"foo" as bar-*'));

        it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@forward "foo" as bar-*').nodes[0] as ForwardRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@forward "foo" as bar-*').nodes[0] as ForwardRule,
    );

    describeNode(
      'constructed manually',
      () =>
        new ForwardRule({
          forwardUrl: 'foo',
          prefix: 'bar-',
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        forwardUrl: 'foo',
        prefix: 'bar-',
      }),
    );
  });

  describe('with shown names of both types', () => {
    function describeNode(
      description: string,
      create: () => ForwardRule,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('atrule'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('forward-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('forward'));

        it('has a url', () => expect(node.forwardUrl).toBe('foo'));

        it('has an empty prefix', () => expect(node.prefix).toBe(''));

        it('has show', () =>
          expect(node.show).toEqual({
            mixinsAndFunctions: new Set(['bar', 'qux']),
            variables: new Set(['baz']),
          }));

        it('has no hide', () => expect(node.hide).toBeUndefined());

        it('has an empty configuration', () => {
          expect(node.configuration.size).toBe(0);
          expect(node.configuration.parent).toBe(node);
        });

        it('has matching params', () =>
          expect(node.params).toBe('"foo" show bar, qux, $baz'));

        it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        scss.parse('@forward "foo" show bar, $baz, qux')
          .nodes[0] as ForwardRule,
    );

    describeNode(
      'parsed as Sass',
      () =>
        sass.parse('@forward "foo" show bar, $baz, qux')
          .nodes[0] as ForwardRule,
    );

    describeNode(
      'constructed manually',
      () =>
        new ForwardRule({
          forwardUrl: 'foo',
          show: {mixinsAndFunctions: ['bar', 'qux'], variables: ['baz']},
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        forwardUrl: 'foo',
        show: {mixinsAndFunctions: ['bar', 'qux'], variables: ['baz']},
      }),
    );
  });

  describe('with hidden names of one type only', () => {
    function describeNode(
      description: string,
      create: () => ForwardRule,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('atrule'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('forward-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('forward'));

        it('has a url', () => expect(node.forwardUrl).toBe('foo'));

        it('has an empty prefix', () => expect(node.prefix).toBe(''));

        it('has no show', () => expect(node.show).toBeUndefined());

        it('has hide', () =>
          expect(node.hide).toEqual({
            mixinsAndFunctions: new Set(['bar', 'baz']),
            variables: new Set(),
          }));

        it('has an empty configuration', () => {
          expect(node.configuration.size).toBe(0);
          expect(node.configuration.parent).toBe(node);
        });

        it('has matching params', () =>
          expect(node.params).toBe('"foo" hide bar, baz'));

        it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@forward "foo" hide bar, baz').nodes[0] as ForwardRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@forward "foo" hide bar, baz').nodes[0] as ForwardRule,
    );

    describeNode(
      'constructed manually',
      () =>
        new ForwardRule({
          forwardUrl: 'foo',
          hide: {mixinsAndFunctions: ['bar', 'baz']},
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        forwardUrl: 'foo',
        hide: {mixinsAndFunctions: ['bar', 'baz']},
      }),
    );
  });

  describe('with explicit configuration', () => {
    function describeNode(
      description: string,
      create: () => ForwardRule,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a type', () => expect(node.type.toString()).toBe('atrule'));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('forward-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('forward'));

        it('has a url', () => expect(node.forwardUrl).toBe('foo'));

        it('has an empty prefix', () => expect(node.prefix).toBe(''));

        it('has a configuration', () => {
          expect(node.configuration.size).toBe(1);
          expect(node.configuration.parent).toBe(node);
          const variables = [...node.configuration.variables()];
          expect(variables[0].variableName).toBe('baz');
          expect(variables[0]).toHaveStringExpression('expression', 'qux');
        });

        it('has matching params', () =>
          expect(node.params).toBe('"foo" with ($baz: "qux")'));

        it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        scss.parse('@forward "foo" with ($baz: "qux")').nodes[0] as ForwardRule,
    );

    describeNode(
      'parsed as Sass',
      () =>
        sass.parse('@forward "foo" with ($baz: "qux")').nodes[0] as ForwardRule,
    );

    describeNode(
      'constructed manually',
      () =>
        new ForwardRule({
          forwardUrl: 'foo',
          configuration: {
            variables: {baz: {text: 'qux', quotes: true}},
          },
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        forwardUrl: 'foo',
        configuration: {
          variables: {baz: {text: 'qux', quotes: true}},
        },
      }),
    );
  });

  describe('throws an error when assigned a new', () => {
    beforeEach(() => void (node = new ForwardRule({forwardUrl: 'foo'})));

    it('name', () => expect(() => (node.name = 'bar')).toThrow());

    it('params', () => expect(() => (node.params = 'bar')).toThrow());
  });

  it('assigned a new url', () => {
    node = new ForwardRule({forwardUrl: 'foo'});
    node.forwardUrl = 'bar';
    expect(node.forwardUrl).toBe('bar');
    expect(node.params).toBe('"bar"');
  });

  it('assigned a new prefix', () => {
    node = new ForwardRule({forwardUrl: 'foo'});
    node.prefix = 'bar-';
    expect(node.prefix).toBe('bar-');
    expect(node.params).toBe('"foo" as bar-*');
  });

  describe('assigned a new show', () => {
    it('defined unsets hide', () => {
      node = new ForwardRule({forwardUrl: 'foo', hide: {variables: ['bar']}});
      node.show = {mixinsAndFunctions: ['baz']};
      expect(node.show).toEqual({
        mixinsAndFunctions: new Set(['baz']),
        variables: new Set(),
      });
      expect(node.hide).toBeUndefined();
      expect(node.params).toBe('"foo" show baz');
    });

    it('undefined unsets show', () => {
      node = new ForwardRule({forwardUrl: 'foo', show: {variables: ['bar']}});
      node.show = undefined;
      expect(node.show).toBeUndefined();
      expect(node.params).toBe('"foo"');
    });

    it('undefined retains hide', () => {
      node = new ForwardRule({forwardUrl: 'foo', hide: {variables: ['bar']}});
      node.show = undefined;
      expect(node.show).toBeUndefined();
      expect(node.hide).toEqual({
        mixinsAndFunctions: new Set(),
        variables: new Set(['bar']),
      });
      expect(node.params).toBe('"foo" hide $bar');
    });
  });

  describe('assigned a new hide', () => {
    it('defined unsets show', () => {
      node = new ForwardRule({forwardUrl: 'foo', show: {variables: ['bar']}});
      node.hide = {mixinsAndFunctions: ['baz']};
      expect(node.hide).toEqual({
        mixinsAndFunctions: new Set(['baz']),
        variables: new Set(),
      });
      expect(node.show).toBeUndefined();
      expect(node.params).toBe('"foo" hide baz');
    });

    it('undefined unsets hide', () => {
      node = new ForwardRule({forwardUrl: 'foo', hide: {variables: ['bar']}});
      node.hide = undefined;
      expect(node.hide).toBeUndefined();
      expect(node.params).toBe('"foo"');
    });

    it('undefined retains show', () => {
      node = new ForwardRule({forwardUrl: 'foo', show: {variables: ['bar']}});
      node.hide = undefined;
      expect(node.hide).toBeUndefined();
      expect(node.show).toEqual({
        mixinsAndFunctions: new Set(),
        variables: new Set(['bar']),
      });
      expect(node.params).toBe('"foo" show $bar');
    });
  });

  it('assigned a new configuration', () => {
    node = new ForwardRule({forwardUrl: 'foo'});
    node.configuration = new Configuration({
      variables: {bar: {text: 'baz', quotes: true}},
    });
    expect(node.configuration.size).toBe(1);
    expect(node.params).toBe('"foo" with ($bar: "baz")');
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with a prefix', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              prefix: 'bar-',
            }).toString(),
          ).toBe('@forward "foo" as bar-*;'));

        it('with a non-identifier prefix', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              prefix: ' ',
            }).toString(),
          ).toBe('@forward "foo" as \\20*;'));

        it('with show', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              show: {mixinsAndFunctions: ['bar'], variables: ['baz', 'qux']},
            }).toString(),
          ).toBe('@forward "foo" show bar, $baz, $qux;'));

        it('with a non-identifier show', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              show: {mixinsAndFunctions: [' ']},
            }).toString(),
          ).toBe('@forward "foo" show \\20;'));

        it('with hide', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              hide: {mixinsAndFunctions: ['bar'], variables: ['baz', 'qux']},
            }).toString(),
          ).toBe('@forward "foo" hide bar, $baz, $qux;'));

        it('with a non-identifier hide', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              hide: {mixinsAndFunctions: [' ']},
            }).toString(),
          ).toBe('@forward "foo" hide \\20;'));

        it('with configuration', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              configuration: {
                variables: {bar: {text: 'baz', quotes: true}},
              },
            }).toString(),
          ).toBe('@forward "foo" with ($bar: "baz");'));
      });

      describe('with a URL raw', () => {
        it('that matches', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              raws: {url: {raw: "'foo'", value: 'foo'}},
            }).toString(),
          ).toBe("@forward 'foo';"));

        it("that doesn't match", () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              raws: {url: {raw: "'bar'", value: 'bar'}},
            }).toString(),
          ).toBe('@forward "foo";'));
      });

      describe('with a prefix raw', () => {
        it('that matches', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              prefix: 'bar-',
              raws: {prefix: {raw: '  as  bar-*', value: 'bar-'}},
            }).toString(),
          ).toBe('@forward "foo"  as  bar-*;'));

        it("that doesn't match", () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              prefix: 'baz-',
              raws: {url: {raw: '  as  bar-*', value: 'bar-'}},
            }).toString(),
          ).toBe('@forward "foo" as baz-*;'));
      });

      describe('with show', () => {
        it('that matches', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              show: {mixinsAndFunctions: ['bar', 'baz']},
              raws: {
                show: {
                  raw: '  show  bar, baz',
                  value: {
                    mixinsAndFunctions: new Set(['bar', 'baz']),
                    variables: new Set(),
                  },
                },
              },
            }).toString(),
          ).toBe('@forward "foo"  show  bar, baz;'));

        it('that has an extra member', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              show: {mixinsAndFunctions: ['bar', 'baz']},
              raws: {
                show: {
                  raw: '  show  bar, baz, $qux',
                  value: {
                    mixinsAndFunctions: new Set(['bar', 'baz']),
                    variables: new Set(['qux']),
                  },
                },
              },
            }).toString(),
          ).toBe('@forward "foo" show bar, baz;'));

        it("that's missing a member", () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              show: {mixinsAndFunctions: ['bar', 'baz']},
              raws: {
                show: {
                  raw: '  show  bar',
                  value: {
                    mixinsAndFunctions: new Set(['bar']),
                    variables: new Set(),
                  },
                },
              },
            }).toString(),
          ).toBe('@forward "foo" show bar, baz;'));
      });

      describe('with hide', () => {
        it('that matches', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              hide: {mixinsAndFunctions: ['bar', 'baz']},
              raws: {
                hide: {
                  raw: '  hide  bar, baz',
                  value: {
                    mixinsAndFunctions: new Set(['bar', 'baz']),
                    variables: new Set(),
                  },
                },
              },
            }).toString(),
          ).toBe('@forward "foo"  hide  bar, baz;'));

        it('that has an extra member', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              hide: {mixinsAndFunctions: ['bar', 'baz']},
              raws: {
                hide: {
                  raw: '  hide  bar, baz, $qux',
                  value: {
                    mixinsAndFunctions: new Set(['bar', 'baz']),
                    variables: new Set(['qux']),
                  },
                },
              },
            }).toString(),
          ).toBe('@forward "foo" hide bar, baz;'));

        it("that's missing a member", () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              hide: {mixinsAndFunctions: ['bar', 'baz']},
              raws: {
                hide: {
                  raw: '  hide  bar',
                  value: {
                    mixinsAndFunctions: new Set(['bar']),
                    variables: new Set(),
                  },
                },
              },
            }).toString(),
          ).toBe('@forward "foo" hide bar, baz;'));
      });

      describe('with beforeWith', () => {
        it('and a configuration', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              configuration: {
                variables: {bar: {text: 'baz', quotes: true}},
              },
              raws: {beforeWith: '/**/'},
            }).toString(),
          ).toBe('@forward "foo"/**/with ($bar: "baz");'));

        it('and no configuration', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              raws: {beforeWith: '/**/'},
            }).toString(),
          ).toBe('@forward "foo";'));
      });

      describe('with afterWith', () => {
        it('and a configuration', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              configuration: {
                variables: {bar: {text: 'baz', quotes: true}},
              },
              raws: {afterWith: '/**/'},
            }).toString(),
          ).toBe('@forward "foo" with/**/($bar: "baz");'));

        it('and no configuration', () =>
          expect(
            new ForwardRule({
              forwardUrl: 'foo',
              raws: {afterWith: '/**/'},
            }).toString(),
          ).toBe('@forward "foo";'));
      });
    });
  });

  describe('clone', () => {
    let original: ForwardRule;
    beforeEach(() => {
      original = scss.parse(
        '@forward "foo" as bar-* show baz, $qux with ($zip: "zap")',
      ).nodes[0] as ForwardRule;
      // TODO: remove this once raws are properly parsed
      original.raws.beforeWith = '  ';
    });

    describe('with no overrides', () => {
      let clone: ForwardRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () =>
          expect(clone.params).toBe(
            '"foo" as bar-* show baz, $qux  with ($zip: "zap")',
          ));

        it('forwardUrl', () => expect(clone.forwardUrl).toBe('foo'));

        it('prefix', () => expect(clone.prefix).toBe('bar-'));

        it('show', () =>
          expect(clone.show).toEqual({
            mixinsAndFunctions: new Set(['baz']),
            variables: new Set(['qux']),
          }));

        it('hide', () => expect(clone.hide).toBeUndefined());

        it('configuration', () => {
          expect(clone.configuration.size).toBe(1);
          expect(clone.configuration.parent).toBe(clone);
          const variables = [...clone.configuration.variables()];
          expect(variables[0].variableName).toBe('zip');
          expect(variables[0]).toHaveStringExpression('expression', 'zap');
        });

        it('raws', () => expect(clone.raws).toEqual({beforeWith: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['show', 'configuration', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }

        it('show.mixinsAndFunctions', () =>
          expect(clone.show!.mixinsAndFunctions).not.toBe(
            original.show!.mixinsAndFunctions,
          ));

        it('show.variables', () =>
          expect(clone.show!.variables).not.toBe(original.show!.variables));
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

      describe('forwardUrl', () => {
        describe('defined', () => {
          let clone: ForwardRule;
          beforeEach(() => {
            clone = original.clone({forwardUrl: 'flip'});
          });

          it('changes forwardUrl', () => expect(clone.forwardUrl).toBe('flip'));

          it('changes params', () =>
            expect(clone.params).toBe(
              '"flip" as bar-* show baz, $qux  with ($zip: "zap")',
            ));
        });

        describe('undefined', () => {
          let clone: ForwardRule;
          beforeEach(() => {
            clone = original.clone({forwardUrl: undefined});
          });

          it('preserves forwardUrl', () =>
            expect(clone.forwardUrl).toBe('foo'));

          it('preserves params', () =>
            expect(clone.params).toBe(
              '"foo" as bar-* show baz, $qux  with ($zip: "zap")',
            ));
        });
      });

      describe('prefix', () => {
        describe('defined', () => {
          let clone: ForwardRule;
          beforeEach(() => {
            clone = original.clone({prefix: 'flip-'});
          });

          it('changes prefix', () => expect(clone.prefix).toBe('flip-'));

          it('changes params', () =>
            expect(clone.params).toBe(
              '"foo" as flip-* show baz, $qux  with ($zip: "zap")',
            ));
        });

        describe('undefined', () => {
          let clone: ForwardRule;
          beforeEach(() => {
            clone = original.clone({prefix: undefined});
          });

          it('preserves prefix', () => expect(clone.prefix).toBe('bar-'));

          it('preserves params', () =>
            expect(clone.params).toBe(
              '"foo" as bar-* show baz, $qux  with ($zip: "zap")',
            ));
        });
      });

      describe('show', () => {
        describe('defined', () => {
          let clone: ForwardRule;
          beforeEach(() => {
            clone = original.clone({show: {variables: ['flip']}});
          });

          it('changes show', () =>
            expect(clone.show).toEqual({
              mixinsAndFunctions: new Set([]),
              variables: new Set(['flip']),
            }));

          it('changes params', () =>
            expect(clone.params).toBe(
              '"foo" as bar-* show $flip  with ($zip: "zap")',
            ));
        });

        describe('undefined', () => {
          let clone: ForwardRule;
          beforeEach(() => {
            clone = original.clone({show: undefined});
          });

          it('changes show', () => expect(clone.show).toBeUndefined());

          it('changes params', () =>
            expect(clone.params).toBe('"foo" as bar-*  with ($zip: "zap")'));
        });
      });

      describe('hide', () => {
        describe('defined', () => {
          let clone: ForwardRule;
          beforeEach(() => {
            clone = original.clone({hide: {variables: ['flip']}});
          });

          it('changes show', () => expect(clone.show).toBeUndefined());

          it('changes hide', () =>
            expect(clone.hide).toEqual({
              mixinsAndFunctions: new Set([]),
              variables: new Set(['flip']),
            }));

          it('changes params', () =>
            expect(clone.params).toBe(
              '"foo" as bar-* hide $flip  with ($zip: "zap")',
            ));
        });

        describe('undefined', () => {
          let clone: ForwardRule;
          beforeEach(() => {
            clone = original.clone({hide: undefined});
          });

          it('preserves show', () =>
            expect(clone.show).toEqual({
              mixinsAndFunctions: new Set(['baz']),
              variables: new Set(['qux']),
            }));

          it('preserves hide', () => expect(clone.hide).toBeUndefined());

          it('preserves params', () =>
            expect(clone.params).toBe(
              '"foo" as bar-* show baz, $qux  with ($zip: "zap")',
            ));
        });
      });

      describe('configuration', () => {
        describe('defined', () => {
          let clone: ForwardRule;
          beforeEach(() => {
            clone = original.clone({configuration: new Configuration()});
          });

          it('changes configuration', () =>
            expect(clone.configuration.size).toBe(0));

          it('changes params', () =>
            expect(clone.params).toBe('"foo" as bar-* show baz, $qux'));
        });

        describe('undefined', () => {
          let clone: ForwardRule;
          beforeEach(() => {
            clone = original.clone({configuration: undefined});
          });

          it('preserves configuration', () => {
            expect(clone.configuration.size).toBe(1);
            expect(clone.configuration.parent).toBe(clone);
            const variables = [...clone.configuration.variables()];
            expect(variables[0].variableName).toBe('zip');
            expect(variables[0]).toHaveStringExpression('expression', 'zap');
          });

          it('preserves params', () =>
            expect(clone.params).toBe(
              '"foo" as bar-* show baz, $qux  with ($zip: "zap")',
            ));
        });
      });
    });
  });

  // Can't JSON-serialize this until we implement Configuration.source.span
  it.skip('toJSON', () =>
    expect(
      scss.parse('@forward "foo" as bar-* show baz, $qux with ($zip: "zap")')
        .nodes[0],
    ).toMatchSnapshot());
});
