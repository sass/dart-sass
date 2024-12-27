// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {DynamicImport, ImportList, ImportRule, sass, scss} from '..';

describe('a dynamic import', () => {
  let node: DynamicImport;
  beforeEach(() => void (node = new DynamicImport({url: 'foo'})));

  function describeNode(
    description: string,
    create: () => DynamicImport,
  ): void {
    describe(description, () => {
      beforeEach(() => (node = create()));

      it('has a sassType', () =>
        expect(node.sassType.toString()).toBe('dynamic-import'));

      it('has a url', () => expect(node.url).toBe('foo'));
    });
  }

  describeNode(
    'parsed as SCSS',
    () =>
      (scss.parse('@import "foo"').nodes[0] as ImportRule).imports
        .nodes[0] as DynamicImport,
  );

  describeNode(
    'parsed as Sass',
    () =>
      (sass.parse('@import "foo"').nodes[0] as ImportRule).imports
        .nodes[0] as DynamicImport,
  );

  describe('constructed manually', () => {
    describeNode('with a string', () => new DynamicImport('foo'));

    describeNode('with an object', () => new DynamicImport({url: 'foo'}));
  });

  describe('constructed from properties', () => {
    describeNode(
      'with a string',
      () => new ImportList({nodes: ['foo']}).nodes[0] as DynamicImport,
    );

    describeNode(
      'with an object',
      () => new ImportList({nodes: [{url: 'foo'}]}).nodes[0] as DynamicImport,
    );
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with a simple URL', () =>
          expect(new DynamicImport('foo').toString()).toBe('"foo"'));

        it('with a URL that needs escaping', () =>
          expect(new DynamicImport('\\').toString()).toBe('"\\\\"'));
      });

      // raws.before is only used as part of a ImportList
      it('ignores before', () =>
        expect(
          new DynamicImport({
            url: 'foo',
            raws: {before: '/**/'},
          }).toString(),
        ).toBe('"foo"'));

      // raws.after is only used as part of a ImportList
      it('ignores after', () =>
        expect(
          new DynamicImport({
            url: 'foo',
            raws: {after: '/**/'},
          }).toString(),
        ).toBe('"foo"'));

      it('with matching url', () =>
        expect(
          new DynamicImport({
            url: 'foo',
            raws: {url: {raw: '"f\\6fo"', value: 'foo'}},
          }).toString(),
        ).toBe('"f\\6fo"'));

      it('with non-matching url', () =>
        expect(
          new DynamicImport({
            url: 'foo',
            raws: {url: {raw: '"f\\41o"', value: 'fao'}},
          }).toString(),
        ).toBe('"foo"'));
    });
  });

  describe('clone()', () => {
    let original: DynamicImport;
    beforeEach(() => {
      original = (scss.parse('@import "foo"').nodes[0] as ImportRule).imports
        .nodes[0] as DynamicImport;
      original.raws.before = '/**/';
    });

    describe('with no overrides', () => {
      let clone: DynamicImport;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('url', () => expect(clone.url).toBe('foo'));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {after: '  '}}).raws).toEqual({
            after: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            before: '/**/',
          }));
      });

      describe('url', () => {
        it('defined', () =>
          expect(original.clone({url: 'bar'}).url).toBe('bar'));

        it('undefined', () =>
          expect(original.clone({url: undefined}).url).toBe('foo'));
      });
    });
  });

  it('toJSON', () =>
    expect(
      (scss.parse('@import "foo"').nodes[0] as ImportRule).imports.nodes[0],
    ).toMatchSnapshot());
});
