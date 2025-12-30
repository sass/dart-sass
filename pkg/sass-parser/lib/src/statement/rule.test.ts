// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {GenericAtRule, Root, Rule, SelectorList, css, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a style rule', () => {
  let node: Rule;
  describe('with no children', () => {
    function describeNode(description: string, create: () => Rule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has type rule', () => expect(node.type).toBe('rule'));

        it('has sassType rule', () => expect(node.sassType).toBe('rule'));

        it('has matching parsedSelector', () =>
          expect(node).toHaveNode('parsedSelector', '.foo', 'selector-list'));

        it('has matching selector', () => expect(node.selector).toBe('.foo'));

        it('has empty nodes', () => expect(node.nodes).toHaveLength(0));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('.foo {}').nodes[0] as Rule,
    );

    describeNode('parsed as CSS', () => css.parse('.foo {}').nodes[0] as Rule);

    describe('parsed as Sass', () => {
      beforeEach(() => {
        node = sass.parse('.foo\n').nodes[0] as Rule;
      });

      it('has matching parsedSelector', () =>
        expect(node).toHaveNode('parsedSelector', '.foo', 'selector-list'));

      it('has matching selector', () => expect(node.selector).toBe('.foo'));

      it('has empty nodes', () => expect(node.nodes).toHaveLength(0));
    });

    describe('constructed manually', () => {
      describeNode(
        'with a parsed selector',
        () => new Rule({parsedSelector: {class: 'foo'}}),
      );

      describeNode(
        'with a selector string',
        () => new Rule({selector: '.foo'}),
      );
    });

    describe('constructed from ChildProps', () => {
      describeNode('with a parsed selector', () =>
        utils.fromChildProps({parsedSelector: {class: 'foo'}}),
      );

      describeNode('with a selector string', () =>
        utils.fromChildProps({selector: '.foo'}),
      );
    });
  });

  describe('with a child', () => {
    function describeNode(description: string, create: () => Rule): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has matching parsedSelector', () =>
          expect(node).toHaveNode('parsedSelector', '.foo', 'selector-list'));

        it('has matching selector', () => expect(node.selector).toBe('.foo'));

        it('has a child node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0]).toBeInstanceOf(GenericAtRule);
          expect(node.nodes[0]).toHaveProperty('name', 'bar');
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () => scss.parse('.foo {@bar}').nodes[0] as Rule,
    );

    describeNode(
      'parsed as CSS',
      () => css.parse('.foo {@bar}').nodes[0] as Rule,
    );

    describe('parsed as Sass', () => {
      beforeEach(() => {
        node = sass.parse('.foo\n  @bar').nodes[0] as Rule;
      });

      it('has matching parsedSelector', () =>
        expect(node).toHaveNode('parsedSelector', '.foo'));

      it('has matching selector', () => expect(node.selector).toBe('.foo'));

      it('has a child node', () => {
        expect(node.nodes).toHaveLength(1);
        expect(node.nodes[0]).toBeInstanceOf(GenericAtRule);
        expect(node.nodes[0]).toHaveProperty('name', 'bar');
      });
    });

    describe('constructed manually', () => {
      describeNode(
        'with a parsedSelector',
        () =>
          new Rule({
            parsedSelector: {class: 'foo'},
            nodes: [{name: 'bar'}],
          }),
      );

      describeNode(
        'with a selector string',
        () => new Rule({selector: '.foo', nodes: [{name: 'bar'}]}),
      );
    });

    describe('constructed from ChildProps', () => {
      describeNode('with a parsedSelector', () =>
        utils.fromChildProps({
          parsedSelector: {class: 'foo'},
          nodes: [{name: 'bar'}],
        }),
      );

      describeNode('with a selector string', () =>
        utils.fromChildProps({selector: '.foo', nodes: [{name: 'bar'}]}),
      );
    });
  });

  describe('assigned a new selector', () => {
    beforeEach(() => {
      node = scss.parse('.foo {}').nodes[0] as Rule;
    });

    it("removes the old selector's parent", () => {
      const oldSelector = node.parsedSelector!;
      node.parsedSelector = {class: 'bar'};
      expect(oldSelector.parent).toBeUndefined();
    });

    it("assigns the new selector's parent", () => {
      const selector = new SelectorList({class: 'bar'});
      node.parsedSelector = selector;
      expect(selector.parent).toBe(node);
    });

    it('assigns the selector explicitly', () => {
      const selector = new SelectorList({class: 'bar'});
      node.parsedSelector = selector;
      expect(node.parsedSelector).toBe(selector);
    });

    it('assigns the selector as selector', () => {
      node.selector = '.bar';
      expect(node).toHaveNode('parsedSelector', '.bar');
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with no children', () =>
          expect(new Rule({selector: '.foo'}).toString()).toBe('.foo {}'));

        it('with a child', () =>
          expect(
            new Rule({
              selector: '.foo',
              nodes: [{selector: '.bar'}],
            }).toString(),
          ).toBe('.foo {\n    .bar {}\n}'));
      });

      it('with between', () =>
        expect(
          new Rule({
            selector: '.foo',
            raws: {between: '/**/'},
          }).toString(),
        ).toBe('.foo/**/{}'));

      describe('with after', () => {
        it('with no children', () =>
          expect(
            new Rule({selector: '.foo', raws: {after: '/**/'}}).toString(),
          ).toBe('.foo {/**/}'));

        it('with a child', () =>
          expect(
            new Rule({
              selector: '.foo',
              nodes: [{selector: '.bar'}],
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('.foo {\n    .bar {}/**/}'));
      });

      it('with before', () =>
        expect(
          new Root({
            nodes: [new Rule({selector: '.foo', raws: {before: '/**/'}})],
          }).toString(),
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
        it('parsedSelector', () =>
          expect(clone).toHaveNode('parsedSelector', '.foo'));

        it('selector', () => expect(clone.selector).toBe('.foo'));

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

        for (const attr of ['parsedSelector', 'raws', 'nodes'] as const) {
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

          it('changes parsedSelector', () =>
            expect(clone).toHaveNode('parsedSelector', 'qux'));
        });

        describe('undefined', () => {
          let clone: Rule;
          beforeEach(() => {
            clone = original.clone({selector: undefined});
          });

          it('preserves selector', () => expect(clone.selector).toBe('.foo'));

          it('preserves parsedSelector', () =>
            expect(clone).toHaveNode('parsedSelector', '.foo'));
        });
      });

      describe('parsedSelector', () => {
        describe('defined', () => {
          let clone: Rule;
          beforeEach(() => {
            clone = original.clone({
              parsedSelector: {class: 'baz'},
            });
          });

          it('changes selector', () => expect(clone.selector).toBe('.baz'));

          it('changes parsedSelector', () =>
            expect(clone).toHaveNode('parsedSelector', '.baz'));
        });

        describe('undefined', () => {
          let clone: Rule;
          beforeEach(() => {
            clone = original.clone({parsedSelector: undefined});
          });

          it('preserves selector', () => expect(clone.selector).toBe('.foo'));

          it('preserves parsedSelector', () =>
            expect(clone).toHaveNode('parsedSelector', '.foo'));
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
