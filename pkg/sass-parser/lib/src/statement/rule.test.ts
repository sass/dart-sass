// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {GenericAtRule, Interpolation, Root, Rule, css, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a style rule', () => {
  let node: Rule;
  describe('with no children', () => {
    function describeNode(description: string, create: () => Rule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has type rule', () => expect(node.type).toBe('rule'));

        it('has sassType rule', () => expect(node.sassType).toBe('rule'));

        it('has matching selectorInterpolation', () =>
          expect(node).toHaveInterpolation('selectorInterpolation', '.foo '));

        it('has matching selector', () => expect(node.selector).toBe('.foo '));

        it('has empty nodes', () => expect(node.nodes).toHaveLength(0));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('.foo {}').nodes[0] as Rule
    );

    describeNode('parsed as CSS', () => css.parse('.foo {}').nodes[0] as Rule);

    describe('parsed as Sass', () => {
      beforeEach(() => {
        node = sass.parse('.foo').nodes[0] as Rule;
      });

      it('has matching selectorInterpolation', () =>
        expect(node).toHaveInterpolation('selectorInterpolation', '.foo\n'));

      it('has matching selector', () => expect(node.selector).toBe('.foo\n'));

      it('has empty nodes', () => expect(node.nodes).toHaveLength(0));
    });

    describe('constructed manually', () => {
      describeNode(
        'with an interpolation',
        () =>
          new Rule({
            selectorInterpolation: new Interpolation({nodes: ['.foo ']}),
          })
      );

      describeNode(
        'with a selector string',
        () => new Rule({selector: '.foo '})
      );
    });

    describe('constructed from ChildProps', () => {
      describeNode('with an interpolation', () =>
        utils.fromChildProps({
          selectorInterpolation: new Interpolation({nodes: ['.foo ']}),
        })
      );

      describeNode('with a selector string', () =>
        utils.fromChildProps({selector: '.foo '})
      );
    });
  });

  describe('with a child', () => {
    function describeNode(description: string, create: () => Rule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has matching selectorInterpolation', () =>
          expect(node).toHaveInterpolation('selectorInterpolation', '.foo '));

        it('has matching selector', () => expect(node.selector).toBe('.foo '));

        it('has a child node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0]).toBeInstanceOf(GenericAtRule);
          expect(node.nodes[0]).toHaveProperty('name', 'bar');
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('.foo {@bar}').nodes[0] as Rule
    );

    describeNode(
      'parsed as CSS',
      () => css.parse('.foo {@bar}').nodes[0] as Rule
    );

    describe('parsed as Sass', () => {
      beforeEach(() => {
        node = sass.parse('.foo\n  @bar').nodes[0] as Rule;
      });

      it('has matching selectorInterpolation', () =>
        expect(node).toHaveInterpolation('selectorInterpolation', '.foo\n'));

      it('has matching selector', () => expect(node.selector).toBe('.foo\n'));

      it('has a child node', () => {
        expect(node.nodes).toHaveLength(1);
        expect(node.nodes[0]).toBeInstanceOf(GenericAtRule);
        expect(node.nodes[0]).toHaveProperty('name', 'bar');
      });
    });

    describe('constructed manually', () => {
      describeNode(
        'with an interpolation',
        () =>
          new Rule({
            selectorInterpolation: new Interpolation({nodes: ['.foo ']}),
            nodes: [{name: 'bar'}],
          })
      );

      describeNode(
        'with a selector string',
        () => new Rule({selector: '.foo ', nodes: [{name: 'bar'}]})
      );
    });

    describe('constructed from ChildProps', () => {
      describeNode('with an interpolation', () =>
        utils.fromChildProps({
          selectorInterpolation: new Interpolation({nodes: ['.foo ']}),
          nodes: [{name: 'bar'}],
        })
      );

      describeNode('with a selector string', () =>
        utils.fromChildProps({selector: '.foo ', nodes: [{name: 'bar'}]})
      );
    });
  });

  describe('assigned a new selector', () => {
    beforeEach(() => {
      node = scss.parse('.foo {}').nodes[0] as Rule;
    });

    it("removes the old interpolation's parent", () => {
      const oldSelector = node.selectorInterpolation!;
      node.selectorInterpolation = '.bar';
      expect(oldSelector.parent).toBeUndefined();
    });

    it("assigns the new interpolation's parent", () => {
      const interpolation = new Interpolation({nodes: ['.bar']});
      node.selectorInterpolation = interpolation;
      expect(interpolation.parent).toBe(node);
    });

    it('assigns the interpolation explicitly', () => {
      const interpolation = new Interpolation({nodes: ['.bar']});
      node.selectorInterpolation = interpolation;
      expect(node.selectorInterpolation).toBe(interpolation);
    });

    it('assigns the interpolation as a string', () => {
      node.selectorInterpolation = '.bar';
      expect(node).toHaveInterpolation('selectorInterpolation', '.bar');
    });

    it('assigns the interpolation as selector', () => {
      node.selector = '.bar';
      expect(node).toHaveInterpolation('selectorInterpolation', '.bar');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with no children', () =>
          expect(new Rule({selector: '.foo'}).toString()).toBe('.foo {}'));

        it('with a child', () =>
          expect(
            new Rule({selector: '.foo', nodes: [{selector: '.bar'}]}).toString()
          ).toBe('.foo {\n    .bar {}\n}'));
      });

      it('with between', () =>
        expect(
          new Rule({
            selector: '.foo',
            raws: {between: '/**/'},
          }).toString()
        ).toBe('.foo/**/{}'));

      describe('with after', () => {
        it('with no children', () =>
          expect(
            new Rule({selector: '.foo', raws: {after: '/**/'}}).toString()
          ).toBe('.foo {/**/}'));

        it('with a child', () =>
          expect(
            new Rule({
              selector: '.foo',
              nodes: [{selector: '.bar'}],
              raws: {after: '/**/'},
            }).toString()
          ).toBe('.foo {\n    .bar {}/**/}'));
      });

      it('with before', () =>
        expect(
          new Root({
            nodes: [new Rule({selector: '.foo', raws: {before: '/**/'}})],
          }).toString()
        ).toBe('/**/.foo {}'));
    });
  });

  describe('clone', () => {
    let original: Rule;
    beforeEach(() => {
      original = scss.parse('.foo {@bar}').nodes[0] as Rule;
      // TODO: remove this once raws are properly parsed
      original.raws.between = '  ';
    });

    describe('with no overrides', () => {
      let clone: Rule;
      beforeEach(() => {
        clone = original.clone();
      });

      describe('has the same properties:', () => {
        it('selectorInterpolation', () =>
          expect(clone).toHaveInterpolation('selectorInterpolation', '.foo '));

        it('selector', () => expect(clone.selector).toBe('.foo '));

        it('raws', () => expect(clone.raws).toEqual({between: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));

        it('nodes', () => {
          expect(clone.nodes).toHaveLength(1);
          expect(clone.nodes[0]).toBeInstanceOf(GenericAtRule);
          expect(clone.nodes[0]).toHaveProperty('name', 'bar');
        });
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of [
          'selectorInterpolation',
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
      describe('selector', () => {
        describe('defined', () => {
          let clone: Rule;
          beforeEach(() => {
            clone = original.clone({selector: 'qux'});
          });

          it('changes selector', () => expect(clone.selector).toBe('qux'));

          it('changes selectorInterpolation', () =>
            expect(clone).toHaveInterpolation('selectorInterpolation', 'qux'));
        });

        describe('undefined', () => {
          let clone: Rule;
          beforeEach(() => {
            clone = original.clone({selector: undefined});
          });

          it('preserves selector', () => expect(clone.selector).toBe('.foo '));

          it('preserves selectorInterpolation', () =>
            expect(clone).toHaveInterpolation(
              'selectorInterpolation',
              '.foo '
            ));
        });
      });

      describe('selectorInterpolation', () => {
        describe('defined', () => {
          let clone: Rule;
          beforeEach(() => {
            clone = original.clone({
              selectorInterpolation: new Interpolation({nodes: ['.baz']}),
            });
          });

          it('changes selector', () => expect(clone.selector).toBe('.baz'));

          it('changes selectorInterpolation', () =>
            expect(clone).toHaveInterpolation('selectorInterpolation', '.baz'));
        });

        describe('undefined', () => {
          let clone: Rule;
          beforeEach(() => {
            clone = original.clone({selectorInterpolation: undefined});
          });

          it('preserves selector', () => expect(clone.selector).toBe('.foo '));

          it('preserves selectorInterpolation', () =>
            expect(clone).toHaveInterpolation(
              'selectorInterpolation',
              '.foo '
            ));
        });
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {before: '  '}}).raws).toEqual({
            before: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            between: '  ',
          }));
      });
    });
  });

  describe('toJSON', () => {
    it('with empty children', () =>
      expect(scss.parse('.foo {}').nodes[0]).toMatchSnapshot());

    it('with a child', () =>
      expect(scss.parse('.foo {@bar}').nodes[0]).toMatchSnapshot());
  });
});
