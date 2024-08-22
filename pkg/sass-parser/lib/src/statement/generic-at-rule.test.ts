// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {GenericAtRule, Interpolation, Root, Rule, css, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a generic @-rule', () => {
  let node: GenericAtRule;
  describe('with no children', () => {
    describe('with no params', () => {
      function describeNode(
        description: string,
        create: () => GenericAtRule
      ): void {
        describe(description, () => {
          beforeEach(() => void (node = create()));

          it('has type atrule', () => expect(node.type).toBe('atrule'));

          it('has sassType atrule', () => expect(node.sassType).toBe('atrule'));

          it('has a nameInterpolation', () =>
            expect(node).toHaveInterpolation('nameInterpolation', 'foo'));

          it('has a name', () => expect(node.name).toBe('foo'));

          it('has no paramsInterpolation', () =>
            expect(node.paramsInterpolation).toBeUndefined());

          it('has empty params', () => expect(node.params).toBe(''));

          it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
        });
      }

      describeNode(
        'parsed as SCSS',
        () => scss.parse('@foo').nodes[0] as GenericAtRule
      );

      describeNode(
        'parsed as CSS',
        () => css.parse('@foo').nodes[0] as GenericAtRule
      );

      describeNode(
        'parsed as Sass',
        () => sass.parse('@foo').nodes[0] as GenericAtRule
      );

      describe('constructed manually', () => {
        describeNode(
          'with a name interpolation',
          () =>
            new GenericAtRule({
              nameInterpolation: new Interpolation({nodes: ['foo']}),
            })
        );

        describeNode(
          'with a name string',
          () => new GenericAtRule({name: 'foo'})
        );
      });

      describe('constructed from ChildProps', () => {
        describeNode('with a name interpolation', () =>
          utils.fromChildProps({
            nameInterpolation: new Interpolation({nodes: ['foo']}),
          })
        );

        describeNode('with a name string', () =>
          utils.fromChildProps({name: 'foo'})
        );
      });
    });

    describe('with params', () => {
      function describeNode(
        description: string,
        create: () => GenericAtRule
      ): void {
        describe(description, () => {
          beforeEach(() => void (node = create()));

          it('has a name', () => expect(node.name.toString()).toBe('foo'));

          it('has a paramsInterpolation', () =>
            expect(node).toHaveInterpolation('paramsInterpolation', 'bar'));

          it('has matching params', () => expect(node.params).toBe('bar'));

          it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
        });
      }

      describeNode(
        'parsed as SCSS',
        () => scss.parse('@foo bar').nodes[0] as GenericAtRule
      );

      describeNode(
        'parsed as CSS',
        () => css.parse('@foo bar').nodes[0] as GenericAtRule
      );

      describeNode(
        'parsed as Sass',
        () => sass.parse('@foo bar').nodes[0] as GenericAtRule
      );

      describe('constructed manually', () => {
        describeNode(
          'with an interpolation',
          () =>
            new GenericAtRule({
              name: 'foo',
              paramsInterpolation: new Interpolation({nodes: ['bar']}),
            })
        );

        describeNode(
          'with a param string',
          () => new GenericAtRule({name: 'foo', params: 'bar'})
        );
      });

      describe('constructed from ChildProps', () => {
        describeNode('with an interpolation', () =>
          utils.fromChildProps({
            name: 'foo',
            paramsInterpolation: new Interpolation({nodes: ['bar']}),
          })
        );

        describeNode('with a param string', () =>
          utils.fromChildProps({name: 'foo', params: 'bar'})
        );
      });
    });
  });

  describe('with empty children', () => {
    describe('with no params', () => {
      function describeNode(
        description: string,
        create: () => GenericAtRule
      ): void {
        describe(description, () => {
          beforeEach(() => void (node = create()));

          it('has a name', () => expect(node.name).toBe('foo'));

          it('has no paramsInterpolation', () =>
            expect(node.paramsInterpolation).toBeUndefined());

          it('has empty params', () => expect(node.params).toBe(''));

          it('has no nodes', () => expect(node.nodes).toHaveLength(0));
        });
      }

      describeNode(
        'parsed as SCSS',
        () => scss.parse('@foo {}').nodes[0] as GenericAtRule
      );

      describeNode(
        'parsed as CSS',
        () => css.parse('@foo {}').nodes[0] as GenericAtRule
      );

      describeNode(
        'constructed manually',
        () => new GenericAtRule({name: 'foo', nodes: []})
      );

      describeNode('constructed from ChildProps', () =>
        utils.fromChildProps({name: 'foo', nodes: []})
      );
    });

    describe('with params', () => {
      function describeNode(
        description: string,
        create: () => GenericAtRule
      ): void {
        describe(description, () => {
          beforeEach(() => void (node = create()));

          it('has a name', () => expect(node.name.toString()).toBe('foo'));

          it('has a paramsInterpolation', () =>
            expect(node).toHaveInterpolation('paramsInterpolation', 'bar '));

          it('has matching params', () => expect(node.params).toBe('bar '));
        });
      }

      describeNode(
        'parsed as SCSS',
        () => scss.parse('@foo bar {}').nodes[0] as GenericAtRule
      );

      describeNode(
        'parsed as CSS',
        () => css.parse('@foo bar {}').nodes[0] as GenericAtRule
      );

      describe('constructed manually', () => {
        describeNode(
          'with params',
          () =>
            new GenericAtRule({
              name: 'foo',
              params: 'bar ',
              nodes: [],
            })
        );

        describeNode(
          'with an interpolation',
          () =>
            new GenericAtRule({
              name: 'foo',
              paramsInterpolation: new Interpolation({nodes: ['bar ']}),
              nodes: [],
            })
        );
      });

      describe('constructed from ChildProps', () => {
        describeNode('with params', () =>
          utils.fromChildProps({
            name: 'foo',
            params: 'bar ',
            nodes: [],
          })
        );

        describeNode('with an interpolation', () =>
          utils.fromChildProps({
            name: 'foo',
            paramsInterpolation: new Interpolation({nodes: ['bar ']}),
            nodes: [],
          })
        );
      });
    });
  });

  describe('with a child', () => {
    describe('with no params', () => {
      describe('parsed as Sass', () => {
        beforeEach(() => {
          node = sass.parse('@foo\n  .bar').nodes[0] as GenericAtRule;
        });

        it('has a name', () => expect(node.name).toBe('foo'));

        it('has no paramsInterpolation', () =>
          expect(node.paramsInterpolation).toBeUndefined());

        it('has empty params', () => expect(node.params).toBe(''));

        it('has a child node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0]).toBeInstanceOf(Rule);
          expect(node.nodes[0]).toHaveProperty('selector', '.bar\n');
        });
      });
    });

    describe('with params', () => {
      function describeNode(
        description: string,
        create: () => GenericAtRule
      ): void {
        describe(description, () => {
          beforeEach(() => void (node = create()));

          it('has a name', () => expect(node.name.toString()).toBe('foo'));

          it('has a paramsInterpolation', () =>
            expect(node).toHaveInterpolation('paramsInterpolation', 'bar'));

          it('has matching params', () => expect(node.params).toBe('bar'));

          it('has a child node', () => {
            expect(node.nodes).toHaveLength(1);
            expect(node.nodes[0]).toBeInstanceOf(Rule);
            expect(node.nodes[0]).toHaveProperty('selector', '.baz\n');
          });
        });
      }

      describeNode(
        'parsed as Sass',
        () => sass.parse('@foo bar\n  .baz').nodes[0] as GenericAtRule
      );

      describe('constructed manually', () => {
        describeNode(
          'with params',
          () =>
            new GenericAtRule({
              name: 'foo',
              params: 'bar',
              nodes: [{selector: '.baz\n'}],
            })
        );
      });

      describe('constructed from ChildProps', () => {
        describeNode('with params', () =>
          utils.fromChildProps({
            name: 'foo',
            params: 'bar',
            nodes: [{selector: '.baz\n'}],
          })
        );
      });
    });
  });

  describe('assigned new name', () => {
    beforeEach(() => {
      node = scss.parse('@foo {}').nodes[0] as GenericAtRule;
    });

    it("removes the old name's parent", () => {
      const oldName = node.nameInterpolation!;
      node.nameInterpolation = 'bar';
      expect(oldName.parent).toBeUndefined();
    });

    it("assigns the new interpolation's parent", () => {
      const interpolation = new Interpolation({nodes: ['bar']});
      node.nameInterpolation = interpolation;
      expect(interpolation.parent).toBe(node);
    });

    it('assigns the interpolation explicitly', () => {
      const interpolation = new Interpolation({nodes: ['bar']});
      node.nameInterpolation = interpolation;
      expect(node.nameInterpolation).toBe(interpolation);
    });

    it('assigns the interpolation as a string', () => {
      node.nameInterpolation = 'bar';
      expect(node).toHaveInterpolation('nameInterpolation', 'bar');
    });

    it('assigns the interpolation as name', () => {
      node.name = 'bar';
      expect(node).toHaveInterpolation('nameInterpolation', 'bar');
    });
  });

  describe('assigned new params', () => {
    beforeEach(() => {
      node = scss.parse('@foo bar {}').nodes[0] as GenericAtRule;
    });

    it('removes the old interpolation', () => {
      node.paramsInterpolation = undefined;
      expect(node.paramsInterpolation).toBeUndefined();
    });

    it('removes the old interpolation as undefined params', () => {
      node.params = undefined;
      expect(node.params).toBe('');
      expect(node.paramsInterpolation).toBeUndefined();
    });

    it('removes the old interpolation as empty string params', () => {
      node.params = '';
      expect(node.params).toBe('');
      expect(node.paramsInterpolation).toBeUndefined();
    });

    it("removes the old interpolation's parent", () => {
      const oldParams = node.paramsInterpolation!;
      node.paramsInterpolation = undefined;
      expect(oldParams.parent).toBeUndefined();
    });

    it("assigns the new interpolation's parent", () => {
      const interpolation = new Interpolation({nodes: ['baz']});
      node.paramsInterpolation = interpolation;
      expect(interpolation.parent).toBe(node);
    });

    it('assigns the interpolation explicitly', () => {
      const interpolation = new Interpolation({nodes: ['baz']});
      node.paramsInterpolation = interpolation;
      expect(node.paramsInterpolation).toBe(interpolation);
    });

    it('assigns the interpolation as a string', () => {
      node.paramsInterpolation = 'baz';
      expect(node).toHaveInterpolation('paramsInterpolation', 'baz');
    });

    it('assigns the interpolation as params', () => {
      node.params = 'baz';
      expect(node).toHaveInterpolation('paramsInterpolation', 'baz');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with undefined nodes', () => {
        describe('without params', () => {
          it('with default raws', () =>
            expect(new GenericAtRule({name: 'foo'}).toString()).toBe('@foo;'));

          it('with afterName', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                raws: {afterName: '/**/'},
              }).toString()
            ).toBe('@foo/**/;'));

          it('with afterName', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                raws: {afterName: '/**/'},
              }).toString()
            ).toBe('@foo/**/;'));

          it('with between', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                raws: {between: '/**/'},
              }).toString()
            ).toBe('@foo/**/;'));

          it('with afterName and between', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                raws: {afterName: '/*afterName*/', between: '/*between*/'},
              }).toString()
            ).toBe('@foo/*afterName*//*between*/;'));
        });

        describe('with params', () => {
          it('with default raws', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                paramsInterpolation: 'baz',
              }).toString()
            ).toBe('@foo baz;'));

          it('with afterName', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                paramsInterpolation: 'baz',
                raws: {afterName: '/**/'},
              }).toString()
            ).toBe('@foo/**/baz;'));

          it('with between', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                paramsInterpolation: 'baz',
                raws: {between: '/**/'},
              }).toString()
            ).toBe('@foo baz/**/;'));
        });

        it('with after', () =>
          expect(
            new GenericAtRule({name: 'foo', raws: {after: '/**/'}}).toString()
          ).toBe('@foo;'));

        it('with before', () =>
          expect(
            new Root({
              nodes: [new GenericAtRule({name: 'foo', raws: {before: '/**/'}})],
            }).toString()
          ).toBe('/**/@foo'));
      });

      describe('with defined nodes', () => {
        describe('without params', () => {
          it('with default raws', () =>
            expect(new GenericAtRule({name: 'foo', nodes: []}).toString()).toBe(
              '@foo {}'
            ));

          it('with afterName', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                raws: {afterName: '/**/'},
                nodes: [],
              }).toString()
            ).toBe('@foo/**/ {}'));

          it('with afterName', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                raws: {afterName: '/**/'},
                nodes: [],
              }).toString()
            ).toBe('@foo/**/ {}'));

          it('with between', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                raws: {between: '/**/'},
                nodes: [],
              }).toString()
            ).toBe('@foo/**/{}'));

          it('with afterName and between', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                raws: {afterName: '/*afterName*/', between: '/*between*/'},
                nodes: [],
              }).toString()
            ).toBe('@foo/*afterName*//*between*/{}'));
        });

        describe('with params', () => {
          it('with default raws', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                paramsInterpolation: 'baz',
                nodes: [],
              }).toString()
            ).toBe('@foo baz {}'));

          it('with afterName', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                paramsInterpolation: 'baz',
                raws: {afterName: '/**/'},
                nodes: [],
              }).toString()
            ).toBe('@foo/**/baz {}'));

          it('with between', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                paramsInterpolation: 'baz',
                raws: {between: '/**/'},
                nodes: [],
              }).toString()
            ).toBe('@foo baz/**/{}'));
        });

        describe('with after', () => {
          it('with no children', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                raws: {after: '/**/'},
                nodes: [],
              }).toString()
            ).toBe('@foo {/**/}'));

          it('with a child', () =>
            expect(
              new GenericAtRule({
                name: 'foo',
                nodes: [{selector: '.bar'}],
                raws: {after: '/**/'},
              }).toString()
            ).toBe('@foo {\n    .bar {}/**/}'));
        });

        it('with before', () =>
          expect(
            new Root({
              nodes: [
                new GenericAtRule({
                  name: 'foo',
                  raws: {before: '/**/'},
                  nodes: [],
                }),
              ],
            }).toString()
          ).toBe('/**/@foo {}'));
      });
    });
  });

  describe('clone', () => {
    let original: GenericAtRule;
    beforeEach(() => {
      original = scss.parse('@foo bar {.baz {}}').nodes[0] as GenericAtRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: GenericAtRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('nameInterpolation', () =>
          expect(clone).toHaveInterpolation('nameInterpolation', 'foo'));

        it('name', () => expect(clone.name).toBe('foo'));

        it('params', () => expect(clone.params).toBe('bar '));

        it('paramsInterpolation', () =>
          expect(clone).toHaveInterpolation('paramsInterpolation', 'bar '));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));

        it('nodes', () => {
          expect(clone.nodes).toHaveLength(1);
          expect(clone.nodes[0]).toBeInstanceOf(Rule);
          expect(clone.nodes[0]).toHaveProperty('selector', '.baz ');
        });
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of [
          'nameInterpolation',
          'paramsInterpolation',
          'raws',
          'nodes',
        ] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });

      describe('sets parent for', () => {
        it('nodes', () => expect(clone.nodes[0].parent).toBe(clone));
      });
    });

    describe('overrides', () => {
      describe('name', () => {
        describe('defined', () => {
          let clone: GenericAtRule;
          beforeEach(() => {
            clone = original.clone({name: 'qux'});
          });

          it('changes name', () => expect(clone.name).toBe('qux'));

          it('changes nameInterpolation', () =>
            expect(clone).toHaveInterpolation('nameInterpolation', 'qux'));
        });

        describe('undefined', () => {
          let clone: GenericAtRule;
          beforeEach(() => {
            clone = original.clone({name: undefined});
          });

          it('preserves name', () => expect(clone.name).toBe('foo'));

          it('preserves nameInterpolation', () =>
            expect(clone).toHaveInterpolation('nameInterpolation', 'foo'));
        });
      });

      describe('nameInterpolation', () => {
        describe('defined', () => {
          let clone: GenericAtRule;
          beforeEach(() => {
            clone = original.clone({
              nameInterpolation: new Interpolation({nodes: ['qux']}),
            });
          });

          it('changes name', () => expect(clone.name).toBe('qux'));

          it('changes nameInterpolation', () =>
            expect(clone).toHaveInterpolation('nameInterpolation', 'qux'));
        });

        describe('undefined', () => {
          let clone: GenericAtRule;
          beforeEach(() => {
            clone = original.clone({nameInterpolation: undefined});
          });

          it('preserves name', () => expect(clone.name).toBe('foo'));

          it('preserves nameInterpolation', () =>
            expect(clone).toHaveInterpolation('nameInterpolation', 'foo'));
        });
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {afterName: '  '}}).raws).toEqual({
            afterName: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            between: '  ',
          }));
      });

      describe('params', () => {
        describe('defined', () => {
          let clone: GenericAtRule;
          beforeEach(() => {
            clone = original.clone({params: 'qux'});
          });

          it('changes params', () => expect(clone.params).toBe('qux'));

          it('changes paramsInterpolation', () =>
            expect(clone).toHaveInterpolation('paramsInterpolation', 'qux'));
        });

        describe('undefined', () => {
          let clone: GenericAtRule;
          beforeEach(() => {
            clone = original.clone({params: undefined});
          });

          it('changes params', () => expect(clone.params).toBe(''));

          it('changes paramsInterpolation', () =>
            expect(clone.paramsInterpolation).toBeUndefined());
        });
      });

      describe('paramsInterpolation', () => {
        describe('defined', () => {
          let clone: GenericAtRule;
          let interpolation: Interpolation;
          beforeEach(() => {
            interpolation = new Interpolation({nodes: ['qux']});
            clone = original.clone({paramsInterpolation: interpolation});
          });

          it('changes params', () => expect(clone.params).toBe('qux'));

          it('changes paramsInterpolation', () =>
            expect(clone).toHaveInterpolation('paramsInterpolation', 'qux'));
        });

        describe('undefined', () => {
          let clone: GenericAtRule;
          beforeEach(() => {
            clone = original.clone({paramsInterpolation: undefined});
          });

          it('changes params', () => expect(clone.params).toBe(''));

          it('changes paramsInterpolation', () =>
            expect(clone.paramsInterpolation).toBeUndefined());
        });
      });
    });
  });

  describe('toJSON', () => {
    it('without params', () =>
      expect(scss.parse('@foo').nodes[0]).toMatchSnapshot());

    it('with params', () =>
      expect(scss.parse('@foo bar').nodes[0]).toMatchSnapshot());

    it('with empty children', () =>
      expect(scss.parse('@foo {}').nodes[0]).toMatchSnapshot());

    it('with a child', () =>
      expect(scss.parse('@foo {@bar}').nodes[0]).toMatchSnapshot());
  });
});
