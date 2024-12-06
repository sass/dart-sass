// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {GenericAtRule, MixinRule, ParameterList, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a @mixin rule', () => {
  let node: MixinRule;
  describe('with empty children', () => {
    function describeNode(description: string, create: () => MixinRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('mixin'));

        it('has a mixin name', () =>
          expect(node.mixinName.toString()).toBe('foo'));

        it('has a parameter', () =>
          expect(node.parameters.nodes[0].name).toEqual('bar'));

        it('has matching params', () => expect(node.params).toBe('foo($bar)'));

        it('has empty nodes', () => expect(node.nodes).toEqual([]));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@mixin foo($bar) {}').nodes[0] as MixinRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@mixin foo($bar)').nodes[0] as MixinRule,
    );

    describeNode(
      'constructed manually',
      () => new MixinRule({mixinName: 'foo', parameters: ['bar']}),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({mixinName: 'foo', parameters: ['bar']}),
    );
  });

  describe('with a child', () => {
    function describeNode(description: string, create: () => MixinRule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('mixin'));

        it('has a mixin name', () =>
          expect(node.mixinName.toString()).toBe('foo'));

        it('has a parameter', () =>
          expect(node.parameters.nodes[0].name).toEqual('bar'));

        it('has matching params', () => expect(node.params).toBe('foo($bar)'));

        it('has a child node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0]).toBeInstanceOf(GenericAtRule);
          expect(node.nodes[0]).toHaveInterpolation('nameInterpolation', 'baz');
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@mixin foo($bar) {@baz}').nodes[0] as MixinRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@mixin foo($bar)\n  @baz').nodes[0] as MixinRule,
    );

    describeNode(
      'constructed manually',
      () =>
        new MixinRule({
          mixinName: 'foo',
          parameters: ['bar'],
          nodes: [{nameInterpolation: 'baz'}],
        }),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({
        mixinName: 'foo',
        parameters: ['bar'],
        nodes: [{nameInterpolation: 'baz'}],
      }),
    );
  });

  describe('throws an error when assigned a new', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@mixin foo($bar) {}').nodes[0] as MixinRule),
    );

    it('name', () => expect(() => (node.name = 'qux')).toThrow());

    it('params', () => expect(() => (node.params = 'zip($zap)')).toThrow());
  });

  describe('assigned new parameters', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@mixin foo($bar) {}').nodes[0] as MixinRule),
    );

    it("removes the old parameters' parent", () => {
      const oldParameters = node.parameters;
      node.parameters = ['qux'];
      expect(oldParameters.parent).toBeUndefined();
    });

    it("assigns the new parameters' parent", () => {
      const parameters = new ParameterList(['qux']);
      node.parameters = parameters;
      expect(parameters.parent).toBe(node);
    });

    it('assigns the parameters explicitly', () => {
      const parameters = new ParameterList(['qux']);
      node.parameters = parameters;
      expect(node.parameters).toBe(parameters);
    });

    it('assigns the expression as ParametersProps', () => {
      node.parameters = ['qux'];
      expect(node.parameters.nodes[0].name).toBe('qux');
      expect(node.parameters.parent).toBe(node);
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(
          new MixinRule({
            mixinName: 'foo',
            parameters: ['bar'],
          }).toString(),
        ).toBe('@mixin foo($bar) {}'));

      it('with a non-identifier name', () =>
        expect(
          new MixinRule({
            mixinName: 'f o',
            parameters: ['bar'],
          }).toString(),
        ).toBe('@mixin f\\20o($bar) {}'));

      it('with afterName', () =>
        expect(
          new MixinRule({
            mixinName: 'foo',
            parameters: ['bar'],
            raws: {afterName: '/**/'},
          }).toString(),
        ).toBe('@mixin/**/foo($bar) {}'));

      it('with matching mixinName', () =>
        expect(
          new MixinRule({
            mixinName: 'foo',
            parameters: ['bar'],
            raws: {mixinName: {value: 'foo', raw: 'f\\6fo'}},
          }).toString(),
        ).toBe('@mixin f\\6fo($bar) {}'));

      it('with non-matching mixinName', () =>
        expect(
          new MixinRule({
            mixinName: 'foo',
            parameters: ['bar'],
            raws: {mixinName: {value: 'fao', raw: 'f\\41o'}},
          }).toString(),
        ).toBe('@mixin foo($bar) {}'));
    });
  });

  describe('clone', () => {
    let original: MixinRule;
    beforeEach(() => {
      original = scss.parse('@mixin foo($bar) {}').nodes[0] as MixinRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: MixinRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('foo($bar)'));

        it('mixinName', () => expect(clone.mixinName).toBe('foo'));

        it('parameters', () => {
          expect(clone.parameters.nodes[0].name).toBe('bar');
          expect(clone.parameters.parent).toBe(clone);
        });

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['parameters', 'raws'] as const) {
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

      describe('mixinName', () => {
        describe('defined', () => {
          let clone: MixinRule;
          beforeEach(() => {
            clone = original.clone({mixinName: 'baz'});
          });

          it('changes params', () => expect(clone.params).toBe('baz($bar)'));

          it('changes mixinName', () => expect(clone.mixinName).toEqual('baz'));
        });

        describe('undefined', () => {
          let clone: MixinRule;
          beforeEach(() => {
            clone = original.clone({mixinName: undefined});
          });

          it('preserves params', () => expect(clone.params).toBe('foo($bar)'));

          it('preserves mixinName', () =>
            expect(clone.mixinName).toEqual('foo'));
        });
      });

      describe('parameters', () => {
        describe('defined', () => {
          let clone: MixinRule;
          beforeEach(() => {
            clone = original.clone({parameters: ['baz']});
          });

          it('changes params', () => expect(clone.params).toBe('foo($baz)'));

          it('changes parameters', () => {
            expect(clone.parameters.nodes[0].name).toBe('baz');
            expect(clone.parameters.parent).toBe(clone);
          });
        });

        describe('undefined', () => {
          let clone: MixinRule;
          beforeEach(() => {
            clone = original.clone({parameters: undefined});
          });

          it('preserves params', () => expect(clone.params).toBe('foo($bar)'));

          it('preserves parameters', () =>
            expect(clone.parameters.nodes[0].name).toBe('bar'));
        });
      });
    });
  });

  it('toJSON', () =>
    expect(scss.parse('@mixin foo($bar) {}').nodes[0]).toMatchSnapshot());
});
