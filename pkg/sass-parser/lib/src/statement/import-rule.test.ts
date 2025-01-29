// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {ImportRule, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('an @import rule', () => {
  let node: ImportRule;
  function describeNode(description: string, create: () => ImportRule): void {
    describe(description, () => {
      beforeEach(() => (node = create()));

      it('has a type', () => expect(node.type.toString()).toBe('atrule'));

      it('has a sassType', () =>
        expect(node.sassType.toString()).toBe('import-rule'));

      it('has a name', () => expect(node.name.toString()).toBe('import'));

      it('has an import list', () =>
        expect(node.imports.nodes[0]).toHaveProperty('url', 'foo'));

      it('has matching params', () => expect(node.params).toBe('"foo"'));

      it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
    });
  }

  describeNode(
    'parsed as SCSS',
    () => scss.parse('@import "foo"').nodes[0] as ImportRule,
  );

  describeNode(
    'parsed as Sass',
    () => sass.parse('@import "foo"').nodes[0] as ImportRule,
  );

  describeNode(
    'constructed manually',
    () =>
      new ImportRule({
        imports: 'foo',
      }),
  );

  describeNode('constructed from ChildProps', () =>
    utils.fromChildProps({
      imports: 'foo',
    }),
  );

  describe('throws an error when assigned a new', () => {
    beforeEach(() => void (node = new ImportRule({imports: 'foo'})));

    it('name', () => expect(() => (node.name = 'bar')).toThrow());

    it('params', () => expect(() => (node.params = 'bar')).toThrow());
  });

  it('assigned a new import list', () => {
    node = new ImportRule({imports: 'foo'});
    node.imports = 'bar';
    expect(node.imports.nodes[0]).toHaveProperty('url', 'bar');
    expect(node.params).toBe('"bar"');
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(new ImportRule({imports: 'foo'}).toString()).toBe(
          '@import "foo"',
        ));
    });
  });

  describe('clone', () => {
    let original: ImportRule;
    beforeEach(() => {
      original = scss.parse('@import "foo", "bar" screen')
        .nodes[0] as ImportRule;
      // TODO: remove this once raws are properly parsed
      original.raws.afterName = '  ';
    });

    describe('with no overrides', () => {
      let clone: ImportRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('"foo", "bar" screen'));

        it('imports', () => {
          expect(clone.imports.nodes[0]).toHaveProperty('url', 'foo');
          expect(clone.imports.nodes[1]).toHaveInterpolation(
            'staticUrl',
            '"bar"',
          );
        });

        it('raws', () => expect(clone.raws).toEqual({afterName: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['imports', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {before: '  '}}).raws).toEqual({
            before: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            afterName: '  ',
          }));
      });

      describe('imports', () => {
        describe('defined', () => {
          let clone: ImportRule;
          beforeEach(() => {
            clone = original.clone({imports: 'baz'});
          });

          it('changes imports', () =>
            expect(clone.imports.nodes[0]).toHaveProperty('url', 'baz'));

          it('changes params', () => expect(clone.params).toBe('"baz"'));
        });

        describe('undefined', () => {
          let clone: ImportRule;
          beforeEach(() => {
            clone = original.clone({imports: undefined});
          });

          it('preserves imports', () => {
            expect(clone.imports.nodes[0]).toHaveProperty('url', 'foo');
            expect(clone.imports.nodes[1]).toHaveInterpolation(
              'staticUrl',
              '"bar"',
            );
          });

          it('preserves params', () =>
            expect(clone.params).toBe('"foo", "bar" screen'));
        });
      });
    });
  });

  it('toJSON', () =>
    expect(
      scss.parse('@import "foo", "bar" screen').nodes[0],
    ).toMatchSnapshot());
});
