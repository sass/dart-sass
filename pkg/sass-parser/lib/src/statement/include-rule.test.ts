// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  ArgumentList,
  GenericAtRule,
  IncludeRule,
  ParameterList,
  sass,
  scss,
} from '../..';
import * as utils from '../../../test/utils';

describe('a @include rule', () => {
  let node: IncludeRule;
  describe('with no block', () => {
    function describeNode(
      description: string,
      create: () => IncludeRule,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () => expect(node.sassType).toBe('include-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('include'));

        it('has an include name', () =>
          expect(node.includeName.toString()).toBe('foo'));

        it('has an argument', () =>
          expect(node.arguments.nodes[0]).toHaveStringExpression(
            'value',
            'bar',
          ));

        it('has no using', () => expect(node.using).toBe(undefined));

        it('has matching params', () => expect(node.params).toBe('foo(bar)'));

        it('has no nodes', () => expect(node.nodes).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@include foo(bar)').nodes[0] as IncludeRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@include foo(bar)').nodes[0] as IncludeRule,
    );

    describeNode(
      'constructed manually',
      () => new IncludeRule({includeName: 'foo', arguments: [{text: 'bar'}]}),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({includeName: 'foo', arguments: [{text: 'bar'}]}),
    );
  });

  describe('with a child', () => {
    function describeNode(
      description: string,
      create: () => IncludeRule,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () => expect(node.sassType).toBe('include-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('include'));

        it('has a include name', () =>
          expect(node.includeName.toString()).toBe('foo'));

        it('has an argument', () =>
          expect(node.arguments.nodes[0]).toHaveStringExpression(
            'value',
            'bar',
          ));

        it('has no using', () => expect(node.using).toBe(undefined));

        it('has matching params', () => expect(node.params).toBe('foo(bar)'));

        it('has a child node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes![0]).toBeInstanceOf(GenericAtRule);
          expect(node.nodes![0]).toHaveInterpolation(
            'nameInterpolation',
            'baz',
          );
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@include foo(bar) {@baz}').nodes[0] as IncludeRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@include foo(bar)\n  @baz').nodes[0] as IncludeRule,
    );

    describeNode(
      'constructed manually',
      () =>
        new IncludeRule({
          includeName: 'foo',
          arguments: [{text: 'bar'}],
          nodes: [{name: 'baz'}],
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        includeName: 'foo',
        arguments: [{text: 'bar'}],
        nodes: [{name: 'baz'}],
      }),
    );
  });

  describe('with using', () => {
    function describeNode(
      description: string,
      create: () => IncludeRule,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () => expect(node.sassType).toBe('include-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('include'));

        it('has a include name', () =>
          expect(node.includeName.toString()).toBe('foo'));

        it('has an argument', () =>
          expect(node.arguments.nodes[0]).toHaveStringExpression(
            'value',
            'bar',
          ));

        it('has a using parameter', () =>
          expect(node.using!.nodes[0].name).toBe('baz'));

        it('has matching params', () =>
          expect(node.params).toBe('foo(bar) using ($baz)'));

        it('has a child node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes![0]).toBeInstanceOf(GenericAtRule);
          expect(node.nodes![0]).toHaveInterpolation(
            'nameInterpolation',
            'qux',
          );
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        scss.parse('@include foo(bar) using ($baz) {@qux}')
          .nodes[0] as IncludeRule,
    );

    describeNode(
      'parsed as Sass',
      () =>
        sass.parse('@include foo(bar) using ($baz)\n  @qux')
          .nodes[0] as IncludeRule,
    );

    describeNode(
      'constructed manually',
      () =>
        new IncludeRule({
          includeName: 'foo',
          arguments: [{text: 'bar'}],
          using: ['baz'],
          nodes: [{name: 'qux'}],
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        includeName: 'foo',
        arguments: [{text: 'bar'}],
        using: ['baz'],
        nodes: [{name: 'qux'}],
      }),
    );
  });

  describe('throws an error when assigned a new', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@include foo(bar)').nodes[0] as IncludeRule),
    );

    it('name', () => expect(() => (node.name = 'qux')).toThrow());

    it('params', () => expect(() => (node.params = 'zip(zap)')).toThrow());
  });

  describe('assigned new arguments', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@include foo(bar)').nodes[0] as IncludeRule),
    );

    it("removes the old arguments' parent", () => {
      const oldArguments = node.arguments;
      node.arguments = [{text: 'qux'}];
      expect(oldArguments.parent).toBeUndefined();
    });

    it("assigns the new arguments' parent", () => {
      const args = new ArgumentList([{text: 'qux'}]);
      node.arguments = args;
      expect(args.parent).toBe(node);
    });

    it('assigns the arguments explicitly', () => {
      const args = new ArgumentList([{text: 'qux'}]);
      node.arguments = args;
      expect(node.arguments).toBe(args);
    });

    it('assigns the expression as ArgumentProps', () => {
      node.arguments = [{text: 'qux'}];
      expect(node.arguments.nodes[0]).toHaveStringExpression('value', 'qux');
      expect(node.arguments.parent).toBe(node);
    });
  });

  describe('assigned new using', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@include foo(bar) using ($baz) {}')
          .nodes[0] as IncludeRule),
    );

    it("removes the old using' parent", () => {
      const oldUsing = node.using!;
      node.using = ['qux'];
      expect(oldUsing.parent).toBeUndefined();
    });

    it("assigns the new using' parent", () => {
      const using = new ParameterList(['qux']);
      node.using = using;
      expect(using.parent).toBe(node);
    });

    it('assigns the using explicitly', () => {
      const using = new ParameterList(['qux']);
      node.using = using;
      expect(node.using).toBe(using);
    });

    it('assigns the expression as ParameterProps', () => {
      node.using = ['qux'];
      expect(node.using!.nodes[0].name).toBe('qux');
      expect(node.using!.parent).toBe(node);
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with no arguments', () =>
          expect(new IncludeRule({includeName: 'foo'}).toString()).toBe(
            '@include foo;',
          ));

        it('with an argument', () =>
          expect(
            new IncludeRule({
              includeName: 'foo',
              arguments: [{text: 'bar'}],
            }).toString(),
          ).toBe('@include foo(bar);'));

        it('with empty using', () =>
          expect(
            new IncludeRule({
              includeName: 'foo',
              using: [],
              nodes: [],
            }).toString(),
          ).toBe('@include foo using () {}'));

        it('with a using parameter', () =>
          expect(
            new IncludeRule({
              includeName: 'foo',
              using: ['bar'],
              nodes: [],
            }).toString(),
          ).toBe('@include foo using ($bar) {}'));

        it('with a non-identifier name', () =>
          expect(
            new IncludeRule({
              includeName: 'f o',
              arguments: [{text: 'bar'}],
            }).toString(),
          ).toBe('@include f\\20o(bar);'));
      });

      it('with afterName', () =>
        expect(
          new IncludeRule({
            includeName: 'foo',
            raws: {afterName: '/**/'},
          }).toString(),
        ).toBe('@include/**/foo;'));

      it('with matching includeName', () =>
        expect(
          new IncludeRule({
            includeName: 'foo',
            raws: {includeName: {value: 'foo', raw: 'f\\6fo'}},
          }).toString(),
        ).toBe('@include f\\6fo;'));

      it('with non-matching includeName', () =>
        expect(
          new IncludeRule({
            includeName: 'foo',
            raws: {includeName: {value: 'fao', raw: 'f\\41o'}},
          }).toString(),
        ).toBe('@include foo;'));

      it('with showArguments = true', () =>
        expect(
          new IncludeRule({
            includeName: 'foo',
            raws: {showArguments: true},
          }).toString(),
        ).toBe('@include foo();'));

      it('ignores showArguments with an argument', () =>
        expect(
          new IncludeRule({
            includeName: 'foo',
            arguments: [{text: 'bar'}],
            raws: {showArguments: true},
          }).toString(),
        ).toBe('@include foo(bar);'));

      describe('with afterArguments', () => {
        it('with no using', () =>
          expect(
            new IncludeRule({
              includeName: 'foo',
              arguments: [{text: 'bar'}],
              raws: {afterArguments: '/**/'},
            }).toString(),
          ).toBe('@include foo(bar);'));

        it('with using', () =>
          expect(
            new IncludeRule({
              includeName: 'foo',
              arguments: [{text: 'bar'}],
              using: ['baz'],
              nodes: [],
              raws: {afterArguments: '/**/'},
            }).toString(),
          ).toBe('@include foo(bar)/**/using ($baz) {}'));

        it('with no arguments', () =>
          expect(
            new IncludeRule({
              includeName: 'foo',
              using: ['baz'],
              raws: {afterArguments: '/**/'},
            }).toString(),
          ).toBe('@include foo/**/using ($baz);'));
      });

      describe('with afterUsing', () => {
        it('with no using', () =>
          expect(
            new IncludeRule({
              includeName: 'foo',
              arguments: [{text: 'bar'}],
              raws: {afterUsing: '/**/'},
            }).toString(),
          ).toBe('@include foo(bar);'));

        it('with using', () =>
          expect(
            new IncludeRule({
              includeName: 'foo',
              using: ['baz'],
              raws: {afterUsing: '/**/'},
            }).toString(),
          ).toBe('@include foo using/**/($baz);'));
      });
    });
  });

  describe('clone', () => {
    let original: IncludeRule;
    beforeEach(() => {
      original = scss.parse('@include foo(bar) using ($baz) {}')
        .nodes[0] as IncludeRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: IncludeRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('foo(bar) using ($baz)'));

        it('includeName', () => expect(clone.includeName).toBe('foo'));

        it('arguments', () => {
          expect(clone.arguments.nodes[0]).toHaveStringExpression(
            'value',
            'bar',
          );
          expect(clone.arguments.parent).toBe(clone);
        });

        it('using', () => {
          expect(clone.using!.nodes[0].name).toBe('baz');
          expect(clone.using!.parent).toBe(clone);
        });

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['arguments', 'using', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
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

      describe('includeName', () => {
        describe('defined', () => {
          let clone: IncludeRule;
          beforeEach(() => {
            clone = original.clone({includeName: 'qux'});
          });

          it('changes params', () =>
            expect(clone.params).toBe('qux(bar) using ($baz)'));

          it('changes includeName', () =>
            expect(clone.includeName).toEqual('qux'));
        });

        describe('undefined', () => {
          let clone: IncludeRule;
          beforeEach(() => {
            clone = original.clone({includeName: undefined});
          });

          it('preserves params', () =>
            expect(clone.params).toBe('foo(bar) using ($baz)'));

          it('preserves includeName', () =>
            expect(clone.includeName).toEqual('foo'));
        });
      });

      describe('arguments', () => {
        describe('defined', () => {
          let clone: IncludeRule;
          beforeEach(() => {
            clone = original.clone({arguments: [{text: 'qux'}]});
          });

          it('changes params', () =>
            expect(clone.params).toBe('foo(qux) using ($baz)'));

          it('changes arguments', () => {
            expect(clone.arguments.nodes[0]).toHaveStringExpression(
              'value',
              'qux',
            );
            expect(clone.arguments.parent).toBe(clone);
          });
        });

        describe('undefined', () => {
          let clone: IncludeRule;
          beforeEach(() => {
            clone = original.clone({arguments: undefined});
          });

          it('preserves params', () =>
            expect(clone.params).toBe('foo(bar) using ($baz)'));

          it('preserves arguments', () =>
            expect(clone.arguments.nodes[0]).toHaveStringExpression(
              'value',
              'bar',
            ));
        });
      });

      describe('using', () => {
        describe('defined', () => {
          let clone: IncludeRule;
          beforeEach(() => {
            clone = original.clone({using: ['qux']});
          });

          it('changes params', () =>
            expect(clone.params).toBe('foo(bar) using ($qux)'));

          it('changes arguments', () => {
            expect(clone.using!.nodes[0].name).toBe('qux');
            expect(clone.using!.parent).toBe(clone);
          });
        });

        describe('undefined', () => {
          let clone: IncludeRule;
          beforeEach(() => {
            clone = original.clone({using: undefined});
          });

          it('changes params', () => expect(clone.params).toBe('foo(bar)'));

          it('changes using', () => expect(clone.using).toBeUndefined());
        });
      });
    });
  });

  describe('toJSON', () => {
    it('with no children', () =>
      expect(scss.parse('@include foo(bar)').nodes[0]).toMatchSnapshot());

    it('with a child', () =>
      expect(
        scss.parse('@include foo(bar) {@qux}').nodes[0],
      ).toMatchSnapshot());

    it('with using and a child', () =>
      expect(
        scss.parse('@include foo(bar) using ($baz) {@qux}').nodes[0],
      ).toMatchSnapshot());
  });
});
