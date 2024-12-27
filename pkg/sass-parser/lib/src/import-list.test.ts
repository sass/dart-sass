// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {DynamicImport, ImportList, ImportRule, sass, scss} from '..';

type EachFn = Parameters<ImportList['each']>[0];

let node: ImportList;
describe('an import list', () => {
  function describeNode(description: string, create: () => ImportList): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has a sassType', () => expect(node.sassType).toBe('import-list'));

      it('has a node', () => {
        expect(node.nodes.length).toBe(1);
        expect(node.nodes[0]).toHaveProperty('url', 'foo');
        expect(node.nodes[0].parent).toBe(node);
      });
    });
  }

  describeNode(
    'parsed as SCSS',
    () => (scss.parse('@import "foo"').nodes[0] as ImportRule).imports,
  );

  describeNode(
    'parsed as Sass',
    () => (sass.parse('@import "foo"').nodes[0] as ImportRule).imports,
  );

  describe('constructed manually', () => {
    describeNode('with a string', () => new ImportList('foo'));

    describe('with an array', () => {
      describeNode(
        'with an Import',
        () => new ImportList([new DynamicImport('foo')]),
      );

      describeNode(
        'with DynamicImportProps',
        () => new ImportList([{url: 'foo'}]),
      );

      describeNode('with a string', () => new ImportList(['foo']));
    });

    describe('with an object', () => {
      describeNode(
        'with an Import',
        () => new ImportList({nodes: [new DynamicImport('foo')]}),
      );

      describeNode(
        'with DynamicImportProps',
        () => new ImportList({nodes: [{url: 'foo'}]}),
      );

      describeNode('with a string', () => new ImportList({nodes: ['foo']}));
    });
  });

  describe('constructed from properties', () => {
    describeNode(
      'an object',
      () =>
        new ImportRule({
          imports: {nodes: [{url: 'foo'}]},
        }).imports,
    );

    describeNode(
      'an array',
      () => new ImportRule({imports: [{url: 'foo'}]}).imports,
    );

    describeNode('a string', () => new ImportRule({imports: 'foo'}).imports);
  });

  describe('can add', () => {
    beforeEach(() => void (node = new ImportList()));

    it('a single import', () => {
      const imp = new DynamicImport('foo');
      node.append(imp);
      expect(node.nodes).toEqual([imp]);
      expect(imp).toHaveProperty('parent', node);
    });

    it('a list of imports', () => {
      const foo = new DynamicImport('foo');
      const bar = new DynamicImport('bar');
      node.append([foo, bar]);
      expect(node.nodes).toEqual([foo, bar]);
    });

    it('import properties', () => {
      node.append({url: 'foo'});
      expect(node.nodes[0]).toBeInstanceOf(DynamicImport);
      expect(node.nodes[0]).toHaveProperty('url', 'foo');
      expect(node.nodes[0]).toHaveProperty('parent', node);
    });

    it('an array of import properties', () => {
      node.append([{url: 'foo'}]);
      expect(node.nodes[0]).toBeInstanceOf(DynamicImport);
      expect(node.nodes[0]).toHaveProperty('url', 'foo');
      expect(node.nodes[0]).toHaveProperty('parent', node);
    });

    it('undefined', () => {
      node.append(undefined);
      expect(node.nodes).toHaveLength(0);
    });
  });

  describe('append', () => {
    beforeEach(
      () => void (node = new ImportList([{url: 'foo'}, {url: 'bar'}])),
    );

    it('adds multiple children to the end', () => {
      node.append({url: 'baz'}, {url: 'qux'});
      expect(node.nodes[0]).toHaveProperty('url', 'foo');
      expect(node.nodes[1]).toHaveProperty('url', 'bar');
      expect(node.nodes[2]).toHaveProperty('url', 'baz');
      expect(node.nodes[3]).toHaveProperty('url', 'qux');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () =>
        node.append({url: 'baz'}),
      ));

    it('returns itself', () => expect(node.append()).toBe(node));
  });

  describe('each', () => {
    beforeEach(
      () => void (node = new ImportList([{url: 'foo'}, {url: 'bar'}])),
    );

    it('calls the callback for each node', () => {
      const fn: EachFn = jest.fn();
      node.each(fn);
      expect(fn).toHaveBeenCalledTimes(2);
      expect(fn).toHaveBeenNthCalledWith(
        1,
        expect.objectContaining({url: 'foo'}),
        0,
      );
      expect(fn).toHaveBeenNthCalledWith(
        2,
        expect.objectContaining({url: 'bar'}),
        1,
      );
    });

    it('returns undefined if the callback is void', () =>
      expect(node.each(() => {})).toBeUndefined());

    it('returns false and stops iterating if the callback returns false', () => {
      const fn: EachFn = jest.fn(() => false);
      expect(node.each(fn)).toBe(false);
      expect(fn).toHaveBeenCalledTimes(1);
    });
  });

  describe('every', () => {
    beforeEach(
      () =>
        void (node = new ImportList([
          {url: 'foo'},
          {url: 'bar'},
          {url: 'baz'},
        ])),
    );

    it('returns true if the callback returns true for all elements', () =>
      expect(node.every(() => true)).toBe(true));

    it('returns false if the callback returns false for any element', () =>
      expect(
        node.every(element => 'url' in element && element.url !== 'bar'),
      ).toBe(false));
  });

  describe('index', () => {
    beforeEach(
      () =>
        void (node = new ImportList([
          {url: 'foo'},
          {url: 'bar'},
          {url: 'baz'},
        ])),
    );

    it('returns the first index of a given import', () =>
      expect(node.index(node.nodes[2])).toBe(2));

    it('returns a number as-is', () => expect(node.index(3)).toBe(3));
  });

  describe('insertAfter', () => {
    beforeEach(
      () =>
        void (node = new ImportList({
          nodes: [{url: 'foo'}, {url: 'bar'}, {url: 'baz'}],
        })),
    );

    it('inserts a node after the given element', () => {
      node.insertAfter(node.nodes[1], {url: 'qux'});
      expect(node.nodes[0]).toHaveProperty('url', 'foo');
      expect(node.nodes[1]).toHaveProperty('url', 'bar');
      expect(node.nodes[2]).toHaveProperty('url', 'qux');
      expect(node.nodes[3]).toHaveProperty('url', 'baz');
    });

    it('inserts a node at the beginning', () => {
      node.insertAfter(-1, {url: 'qux'});
      expect(node.nodes[0]).toHaveProperty('url', 'qux');
      expect(node.nodes[1]).toHaveProperty('url', 'foo');
      expect(node.nodes[2]).toHaveProperty('url', 'bar');
      expect(node.nodes[3]).toHaveProperty('url', 'baz');
    });

    it('inserts a node at the end', () => {
      node.insertAfter(3, {url: 'qux'});
      expect(node.nodes[0]).toHaveProperty('url', 'foo');
      expect(node.nodes[1]).toHaveProperty('url', 'bar');
      expect(node.nodes[2]).toHaveProperty('url', 'baz');
      expect(node.nodes[3]).toHaveProperty('url', 'qux');
    });

    it('inserts multiple nodes', () => {
      node.insertAfter(1, [{url: 'qux'}, {url: 'qax'}, {url: 'qix'}]);
      expect(node.nodes[0]).toHaveProperty('url', 'foo');
      expect(node.nodes[1]).toHaveProperty('url', 'bar');
      expect(node.nodes[2]).toHaveProperty('url', 'qux');
      expect(node.nodes[3]).toHaveProperty('url', 'qax');
      expect(node.nodes[4]).toHaveProperty('url', 'qix');
      expect(node.nodes[5]).toHaveProperty('url', 'baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertAfter(0, [{url: 'qux'}, {url: 'qax'}, {url: 'qix'}]),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertAfter(1, [{url: 'qux'}, {url: 'qax'}, {url: 'qix'}]),
      ));

    it('returns itself', () =>
      expect(node.insertAfter(0, {url: 'qux'})).toBe(node));
  });

  describe('insertBefore', () => {
    beforeEach(
      () =>
        void (node = new ImportList([
          {url: 'foo'},
          {url: 'bar'},
          {url: 'baz'},
        ])),
    );

    it('inserts a node before the given element', () => {
      node.insertBefore(node.nodes[1], {url: 'qux'});
      expect(node.nodes[0]).toHaveProperty('url', 'foo');
      expect(node.nodes[1]).toHaveProperty('url', 'qux');
      expect(node.nodes[2]).toHaveProperty('url', 'bar');
      expect(node.nodes[3]).toHaveProperty('url', 'baz');
    });

    it('inserts a node at the beginning', () => {
      node.insertBefore(0, {url: 'qux'});
      expect(node.nodes[0]).toHaveProperty('url', 'qux');
      expect(node.nodes[1]).toHaveProperty('url', 'foo');
      expect(node.nodes[2]).toHaveProperty('url', 'bar');
      expect(node.nodes[3]).toHaveProperty('url', 'baz');
    });

    it('inserts a node at the end', () => {
      node.insertBefore(4, {url: 'qux'});
      expect(node.nodes[0]).toHaveProperty('url', 'foo');
      expect(node.nodes[1]).toHaveProperty('url', 'bar');
      expect(node.nodes[2]).toHaveProperty('url', 'baz');
      expect(node.nodes[3]).toHaveProperty('url', 'qux');
    });

    it('inserts multiple nodes', () => {
      node.insertBefore(1, [{url: 'qux'}, {url: 'qax'}, {url: 'qix'}]);
      expect(node.nodes[0]).toHaveProperty('url', 'foo');
      expect(node.nodes[1]).toHaveProperty('url', 'qux');
      expect(node.nodes[2]).toHaveProperty('url', 'qax');
      expect(node.nodes[3]).toHaveProperty('url', 'qix');
      expect(node.nodes[4]).toHaveProperty('url', 'bar');
      expect(node.nodes[5]).toHaveProperty('url', 'baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertBefore(1, [{url: 'qux'}, {url: 'qax'}, {url: 'qix'}]),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertBefore(2, [{url: 'qux'}, {url: 'qax'}, {url: 'qix'}]),
      ));

    it('returns itself', () =>
      expect(node.insertBefore(0, {url: 'qux'})).toBe(node));
  });

  describe('prepend', () => {
    beforeEach(
      () =>
        void (node = new ImportList([
          {url: 'foo'},
          {url: 'bar'},
          {url: 'baz'},
        ])),
    );

    it('inserts one node', () => {
      node.prepend({url: 'qux'});
      expect(node.nodes[0]).toHaveProperty('url', 'qux');
      expect(node.nodes[1]).toHaveProperty('url', 'foo');
      expect(node.nodes[2]).toHaveProperty('url', 'bar');
      expect(node.nodes[3]).toHaveProperty('url', 'baz');
    });

    it('inserts multiple nodes', () => {
      node.prepend({url: 'qux'}, {url: 'qax'}, {url: 'qix'});
      expect(node.nodes[0]).toHaveProperty('url', 'qux');
      expect(node.nodes[1]).toHaveProperty('url', 'qax');
      expect(node.nodes[2]).toHaveProperty('url', 'qix');
      expect(node.nodes[3]).toHaveProperty('url', 'foo');
      expect(node.nodes[4]).toHaveProperty('url', 'bar');
      expect(node.nodes[5]).toHaveProperty('url', 'baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.prepend({url: 'qux'}, {url: 'qax'}, {url: 'qix'}),
      ));

    it('returns itself', () => expect(node.prepend({url: 'qux'})).toBe(node));
  });

  describe('push', () => {
    beforeEach(
      () => void (node = new ImportList([{url: 'foo'}, {url: 'bar'}])),
    );

    it('inserts one node', () => {
      node.push(new DynamicImport({url: 'baz'}));
      expect(node.nodes[0]).toHaveProperty('url', 'foo');
      expect(node.nodes[1]).toHaveProperty('url', 'bar');
      expect(node.nodes[2]).toHaveProperty('url', 'baz');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () =>
        node.push(new DynamicImport({url: 'baz'})),
      ));

    it('returns itself', () =>
      expect(node.push(new DynamicImport({url: 'baz'}))).toBe(node));
  });

  describe('removeAll', () => {
    beforeEach(
      () =>
        void (node = new ImportList([
          {url: 'foo'},
          {url: 'bar'},
          {url: 'baz'},
        ])),
    );

    it('removes all nodes', () => {
      node.removeAll();
      expect(node.nodes).toHaveLength(0);
    });

    it("removes a node's parents", () => {
      const child = node.nodes[1];
      node.removeAll();
      expect(child).toHaveProperty('parent', undefined);
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo'], 0, () => node.removeAll()));

    it('returns itself', () => expect(node.removeAll()).toBe(node));
  });

  describe('removeChild', () => {
    beforeEach(
      () =>
        void (node = new ImportList([
          {url: 'foo'},
          {url: 'bar'},
          {url: 'baz'},
        ])),
    );

    it('removes a matching node', () => {
      node.removeChild(node.nodes[0]);
      expect(node.nodes[0]).toHaveProperty('url', 'bar');
      expect(node.nodes[1]).toHaveProperty('url', 'baz');
    });

    it('removes a node at index', () => {
      node.removeChild(1);
      expect(node.nodes[0]).toHaveProperty('url', 'foo');
      expect(node.nodes[1]).toHaveProperty('url', 'baz');
    });

    it("removes a node's parents", () => {
      const child = node.nodes[1];
      node.removeChild(1);
      expect(child).toHaveProperty('parent', undefined);
    });

    it('removes a node before the iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 1]], 1, () =>
        node.removeChild(1),
      ));

    it('removes a node after the iterator', () =>
      testEachMutation(['foo', 'bar'], 1, () => node.removeChild(2)));

    it('returns itself', () => expect(node.removeChild(0)).toBe(node));
  });

  describe('some', () => {
    beforeEach(
      () =>
        void (node = new ImportList([
          {url: 'foo'},
          {url: 'bar'},
          {url: 'baz'},
        ])),
    );

    it('returns false if the callback returns false for all elements', () =>
      expect(node.some(() => false)).toBe(false));

    it('returns true if the callback returns true for any element', () =>
      expect(
        node.some(element => 'url' in element && element.url === 'bar'),
      ).toBe(true));
  });

  describe('first', () => {
    it('returns the first element', () =>
      expect(
        new ImportList([{url: 'foo'}, {url: 'bar'}, {url: 'baz'}]).first,
      ).toHaveProperty('url', 'foo'));

    it('returns undefined for an empty list', () =>
      expect(new ImportList().first).toBeUndefined());
  });

  describe('last', () => {
    it('returns the last element', () =>
      expect(
        new ImportList({nodes: [{url: 'foo'}, {url: 'bar'}, {url: 'baz'}]})
          .last,
      ).toHaveProperty('url', 'baz'));

    it('returns undefined for an empty list', () =>
      expect(new ImportList().last).toBeUndefined());
  });

  // TODO: test before and after raws for children
  describe('stringifies', () => {
    it('with default raws', () =>
      expect(
        new ImportList([{url: 'foo'}, {url: 'bar'}, {url: 'baz'}]).toString(),
      ).toBe('"foo", "bar", "baz"'));

    it('with an import with before', () =>
      expect(
        new ImportList([
          {url: 'foo', raws: {before: '/**/'}},
          {url: 'bar'},
          {url: 'baz'},
        ]).toString(),
      ).toBe('/**/"foo", "bar", "baz"'));

    it('with an import with after', () =>
      expect(
        new ImportList([
          {url: 'foo', raws: {after: '/**/'}},
          {url: 'bar'},
          {url: 'baz'},
        ]).toString(),
      ).toBe('"foo"/**/, "bar", "baz"'));
  });

  describe('clone', () => {
    let original: ImportList;
    beforeEach(
      () =>
        void (original = new ImportList({
          nodes: [{url: 'foo'}, {url: 'bar'}],
        })),
    );

    describe('with no overrides', () => {
      let clone: ImportList;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('nodes', () => {
          expect(clone.nodes[0]).toHaveProperty('url', 'foo');
          expect(clone.nodes[0].parent).toBe(clone);
          expect(clone.nodes[1]).toHaveProperty('url', 'bar');
          expect(clone.nodes[1].parent).toBe(clone);
        });

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['nodes'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });

      describe('sets parent for', () => {
        it('nodes', () =>
          expect(clone.nodes[0]).toHaveProperty('parent', clone));
      });
    });

    describe('overrides', () => {
      describe('nodes', () => {
        it('defined', () => {
          const clone = original.clone({nodes: [{url: 'qux'}]});
          expect(clone.nodes[0]).toHaveProperty('url', 'qux');
        });

        it('undefined', () => {
          const clone = original.clone({nodes: undefined});
          expect(clone.nodes).toHaveLength(2);
          expect(clone.nodes[0]).toHaveProperty('url', 'foo');
          expect(clone.nodes[1]).toHaveProperty('url', 'bar');
        });
      });
    });
  });

  it('toJSON', () =>
    expect(
      (scss.parse('@import "foo", "bar.css"').nodes[0] as ImportRule).imports,
    ).toMatchSnapshot());
});

/**
 * Runs `node.each`, asserting that it sees an import with each string value
 * and index in {@link elements} in order. If an index isn't explicitly
 * provided, it defaults to the index in {@link elements}.
 *
 * When it reaches {@link indexToModify}, it calls {@link modify}, which is
 * expected to modify `node.nodes`.
 */
function testEachMutation(
  elements: ([string, number] | string)[],
  indexToModify: number,
  modify: () => void,
): void {
  const fn: EachFn = jest.fn((child, i) => {
    if (i === indexToModify) modify();
  });
  node.each(fn);

  for (let i = 0; i < elements.length; i++) {
    const element = elements[i];
    const [url, index] = Array.isArray(element) ? element : [element, i];
    expect(fn).toHaveBeenNthCalledWith(
      i + 1,
      expect.objectContaining({url}),
      index,
    );
  }
  expect(fn).toHaveBeenCalledTimes(elements.length);
}
