// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {GenericAtRule, Root, css, sass, scss} from '../..';

describe('a root node', () => {
  let node: Root;
  describe('with no children', () => {
    function describeNode(description: string, create: () => Root): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has type root', () => expect(node.type).toBe('root'));

        it('has sassType root', () => expect(node.sassType).toBe('root'));

        it('has no child nodes', () => expect(node.nodes).toHaveLength(0));
      });
    }

    describeNode('parsed as SCSS', () => scss.parse(''));
    describeNode('parsed as CSS', () => css.parse(''));
    describeNode('parsed as Sass', () => sass.parse(''));
    describeNode('constructed manually', () => new Root());
  });

  describe('with children', () => {
    function describeNode(description: string, create: () => Root): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has type root', () => expect(node.type).toBe('root'));

        it('has sassType root', () => expect(node.sassType).toBe('root'));

        it('has a child node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0]).toBeInstanceOf(GenericAtRule);
          expect(node.nodes[0]).toHaveProperty('name', 'foo');
        });
      });
    }

    describeNode('parsed as SCSS', () => scss.parse('@foo'));
    describeNode('parsed as CSS', () => css.parse('@foo'));
    describeNode('parsed as Sass', () => sass.parse('@foo'));

    describeNode(
      'constructed manually',
      () => new Root({nodes: [{name: 'foo'}]})
    );
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with no children', () => expect(new Root().toString()).toBe(''));

        it('with a child', () =>
          expect(new Root({nodes: [{name: 'foo'}]}).toString()).toBe('@foo'));
      });

      describe('with after', () => {
        it('with no children', () =>
          expect(new Root({raws: {after: '/**/'}}).toString()).toBe('/**/'));

        it('with a child', () =>
          expect(
            new Root({
              nodes: [{name: 'foo'}],
              raws: {after: '/**/'},
            }).toString()
          ).toBe('@foo/**/'));
      });

      describe('with semicolon', () => {
        it('with no children', () =>
          expect(new Root({raws: {semicolon: true}}).toString()).toBe(''));

        it('with a child', () =>
          expect(
            new Root({
              nodes: [{name: 'foo'}],
              raws: {semicolon: true},
            }).toString()
          ).toBe('@foo;'));
      });
    });
  });

  describe('clone', () => {
    let original: Root;
    beforeEach(() => {
      original = scss.parse('@foo');
      // TODO: remove this once raws are properly parsed
      original.raws.after = '  ';
    });

    describe('with no overrides', () => {
      let clone: Root;
      beforeEach(() => {
        clone = original.clone();
      });

      describe('has the same properties:', () => {
        it('raws', () => expect(clone.raws).toEqual({after: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));

        it('nodes', () => {
          expect(clone.nodes).toHaveLength(1);
          expect(clone.nodes[0]).toBeInstanceOf(GenericAtRule);
          expect((clone.nodes[0] as GenericAtRule).name).toBe('foo');
        });
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['raws', 'nodes'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });

      describe('sets parent for', () => {
        it('nodes', () => expect(clone.nodes[0].parent).toBe(clone));
      });
    });

    describe('overrides', () => {
      it('nodes', () => {
        const nodes = original.clone({nodes: [{name: 'bar'}]}).nodes;
        expect(nodes).toHaveLength(1);
        expect(nodes[0]).toBeInstanceOf(GenericAtRule);
        expect(nodes[0]).toHaveProperty('name', 'bar');
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {semicolon: true}}).raws).toEqual({
            semicolon: true,
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            after: '  ',
          }));
      });
    });
  });

  describe('toJSON', () => {
    it('without children', () => expect(scss.parse('')).toMatchSnapshot());

    it('with children', () =>
      expect(scss.parse('@foo').nodes[0]).toMatchSnapshot());
  });
});
