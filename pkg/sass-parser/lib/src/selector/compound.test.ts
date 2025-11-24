// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  ClassSelector,
  ComplexSelectorComponent,
  CompoundSelector,
  CompoundSelectorProps,
} from '../..';
import * as utils from '../../../test/utils';

type EachFn = Parameters<CompoundSelector['each']>[0];

/** Parses `text` as a single compound selector. */
function parse(text: string): CompoundSelector {
  const list = utils.parseSelector(text);
  expect(list.nodes).toHaveLength(1);
  const complex = list.nodes[0];
  expect(complex.nodes).toHaveLength(1);
  const component = complex.nodes[0];
  expect(component.combinator).toBeUndefined();
  return component.compound;
}

/** Loads `props` as a compound selector. */
function fromProps(props: CompoundSelectorProps): CompoundSelector {
  return new ComplexSelectorComponent({compound: props}).compound;
}

let node: CompoundSelector;
describe('a compound selector', () => {
  describe('with one child', () => {
    function describeNode(
      description: string,
      create: () => CompoundSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType compound-selector', () =>
          expect(node.sassType).toBe('compound-selector'));

        it('has a child', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node).toHaveNode(0, '.foo', 'class');
        });
      });
    }

    describeNode('parsed', () => parse('.foo'));

    describeNode(
      'constructed manually',
      () => new CompoundSelector({nodes: [{class: 'foo'}]}),
    );

    describe('from props', () => {
      describe('as an object', () => {
        describeNode('with simple props', () =>
          fromProps({nodes: [{class: 'foo'}]}),
        );

        describeNode('with a full selector', () =>
          fromProps({nodes: [new ClassSelector({class: 'foo'})]}),
        );
      });

      describe('as an array', () => {
        describeNode('with simple props', () => fromProps([{class: 'foo'}]));

        describeNode('with a full selector', () =>
          fromProps([new ClassSelector({class: 'foo'})]),
        );
      });

      describeNode('as simple props', () => fromProps({class: 'foo'}));

      describeNode('as a simple selector', () =>
        fromProps(new ClassSelector({class: 'foo'})),
      );
    });
  });

  describe('with multiple children', () => {
    function describeNode(
      description: string,
      create: () => CompoundSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType compound-selector', () =>
          expect(node.sassType).toBe('compound-selector'));

        it('has children', () => {
          expect(node.nodes).toHaveLength(2);
          expect(node).toHaveNode(0, '.foo', 'class');
          expect(node).toHaveNode(1, '.bar', 'class');
        });
      });
    }

    describeNode('parsed', () => parse('.foo.bar'));

    describeNode(
      'constructed manually',
      () => new CompoundSelector({nodes: [{class: 'foo'}, {class: 'bar'}]}),
    );

    describe('from props', () => {
      describe('as an object', () => {
        describeNode('with simple props', () =>
          fromProps({nodes: [{class: 'foo'}, {class: 'bar'}]}),
        );

        describeNode('with a full selector', () =>
          fromProps({
            nodes: [
              new ClassSelector({class: 'foo'}),
              new ClassSelector({class: 'bar'}),
            ],
          }),
        );
      });

      describe('as an array', () => {
        describeNode('with simple props', () =>
          fromProps([{class: 'foo'}, {class: 'bar'}]),
        );

        describeNode('with a full selector', () =>
          fromProps([
            new ClassSelector({class: 'foo'}),
            new ClassSelector({class: 'bar'}),
          ]),
        );
      });
    });
  });

  describe('can add', () => {
    beforeEach(() => void (node = new CompoundSelector()));

    it('a single selector', () => {
      const classSelector = new ClassSelector({class: 'foo'});
      node.append(classSelector);
      expect(node.nodes[0]).toBe(classSelector);
      expect(classSelector.parent).toBe(node);
    });

    it('a list of selectors', () => {
      const classSelector1 = new ClassSelector({class: 'foo'});
      const classSelector2 = new ClassSelector({class: 'bar'});
      node.append([classSelector1, classSelector2]);
      expect(node.nodes[0]).toBe(classSelector1);
      expect(node.nodes[1]).toBe(classSelector2);
      expect(classSelector1.parent).toBe(node);
      expect(classSelector2.parent).toBe(node);
    });

    it("a single selector's properties", () => {
      node.append({class: 'foo'});
      expect(node).toHaveNode(0, '.foo');
    });

    it('a list of properties', () => {
      node.append([{class: 'foo'}, {class: 'bar'}]);
      expect(node).toHaveNode(0, '.foo');
      expect(node).toHaveNode(1, '.bar');
    });

    it('undefined', () => {
      node.append(undefined);
      expect(node.nodes).toHaveLength(0);
    });
  });

  describe('append', () => {
    beforeEach(
      () =>
        void (node = new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}],
        })),
    );

    it('adds multiple children to the end', () => {
      node.append({class: 'baz'}, {class: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, '.foo');
      expect(node).toHaveNode(1, '.bar');
      expect(node).toHaveNode(2, '.baz');
      expect(node).toHaveNode(3, '.qux');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () =>
        node.append({class: 'baz'}),
      ));

    it('returns itself', () => expect(node.append()).toBe(node));
  });

  describe('each', () => {
    beforeEach(
      () =>
        void (node = new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}],
        })),
    );

    it('calls the callback for each node', () => {
      const fn: EachFn = jest.fn();
      node.each(fn);
      expect(fn).toHaveBeenCalledTimes(2);
      expect(fn).toHaveBeenNthCalledWith(1, node.nodes[0], 0);
      expect(fn).toHaveBeenNthCalledWith(2, node.nodes[1], 1);
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
        void (node = new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}, {class: 'baz'}],
        })),
    );

    it('returns true if the callback returns true for all elements', () =>
      expect(node.every(() => true)).toBe(true));

    it('returns false if the callback returns false for any element', () =>
      expect(
        node.every(
          element => (element as ClassSelector).class.asPlain !== 'bar',
        ),
      ).toBe(false));
  });

  describe('index', () => {
    beforeEach(
      () =>
        void (node = new CompoundSelector({
          nodes: [
            {class: 'foo'},
            {class: 'bar'},
            {class: 'baz'},
            {class: 'qux'},
          ],
        })),
    );

    it('returns the first index of a given selector', () =>
      expect(node.index(node.nodes[2])).toBe(2));

    it('returns a number as-is', () => expect(node.index(3)).toBe(3));
  });

  describe('insertAfter', () => {
    beforeEach(
      () =>
        void (node = new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}, {class: 'baz'}],
        })),
    );

    it('inserts a node after the given element', () => {
      node.insertAfter(node.nodes[1], {class: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, '.foo');
      expect(node).toHaveNode(1, '.bar');
      expect(node).toHaveNode(2, '.qux');
      expect(node).toHaveNode(3, '.baz');
    });

    it('inserts a node at the beginning', () => {
      node.insertAfter(-1, {class: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, '.qux');
      expect(node).toHaveNode(1, '.foo');
      expect(node).toHaveNode(2, '.bar');
      expect(node).toHaveNode(3, '.baz');
    });

    it('inserts a node at the end', () => {
      node.insertAfter(3, {class: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, '.foo');
      expect(node).toHaveNode(1, '.bar');
      expect(node).toHaveNode(2, '.baz');
      expect(node).toHaveNode(3, '.qux');
    });

    it('inserts multiple nodes', () => {
      node.insertAfter(1, [{class: 'qux'}, {class: 'qax'}, {class: 'qix'}]);
      expect(node.nodes).toHaveLength(6);
      expect(node).toHaveNode(0, '.foo');
      expect(node).toHaveNode(1, '.bar');
      expect(node).toHaveNode(2, '.qux');
      expect(node).toHaveNode(3, '.qax');
      expect(node).toHaveNode(4, '.qix');
      expect(node).toHaveNode(5, '.baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertAfter(0, [{class: 'qux'}, {class: 'qax'}, {class: 'qix'}]),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertAfter(1, [{class: 'qux'}, {class: 'qax'}, {class: 'qix'}]),
      ));

    it('returns itself', () =>
      expect(node.insertAfter(node.nodes[0], {class: 'qux'})).toBe(node));
  });

  describe('insertBefore', () => {
    beforeEach(
      () =>
        void (node = new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}, {class: 'baz'}],
        })),
    );

    it('inserts a node before the given element', () => {
      node.insertBefore(node.nodes[1], {class: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, '.foo');
      expect(node).toHaveNode(1, '.qux');
      expect(node).toHaveNode(2, '.bar');
      expect(node).toHaveNode(3, '.baz');
    });

    it('inserts a node at the beginning', () => {
      node.insertBefore(0, {class: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, '.qux');
      expect(node).toHaveNode(1, '.foo');
      expect(node).toHaveNode(2, '.bar');
      expect(node).toHaveNode(3, '.baz');
    });

    it('inserts a node at the end', () => {
      node.insertBefore(4, {class: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, '.foo');
      expect(node).toHaveNode(1, '.bar');
      expect(node).toHaveNode(2, '.baz');
      expect(node).toHaveNode(3, '.qux');
    });

    it('inserts multiple nodes', () => {
      node.insertBefore(1, [{class: 'qux'}, {class: 'qax'}, {class: 'qix'}]);
      expect(node.nodes).toHaveLength(6);
      expect(node).toHaveNode(0, '.foo');
      expect(node).toHaveNode(1, '.qux');
      expect(node).toHaveNode(2, '.qax');
      expect(node).toHaveNode(3, '.qix');
      expect(node).toHaveNode(4, '.bar');
      expect(node).toHaveNode(5, '.baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertBefore(1, [{class: 'qux'}, {class: 'qax'}, {class: 'qix'}]),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertBefore(2, [{class: 'qux'}, {class: 'qax'}, {class: 'qix'}]),
      ));

    it('returns itself', () =>
      expect(node.insertBefore(node.nodes[0], {class: 'qux'})).toBe(node));
  });

  describe('prepend', () => {
    beforeEach(
      () =>
        void (node = new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}, {class: 'baz'}],
        })),
    );

    it('inserts one node', () => {
      node.prepend({class: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, '.qux');
      expect(node).toHaveNode(1, '.foo');
      expect(node).toHaveNode(2, '.bar');
      expect(node).toHaveNode(3, '.baz');
    });

    it('inserts multiple nodes', () => {
      node.prepend({class: 'qux'}, {class: 'qax'}, {class: 'qix'});
      expect(node.nodes).toHaveLength(6);
      expect(node).toHaveNode(0, '.qux');
      expect(node).toHaveNode(1, '.qax');
      expect(node).toHaveNode(2, '.qix');
      expect(node).toHaveNode(3, '.foo');
      expect(node).toHaveNode(4, '.bar');
      expect(node).toHaveNode(5, '.baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.prepend({class: 'qux'}, {class: 'qax'}, {class: 'qix'}),
      ));

    it('returns itself', () => expect(node.prepend({class: 'qux'})).toBe(node));
  });

  describe('push', () => {
    beforeEach(
      () =>
        void (node = new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}],
        })),
    );

    it('inserts one node', () => {
      node.push(new ClassSelector({class: 'baz'}));
      expect(node.nodes).toHaveLength(3);
      expect(node).toHaveNode(0, '.foo');
      expect(node).toHaveNode(1, '.bar');
      expect(node).toHaveNode(2, '.baz');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () =>
        node.push(new ClassSelector({class: 'baz'})),
      ));

    it('returns itself', () =>
      expect(node.push(new ClassSelector({class: 'baz'}))).toBe(node));
  });

  describe('removeAll', () => {
    beforeEach(
      () =>
        void (node = new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}, {class: 'baz'}],
        })),
    );

    it('removes all nodes', () => {
      node.removeAll();
      expect(node.nodes).toHaveLength(0);
    });

    it("removes a node's parents", () => {
      const classSelector = node.nodes[1];
      node.removeAll();
      expect(classSelector).toHaveProperty('parent', undefined);
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo'], 0, () => node.removeAll()));

    it('returns itself', () => expect(node.removeAll()).toBe(node));
  });

  describe('removeChild', () => {
    beforeEach(
      () =>
        void (node = new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}, {class: 'baz'}],
        })),
    );

    it('removes a matching node', () => {
      const child1 = node.nodes[1];
      const child2 = node.nodes[2];
      node.removeChild(node.nodes[0]);
      expect(node.nodes).toEqual([child1, child2]);
    });

    it('removes a node at index', () => {
      node.removeChild(1);
      expect(node.nodes).toHaveLength(2);
      expect(node).toHaveNode(0, '.foo');
      expect(node).toHaveNode(1, '.baz');
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
        void (node = new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}, {class: 'baz'}],
        })),
    );

    it('returns false if the callback returns false for all elements', () =>
      expect(node.some(() => false)).toBe(false));

    it('returns true if the callback returns true for any element', () =>
      expect(
        node.some(
          element => (element as ClassSelector).class.asPlain === 'bar',
        ),
      ).toBe(true));
  });

  describe('first', () => {
    it('returns the first element', () =>
      expect(
        new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}, {class: 'baz'}],
        }),
      ).toHaveNode('first', '.foo'));

    it('returns undefined for an empty selector', () =>
      expect(new CompoundSelector().first).toBeUndefined());
  });

  describe('last', () => {
    it('returns the last element', () =>
      expect(
        new CompoundSelector({
          nodes: [{class: 'foo'}, {class: 'bar'}, {class: 'baz'}],
        }),
      ).toHaveNode('last', '.baz'));

    it('returns undefined for an empty selector', () =>
      expect(new CompoundSelector().last).toBeUndefined());
  });

  describe('stringifies', () => {
    it('with one child', () => expect(parse('.foo').toString()).toBe('.foo'));

    it('with multiple children', () =>
      expect(parse('.foo.bar.baz').toString()).toBe('.foo.bar.baz'));
  });

  describe('clone', () => {
    let original: CompoundSelector;

    beforeEach(() => {
      original = parse('.foo.bar');
    });

    describe('with no overrides', () => {
      let clone: CompoundSelector;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('nodes', () => {
          expect(clone.nodes).toHaveLength(2);
          expect(clone).toHaveNode(0, '.foo');
          expect(clone).toHaveNode(1, '.bar');
        });

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['nodes', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('nodes', () => {
        it('defined', () => {
          const clone = original.clone({nodes: [{class: 'zip'}]});
          expect(clone.nodes).toHaveLength(1);
          expect(clone).toHaveNode(0, '.zip');
        });

        it('undefined', () => {
          const clone = original.clone({nodes: undefined});
          expect(clone.nodes).toHaveLength(2);
          expect(clone).toHaveNode(0, '.foo');
          expect(clone).toHaveNode(1, '.bar');
        });
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {}}).raws).toEqual({}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({}));
      });
    });
  });

  it('toJSON', () => expect(parse('.foo.bar')).toMatchSnapshot());
});

/**
 * Runs `node.each`, asserting that it sees each element and index in {@link
 * elements} in order. If an index isn't explicitly provided, it defaults to the
 * index in {@link elements}.
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
    const [value, index] = Array.isArray(element) ? element : [element, i];
    expect(fn).toHaveBeenNthCalledWith(
      i + 1,
      expect.objectContaining({
        class: expect.objectContaining({asPlain: value}),
      }),
      index,
    );
  }
  expect(fn).toHaveBeenCalledTimes(elements.length);
}
