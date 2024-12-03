// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {FunctionRule, ParameterList, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a @function rule', () => {
  let node: FunctionRule;
  describe('with empty children', () => {
    function describeNode(
      description: string,
      create: () => FunctionRule,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a name', () => expect(node.name.toString()).toBe('function'));

        it('has a function name', () =>
          expect(node.functionName.toString()).toBe('foo'));

        it('has a parameter', () =>
          expect(node.parameters.nodes[0].name).toEqual('bar'));

        it('has matching params', () => expect(node.params).toBe('foo($bar)'));

        it('has empty nodes', () => expect(node.nodes).toEqual([]));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('@function foo($bar) {}').nodes[0] as FunctionRule,
    );

    describeNode(
      'parsed as Sass',
      () => sass.parse('@function foo($bar)').nodes[0] as FunctionRule,
    );

    describeNode(
      'constructed manually',
      () => new FunctionRule({functionName: 'foo', parameters: ['bar']}),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({functionName: 'foo', parameters: ['bar']}),
    );
  });

  // TODO(nweiz): Enable this when we parse ReturnRule.
  //
  // describe('with a child', () => {
  //   function describeNode(description: string, create: () => FunctionRule): void {
  //     describe(description, () => {
  //       beforeEach(() => void (node = create()));
  //
  //       it('has a name', () => expect(node.name.toString()).toBe('function'));
  //
  //       it('has a function name', () => expect(node.functionName.toString()).toBe('foo'));
  //
  //       it('has a parameter', () =>
  //         expect(node.parameters.nodes[0].name).toEqual('bar'));
  //
  //       it('has matching params', () =>
  //         expect(node.params).toBe('foo($bar)'));
  //
  //       it('has a child node', () => {
  //         expect(node.nodes).toHaveLength(1);
  //         expect(node.nodes[0]).toBeInstanceOf(ReturnRule);
  //         expect(node.nodes[0]).toHaveStringExpression('returnExpression', 'baz');
  //       });
  //     });
  //   }
  //
  //   describeNode(
  //     'parsed as SCSS',
  //     () => scss.parse('@function foo($bar) {@return "baz"}').nodes[0] as FunctionRule,
  //   );
  //
  //   describeNode(
  //     'parsed as Sass',
  //     () =>
  //       sass.parse('@function foo($bar)\n  @return "baz"').nodes[0] as FunctionRule,
  //   );
  //
  //   describeNode(
  //     'constructed manually',
  //     () =>
  //       new FunctionRule({
  //         name: 'foo',
  //         parameters: ['bar'],
  //         nodes: [{returnExpression: 'child'}],
  //       }),
  //   );
  //
  //   describeNode('constructed from ChildProps', () =>
  //     utils.fromChildProps({
  //         name: 'foo',
  //         parameters: ['bar'],
  //         nodes: [{returnExpression: 'child'}],
  //       }),
  //   );
  // });

  describe('throws an error when assigned a new', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@function foo($bar) {}')
          .nodes[0] as FunctionRule),
    );

    it('name', () => expect(() => (node.name = 'qux')).toThrow());

    it('params', () => expect(() => (node.params = 'zip($zap)')).toThrow());
  });

  describe('assigned new parameters', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@function foo($bar) {}')
          .nodes[0] as FunctionRule),
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
          new FunctionRule({
            functionName: 'foo',
            parameters: ['bar'],
          }).toString(),
        ).toBe('@function foo($bar) {}'));

      it('with a non-identifier name', () =>
        expect(
          new FunctionRule({
            functionName: 'f o',
            parameters: ['bar'],
          }).toString(),
        ).toBe('@function f\\20o($bar) {}'));

      it('with afterName', () =>
        expect(
          new FunctionRule({
            functionName: 'foo',
            parameters: ['bar'],
            raws: {afterName: '/**/'},
          }).toString(),
        ).toBe('@function/**/foo($bar) {}'));

      it('with matching functionName', () =>
        expect(
          new FunctionRule({
            functionName: 'foo',
            parameters: ['bar'],
            raws: {functionName: {value: 'foo', raw: 'f\\6fo'}},
          }).toString(),
        ).toBe('@function f\\6fo($bar) {}'));

      it('with non-matching functionName', () =>
        expect(
          new FunctionRule({
            functionName: 'foo',
            parameters: ['bar'],
            raws: {functionName: {value: 'fao', raw: 'f\\41o'}},
          }).toString(),
        ).toBe('@function foo($bar) {}'));
    });
  });

  describe('clone', () => {
    let original: FunctionRule;
    beforeEach(() => {
      original = scss.parse('@function foo($bar) {}').nodes[0] as FunctionRule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: FunctionRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('foo($bar)'));

        it('functionName', () => expect(clone.functionName).toBe('foo'));

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

      describe('functionName', () => {
        describe('defined', () => {
          let clone: FunctionRule;
          beforeEach(() => {
            clone = original.clone({functionName: 'baz'});
          });

          it('changes params', () => expect(clone.params).toBe('baz($bar)'));

          it('changes functionName', () =>
            expect(clone.functionName).toEqual('baz'));
        });

        describe('undefined', () => {
          let clone: FunctionRule;
          beforeEach(() => {
            clone = original.clone({functionName: undefined});
          });

          it('preserves params', () => expect(clone.params).toBe('foo($bar)'));

          it('preserves functionName', () =>
            expect(clone.functionName).toEqual('foo'));
        });
      });

      describe('parameters', () => {
        describe('defined', () => {
          let clone: FunctionRule;
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
          let clone: FunctionRule;
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
    expect(scss.parse('@function foo($bar) {}').nodes[0]).toMatchSnapshot());
});
