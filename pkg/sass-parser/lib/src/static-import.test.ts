// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {ImportList, ImportRule, StaticImport, sass, scss} from '..';

describe('a static import', () => {
  let node: StaticImport;
  beforeEach(() => void (node = new StaticImport({staticUrl: 'foo'})));

  describe('with no modifiers', () => {
    function describeNode(
      description: string,
      create: () => StaticImport,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('static-import'));

        it('has a url', () =>
          expect(node).toHaveInterpolation('staticUrl', '"foo.css"'));

        it('has no modifiers', () => expect(node.modifiers).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@import "foo.css"').nodes[0] as ImportRule).imports
          .nodes[0] as StaticImport,
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@import "foo.css"').nodes[0] as ImportRule).imports
          .nodes[0] as StaticImport,
    );

    describe('constructed manually', () => {
      describeNode('with a string', () => new StaticImport('"foo.css"'));

      describeNode(
        'with an object',
        () => new StaticImport({staticUrl: '"foo.css"'}),
      );
    });

    describeNode(
      'constructed from properties',
      () =>
        new ImportList({nodes: [{staticUrl: '"foo.css"'}]})
          .nodes[0] as StaticImport,
    );
  });

  describe('with modifiers', () => {
    function describeNode(
      description: string,
      create: () => StaticImport,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('static-import'));

        it('has a url', () =>
          expect(node).toHaveInterpolation('staticUrl', '"foo.css"'));

        it('has modifiers', () =>
          expect(node).toHaveInterpolation('modifiers', 'screen'));
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@import "foo.css" screen').nodes[0] as ImportRule).imports
          .nodes[0] as StaticImport,
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@import "foo.css" screen').nodes[0] as ImportRule).imports
          .nodes[0] as StaticImport,
    );

    describeNode(
      'constructed manually',
      () => new StaticImport({staticUrl: '"foo.css"', modifiers: 'screen'}),
    );

    describeNode(
      'constructed from properties',
      () =>
        new ImportList({nodes: [{staticUrl: '"foo.css"', modifiers: 'screen'}]})
          .nodes[0] as StaticImport,
    );
  });

  // TODO: test `@import url("foo")` when the expression-level syntax is
  // representable.

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('without modifiers', () =>
          expect(new StaticImport('"foo.css"').toString()).toBe('"foo.css"'));

        // TODO: test `@import url("foo")` when the expression-level syntax is
        // representable.

        it('with modifiers', () =>
          expect(
            new StaticImport({
              staticUrl: '"foo.css"',
              modifiers: 'screen',
            }).toString(),
          ).toBe('"foo.css" screen'));
      });

      // raws.before is only used as part of a ImportList
      it('ignores before', () =>
        expect(
          new StaticImport({
            staticUrl: '"foo.css"',
            raws: {before: '/**/'},
          }).toString(),
        ).toBe('"foo.css"'));

      // raws.after is only used as part of a ImportList
      it('ignores after', () =>
        expect(
          new StaticImport({
            staticUrl: '"foo.css"',
            raws: {after: '/**/'},
          }).toString(),
        ).toBe('"foo.css"'));

      describe('with between', () => {
        it('without modifiers', () =>
          expect(
            new StaticImport({
              staticUrl: '"foo.css"',
              raws: {between: '/**/'},
            }).toString(),
          ).toBe('"foo.css"'));

        it('with modifiers', () =>
          expect(
            new StaticImport({
              staticUrl: '"foo.css"',
              modifiers: 'screen',
              raws: {between: '/**/'},
            }).toString(),
          ).toBe('"foo.css"/**/screen'));
      });
    });
  });

  describe('clone()', () => {
    let original: StaticImport;
    beforeEach(() => {
      original = (scss.parse('@import "foo.css" screen').nodes[0] as ImportRule)
        .imports.nodes[0] as StaticImport;
      original.raws.before = '/**/';
    });

    describe('with no overrides', () => {
      let clone: StaticImport;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('staticUrl', () =>
          expect(clone).toHaveInterpolation('staticUrl', '"foo.css"'));

        it('modifiers', () =>
          expect(clone).toHaveInterpolation('modifiers', 'screen'));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['raws', 'staticUrl', 'modifiers'] as const) {
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

      describe('staticUrl', () => {
        it('defined', () =>
          expect(original.clone({staticUrl: '"bar.css"'})).toHaveInterpolation(
            'staticUrl',
            '"bar.css"',
          ));

        it('undefined', () =>
          expect(original.clone({staticUrl: undefined})).toHaveInterpolation(
            'staticUrl',
            '"foo.css"',
          ));
      });

      describe('modifiers', () => {
        it('defined', () =>
          expect(original.clone({modifiers: 'print'})).toHaveInterpolation(
            'modifiers',
            'print',
          ));

        it('undefined', () =>
          expect(
            original.clone({modifiers: undefined}).modifiers,
          ).toBeUndefined());
      });
    });
  });

  describe('toJSON', () => {
    it('without modifiers', () =>
      expect(
        (scss.parse('@import "foo.css"').nodes[0] as ImportRule).imports
          .nodes[0],
      ).toMatchSnapshot());

    it('with modifiers', () =>
      expect(
        (scss.parse('@import "foo.css" screen').nodes[0] as ImportRule).imports
          .nodes[0],
      ).toMatchSnapshot());
  });
});
