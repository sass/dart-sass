// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {MapEntry, MapExpression, StringExpression} from '../..';
import * as utils from '../../../test/utils';

type EachFn = Parameters<MapExpression['each']>[0];

let node: MapExpression;
describe('a map expression', () => {
  describe('empty', () => {
    function describeNode(
      description: string,
      create: () => MapExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType map', () => expect(node.sassType).toBe('map'));

        it('is empty', () => expect(node.nodes).toHaveLength(0));
      });
    }

    // An empty map can't be parsed, because it's always parsed as a list
    // instead.

    describeNode('constructed manually', () => new MapExpression({nodes: []}));

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({nodes: []}),
    );
  });

  describe('with one pair', () => {
    function describeNode(
      description: string,
      create: () => MapExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType map', () => expect(node.sassType).toBe('map'));

        it('has an entry', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
          expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
        });
      });
    }

    describeNode('parsed', () => utils.parseExpression('(foo: bar)'));

    describeNode(
      'constructed manually',
      () =>
        new MapExpression({
          nodes: [[{text: 'foo'}, {text: 'bar'}]],
        }),
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({
        nodes: [[{text: 'foo'}, {text: 'bar'}]],
      }),
    );
  });

  describe('with multiple elements ', () => {
    function describeNode(
      description: string,
      create: () => MapExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType map', () => expect(node.sassType).toBe('map'));

        it('has elements', () => {
          expect(node.nodes).toHaveLength(2);
          expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
          expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
          expect(node.nodes[1]).toHaveStringExpression('key', 'baz');
          expect(node.nodes[1]).toHaveStringExpression('value', 'qux');
        });
      });
    }

    describeNode('parsed', () => utils.parseExpression('(foo: bar, baz: qux)'));

    describeNode(
      'constructed manually',
      () =>
        new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'qux'}],
          ],
        }),
    );

    describeNode('constructed from ExpressionProps', () =>
      utils.fromExpressionProps({
        nodes: [
          [{text: 'foo'}, {text: 'bar'}],
          [{text: 'baz'}, {text: 'qux'}],
        ],
      }),
    );
  });

  describe('can add', () => {
    beforeEach(() => void (node = new MapExpression({nodes: []})));

    it('a single entry', () => {
      const entry = new MapEntry({key: {text: 'foo'}, value: {text: 'bar'}});
      node.append(entry);
      expect(node.nodes[0]).toBe(entry);
      expect(entry.parent).toBe(node);
    });

    it('a list of entries', () => {
      const entry1 = new MapEntry({key: {text: 'foo'}, value: {text: 'bar'}});
      const entry2 = new MapEntry({key: {text: 'baz'}, value: {text: 'qux'}});
      node.append([entry1, entry2]);
      expect(node.nodes[0]).toBe(entry1);
      expect(node.nodes[1]).toBe(entry2);
      expect(entry1.parent).toBe(node);
      expect(entry2.parent).toBe(node);
    });

    it("a single entry's properties as an object", () => {
      node.append({key: {text: 'foo'}, value: {text: 'bar'}});
      expect(node.nodes[0].parent).toBe(node);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
    });

    it("a single entry's properties as a list", () => {
      node.append([{text: 'foo'}, {text: 'bar'}]);
      expect(node.nodes[0].parent).toBe(node);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
    });

    it('a list of entry properties as objects', () => {
      node.append([
        {key: {text: 'foo'}, value: {text: 'bar'}},
        {key: {text: 'baz'}, value: {text: 'qux'}},
      ]);
      expect(node.nodes[0].parent).toBe(node);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[1].parent).toBe(node);
      expect(node.nodes[1]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[1]).toHaveStringExpression('value', 'qux');
    });

    it('a list of entry properties as lists', () => {
      node.append([
        [{text: 'foo'}, {text: 'bar'}],
        [{text: 'baz'}, {text: 'qux'}],
      ]);
      expect(node.nodes[0].parent).toBe(node);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[1].parent).toBe(node);
      expect(node.nodes[1]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[1]).toHaveStringExpression('value', 'qux');
    });

    it('undefined', () => {
      node.append(undefined);
      expect(node.nodes).toHaveLength(0);
    });
  });

  describe('append', () => {
    beforeEach(
      () =>
        void (node = new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'qux'}],
          ],
        })),
    );

    it('adds multiple children to the end', () => {
      node.append(
        [{text: 'zip'}, {text: 'zap'}],
        [{text: 'zop'}, {text: 'zoop'}],
      );
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[2]).toHaveStringExpression('key', 'zip');
      expect(node.nodes[2]).toHaveStringExpression('value', 'zap');
      expect(node.nodes[3]).toHaveStringExpression('key', 'zop');
      expect(node.nodes[3]).toHaveStringExpression('value', 'zoop');
    });

    it('can be called during iteration', () =>
      testEachMutation(
        [
          ['foo', 'bar'],
          ['baz', 'qux'],
          ['zip', 'zap'],
        ],
        0,
        () => node.append([{text: 'zip'}, {text: 'zap'}]),
      ));

    it('returns itself', () => expect(node.append()).toBe(node));
  });

  describe('each', () => {
    beforeEach(
      () =>
        void (node = new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'qux'}],
          ],
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
        void (node = new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'bang'}],
            [{text: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('returns true if the callback returns true for all elements', () =>
      expect(node.every(() => true)).toBe(true));

    it('returns false if the callback returns false for any element', () =>
      expect(
        node.every(
          element => (element.key as StringExpression).text.asPlain !== 'baz',
        ),
      ).toBe(false));
  });

  describe('index', () => {
    beforeEach(
      () =>
        void (node = new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'bang'}],
            [{text: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('returns the first index of a given expression', () =>
      expect(node.index(node.nodes[2])).toBe(2));

    it('returns a number as-is', () => expect(node.index(3)).toBe(3));
  });

  describe('insertAfter', () => {
    beforeEach(
      () =>
        void (node = new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'bang'}],
            [{text: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('inserts a node after the given element', () => {
      node.insertAfter(node.nodes[1], [{text: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[2]).toHaveStringExpression('key', 'zop');
      expect(node.nodes[2]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[3]).toHaveStringExpression('key', 'zip');
    });

    it('inserts a node at the beginning', () => {
      node.insertAfter(-1, [{text: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveStringExpression('key', 'zop');
      expect(node.nodes[0]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[1]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[2]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[3]).toHaveStringExpression('key', 'zip');
    });

    it('inserts a node at the end', () => {
      node.insertAfter(3, [{text: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[2]).toHaveStringExpression('key', 'zip');
      expect(node.nodes[3]).toHaveStringExpression('key', 'zop');
      expect(node.nodes[3]).toHaveStringExpression('value', 'zoop');
    });

    it('inserts multiple nodes', () => {
      node.insertAfter(1, [
        [{text: 'zop'}, {text: 'zoop'}],
        [{text: 'flip'}, {text: 'flap'}],
      ]);
      expect(node.nodes).toHaveLength(5);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[2]).toHaveStringExpression('key', 'zop');
      expect(node.nodes[2]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[3]).toHaveStringExpression('key', 'flip');
      expect(node.nodes[3]).toHaveStringExpression('value', 'flap');
      expect(node.nodes[4]).toHaveStringExpression('key', 'zip');
    });

    it('inserts before an iterator', () =>
      testEachMutation(
        [
          ['foo', 'bar'],
          ['baz', 'bang'],
          [['zip', 'zap'], 5],
        ],
        1,
        () =>
          node.insertAfter(0, [
            [{text: 'zop'}, {text: 'zoop'}],
            [{text: 'qux'}, {text: 'qax'}],
            [{text: 'flip'}, {text: 'flap'}],
          ]),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(
        [
          ['foo', 'bar'],
          ['baz', 'bang'],
          ['zop', 'zoop'],
          ['qux', 'qax'],
          ['flip', 'flap'],
          ['zip', 'zap'],
        ],
        1,
        () =>
          node.insertAfter(1, [
            [{text: 'zop'}, {text: 'zoop'}],
            [{text: 'qux'}, {text: 'qax'}],
            [{text: 'flip'}, {text: 'flap'}],
          ]),
      ));

    it('returns itself', () =>
      expect(
        node.insertAfter(node.nodes[0], [{text: 'qux'}, {text: 'qax'}]),
      ).toBe(node));
  });

  describe('insertBefore', () => {
    beforeEach(
      () =>
        void (node = new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'bang'}],
            [{text: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('inserts a node before the given element', () => {
      node.insertBefore(node.nodes[1], [{text: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('key', 'zop');
      expect(node.nodes[1]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[2]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[3]).toHaveStringExpression('key', 'zip');
    });

    it('inserts a node at the beginning', () => {
      node.insertBefore(0, [{text: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveStringExpression('key', 'zop');
      expect(node.nodes[0]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[1]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[2]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[3]).toHaveStringExpression('key', 'zip');
    });

    it('inserts a node at the end', () => {
      node.insertBefore(4, [{text: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[2]).toHaveStringExpression('key', 'zip');
      expect(node.nodes[3]).toHaveStringExpression('key', 'zop');
      expect(node.nodes[3]).toHaveStringExpression('value', 'zoop');
    });

    it('inserts multiple nodes', () => {
      node.insertBefore(1, [
        [{text: 'zop'}, {text: 'zoop'}],
        [{text: 'flip'}, {text: 'flap'}],
      ]);
      expect(node.nodes).toHaveLength(5);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('key', 'zop');
      expect(node.nodes[1]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[2]).toHaveStringExpression('key', 'flip');
      expect(node.nodes[2]).toHaveStringExpression('value', 'flap');
      expect(node.nodes[3]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[4]).toHaveStringExpression('key', 'zip');
    });

    it('inserts before an iterator', () =>
      testEachMutation(
        [
          ['foo', 'bar'],
          ['baz', 'bang'],
          [['zip', 'zap'], 5],
        ],
        1,
        () =>
          node.insertBefore(1, [
            [{text: 'zop'}, {text: 'zoop'}],
            [{text: 'qux'}, {text: 'qax'}],
            [{text: 'flip'}, {text: 'flap'}],
          ]),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(
        [
          ['foo', 'bar'],
          ['baz', 'bang'],
          ['zop', 'zoop'],
          ['qux', 'qax'],
          ['flip', 'flap'],
          ['zip', 'zap'],
        ],
        1,
        () =>
          node.insertBefore(2, [
            [{text: 'zop'}, {text: 'zoop'}],
            [{text: 'qux'}, {text: 'qax'}],
            [{text: 'flip'}, {text: 'flap'}],
          ]),
      ));

    it('returns itself', () =>
      expect(
        node.insertBefore(node.nodes[0], [{text: 'qux'}, {text: 'qax'}]),
      ).toBe(node));
  });

  describe('prepend', () => {
    beforeEach(
      () =>
        void (node = new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'bang'}],
            [{text: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('inserts one node', () => {
      node.prepend([{text: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveStringExpression('key', 'zop');
      expect(node.nodes[0]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[1]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[2]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[3]).toHaveStringExpression('key', 'zip');
    });

    it('inserts multiple nodes', () => {
      node.prepend([
        [{text: 'zop'}, {text: 'zoop'}],
        [{text: 'flip'}, {text: 'flap'}],
      ]);
      expect(node.nodes).toHaveLength(5);
      expect(node.nodes[0]).toHaveStringExpression('key', 'zop');
      expect(node.nodes[0]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[1]).toHaveStringExpression('key', 'flip');
      expect(node.nodes[1]).toHaveStringExpression('value', 'flap');
      expect(node.nodes[2]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[3]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[4]).toHaveStringExpression('key', 'zip');
    });

    it('inserts before an iterator', () =>
      testEachMutation(
        [
          ['foo', 'bar'],
          ['baz', 'bang'],
          [['zip', 'zap'], 5],
        ],
        1,
        () =>
          node.prepend(
            [{text: 'zop'}, {text: 'zoop'}],
            [{text: 'qux'}, {text: 'qax'}],
            [{text: 'flip'}, {text: 'flap'}],
          ),
      ));

    it('returns itself', () =>
      expect(node.prepend([{text: 'qux'}, {text: 'qax'}])).toBe(node));
  });

  describe('push', () => {
    beforeEach(
      () =>
        void (node = new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'bang'}],
          ],
        })),
    );

    it('inserts one node', () => {
      node.push(new MapEntry([{text: 'zip'}, {text: 'zap'}]));
      expect(node.nodes).toHaveLength(3);
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('key', 'baz');
      expect(node.nodes[2]).toHaveStringExpression('key', 'zip');
      expect(node.nodes[2]).toHaveStringExpression('value', 'zap');
    });

    it('can be called during iteration', () =>
      testEachMutation(
        [
          ['foo', 'bar'],
          ['baz', 'bang'],
          ['zip', 'zap'],
        ],
        0,
        () => node.push(new MapEntry([{text: 'zip'}, {text: 'zap'}])),
      ));

    it('returns itself', () =>
      expect(node.push(new MapEntry([{text: 'zip'}, {text: 'zap'}]))).toBe(
        node,
      ));
  });

  describe('removeAll', () => {
    beforeEach(
      () =>
        void (node = new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'bang'}],
            [{text: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('removes all nodes', () => {
      node.removeAll();
      expect(node.nodes).toHaveLength(0);
    });

    it("removes a node's parents", () => {
      const string = node.nodes[1];
      node.removeAll();
      expect(string).toHaveProperty('parent', undefined);
    });

    it('can be called during iteration', () =>
      testEachMutation([['foo', 'bar']], 0, () => node.removeAll()));

    it('returns itself', () => expect(node.removeAll()).toBe(node));
  });

  describe('removeChild', () => {
    beforeEach(
      () =>
        void (node = new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'bang'}],
            [{text: 'zip'}, {text: 'zap'}],
          ],
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
      expect(node.nodes[0]).toHaveStringExpression('key', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('key', 'zip');
    });

    it("removes a node's parents", () => {
      const child = node.nodes[1];
      node.removeChild(1);
      expect(child).toHaveProperty('parent', undefined);
    });

    it('removes a node before the iterator', () =>
      testEachMutation(
        [
          ['foo', 'bar'],
          ['baz', 'bang'],
          [['zip', 'zap'], 1],
        ],
        1,
        () => node.removeChild(1),
      ));

    it('removes a node after the iterator', () =>
      testEachMutation(
        [
          ['foo', 'bar'],
          ['baz', 'bang'],
        ],
        1,
        () => node.removeChild(2),
      ));

    it('returns itself', () => expect(node.removeChild(0)).toBe(node));
  });

  describe('some', () => {
    beforeEach(
      () =>
        void (node = new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'bang'}],
            [{text: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('returns false if the callback returns false for all elements', () =>
      expect(node.some(() => false)).toBe(false));

    it('returns true if the callback returns true for any element', () =>
      expect(
        node.some(
          element => (element.key as StringExpression).text.asPlain === 'baz',
        ),
      ).toBe(true));
  });

  describe('first', () => {
    it('returns the first element', () =>
      expect(
        new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'bang'}],
            [{text: 'zip'}, {text: 'zap'}],
          ],
        }).first,
      ).toHaveStringExpression('key', 'foo'));

    it('returns undefined for an empty map', () =>
      expect(new MapExpression({nodes: []}).first).toBeUndefined());
  });

  describe('last', () => {
    it('returns the last element', () =>
      expect(
        new MapExpression({
          nodes: [
            [{text: 'foo'}, {text: 'bar'}],
            [{text: 'baz'}, {text: 'bang'}],
            [{text: 'zip'}, {text: 'zap'}],
          ],
        }).last,
      ).toHaveStringExpression('key', 'zip'));

    it('returns undefined for an empty interpolation', () =>
      expect(new MapExpression({nodes: []}).last).toBeUndefined());
  });

  describe('stringifies', () => {
    describe('with default raws', () => {
      it('empty', () =>
        expect(new MapExpression({nodes: []}).toString()).toBe('()'));

      it('with one pair', () =>
        expect(
          new MapExpression({
            nodes: [[{text: 'foo'}, {text: 'bar'}]],
          }).toString(),
        ).toBe('(foo: bar)'));

      it('with multiple pairs', () =>
        expect(
          new MapExpression({
            nodes: [
              [{text: 'foo'}, {text: 'bar'}],
              [{text: 'zip'}, {text: 'zap'}],
            ],
          }).toString(),
        ).toBe('(foo: bar, zip: zap)'));
    });

    describe('afterOpen', () => {
      describe('empty', () => {
        it('no beforeClose', () =>
          expect(
            new MapExpression({
              raws: {afterOpen: '/**/'},
              nodes: [],
            }).toString(),
          ).toBe('(/**/)'));

        it('and beforeClose', () =>
          expect(
            new MapExpression({
              raws: {afterOpen: '/**/', beforeClose: '  '},
              nodes: [],
            }).toString(),
          ).toBe('(/**/  )'));
      });

      describe('one pair', () => {
        it('no nodes.before', () =>
          expect(
            new MapExpression({
              raws: {afterOpen: '/**/'},
              nodes: [[{text: 'foo'}, {text: 'bar'}]],
            }).toString(),
          ).toBe('(/**/foo: bar)'));

        it('with nodes.before', () =>
          expect(
            new MapExpression({
              raws: {afterOpen: '/**/'},
              nodes: [
                {
                  key: {text: 'foo'},
                  value: {text: 'bar'},
                  raws: {before: '  '},
                },
              ],
            }).toString(),
          ).toBe('(/**/  foo: bar)'));
      });
    });

    describe('beforeClose', () => {
      it('empty', () =>
        expect(
          new MapExpression({
            raws: {beforeClose: '/**/'},
            nodes: [],
          }).toString(),
        ).toBe('(/**/)'));

      describe('one pair', () => {
        it('no nodes.after', () =>
          expect(
            new MapExpression({
              raws: {beforeClose: '/**/'},
              nodes: [[{text: 'foo'}, {text: 'bar'}]],
            }).toString(),
          ).toBe('(foo: bar/**/)'));

        it('with nodes.after', () =>
          expect(
            new MapExpression({
              raws: {beforeClose: '/**/'},
              nodes: [
                {
                  key: {text: 'foo'},
                  value: {text: 'bar'},
                  raws: {after: '  '},
                },
              ],
            }).toString(),
          ).toBe('(foo: bar  /**/)'));
      });
    });

    describe('trailingComma', () => {
      describe('is ignored for', () => {
        describe('empty', () =>
          expect(
            new MapExpression({
              raws: {trailingComma: true},
              nodes: [],
            }).toString(),
          ).toBe('()'));
      });

      describe('one element', () => {
        it('no nodes.after', () =>
          expect(
            new MapExpression({
              raws: {trailingComma: true},
              nodes: [[{text: 'foo'}, {text: 'bar'}]],
            }).toString(),
          ).toBe('(foo: bar,)'));

        it('with nodes.after', () =>
          expect(
            new MapExpression({
              raws: {trailingComma: true},
              nodes: [
                {
                  key: {text: 'foo'},
                  value: {text: 'bar'},
                  raws: {after: '/**/'},
                },
              ],
            }).toString(),
          ).toBe('(foo: bar/**/,)'));
      });
    });
  });

  describe('clone', () => {
    let original: MapExpression;

    beforeEach(() => {
      original = utils.parseExpression('(foo: bar, baz: bang)');
      // TODO: remove this once raws are properly parsed.
      original.raws.afterOpen = '  ';
    });

    describe('with no overrides', () => {
      let clone: MapExpression;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('nodes', () => {
          expect(clone.nodes).toHaveLength(2);
          expect(clone.nodes[0]).toHaveStringExpression('key', 'foo');
          expect(clone.nodes[0]).toHaveStringExpression('value', 'bar');
          expect(clone.nodes[1]).toHaveStringExpression('key', 'baz');
          expect(clone.nodes[1]).toHaveStringExpression('value', 'bang');
        });

        it('raws', () => expect(clone.raws).toEqual({afterOpen: '  '}));

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
          const clone = original.clone({
            nodes: [[{text: 'zip'}, {text: 'zap'}]],
          });
          expect(clone.nodes).toHaveLength(1);
          expect(clone.nodes[0]).toHaveStringExpression('key', 'zip');
          expect(clone.nodes[0]).toHaveStringExpression('value', 'zap');
        });

        it('undefined', () => {
          const clone = original.clone({nodes: undefined});
          expect(clone.nodes).toHaveLength(2);
          expect(clone.nodes[0]).toHaveStringExpression('key', 'foo');
          expect(clone.nodes[1]).toHaveStringExpression('key', 'baz');
        });
      });

      describe('raws', () => {
        it('defined', () =>
          expect(
            original.clone({raws: {beforeClose: '/**/'}}).raws.beforeClose,
          ).toBe('/**/'));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws.afterOpen).toBe('  '));
      });
    });
  });

  it('toJSON', () =>
    expect(utils.parseExpression('(foo: bar, baz: bang)')).toMatchSnapshot());
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
  elements: ([[string, string], number] | [string, string])[],
  indexToModify: number,
  modify: () => void,
): void {
  const fn: EachFn = jest.fn((child, i) => {
    if (i === indexToModify) modify();
  });
  node.each(fn);

  for (let i = 0; i < elements.length; i++) {
    const element = elements[i];
    const [[key, value], index] = Array.isArray(element[0])
      ? element
      : [element, i];
    expect(fn).toHaveBeenNthCalledWith(
      i + 1,
      expect.objectContaining({
        key: expect.objectContaining({
          text: expect.objectContaining({asPlain: key}),
        }),
        value: expect.objectContaining({
          text: expect.objectContaining({asPlain: value}),
        }),
      }),
      index,
    );
  }
  expect(fn).toHaveBeenCalledTimes(elements.length);
}
