// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {IfConditionSass, IfEntry, IfExpression} from '../..';
import * as utils from '../../../test/utils';

type EachFn = Parameters<IfExpression['each']>[0];

let node: IfExpression;
describe('an if expression', () => {
  describe('empty', () => {
    function describeNode(
      description: string,
      create: () => IfExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType if-expr', () => expect(node.sassType).toBe('if-expr'));

        it('is empty', () => expect(node.nodes).toHaveLength(0));
      });
    }

    // An empty if() isn't valid CSS syntax, so it can't be parsed.

    describeNode('constructed manually', () => new IfExpression({nodes: []}));

    // We don't support constructing IfExpression from props alone, because it
    // would be ambiguous with MapExpression.
  });

  describe('with one branch', () => {
    function describeNode(
      description: string,
      create: () => IfExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType if-expr', () => expect(node.sassType).toBe('if-expr'));

        it('has an entry', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0].condition).toBe('else');
          expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
        });
      });
    }

    describeNode('parsed', () => utils.parseExpression('if(else: foo)'));

    describeNode(
      'constructed manually',
      () =>
        new IfExpression({
          nodes: [['else', {text: 'foo'}]],
        }),
    );
  });

  describe('with multiple elements ', () => {
    function describeNode(
      description: string,
      create: () => IfExpression,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType if-expr', () => expect(node.sassType).toBe('if-expr'));

        it('has elements', () => {
          expect(node.nodes).toHaveLength(2);
          expect(node.nodes[0]).toHaveNode('condition', 'sass(true)');
          expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
          expect(node.nodes[1].condition).toBe('else');
          expect(node.nodes[1]).toHaveStringExpression('value', 'bar');
        });
      });
    }

    describeNode('parsed', () =>
      utils.parseExpression('if(sass(true): foo; else: bar)'),
    );

    describeNode(
      'constructed manually',
      () =>
        new IfExpression({
          nodes: [
            [{value: true}, {text: 'foo'}],
            ['else', {text: 'bar'}],
          ],
        }),
    );
  });

  describe('can add', () => {
    beforeEach(() => void (node = new IfExpression({nodes: []})));

    it('a single entry', () => {
      const entry = new IfEntry({
        condition: {value: true},
        value: {text: 'foo'},
      });
      node.append(entry);
      expect(node.nodes[0]).toBe(entry);
      expect(entry.parent).toBe(node);
    });

    it('a list of entries', () => {
      const entry1 = new IfEntry({
        condition: {value: true},
        value: {text: 'foo'},
      });
      const entry2 = new IfEntry({condition: 'else', value: {text: 'bar'}});
      node.append([entry1, entry2]);
      expect(node.nodes[0]).toBe(entry1);
      expect(node.nodes[1]).toBe(entry2);
      expect(entry1.parent).toBe(node);
      expect(entry2.parent).toBe(node);
    });

    it("a single entry's properties as an object", () => {
      node.append({condition: {value: true}, value: {text: 'foo'}});
      expect(node.nodes[0].parent).toBe(node);
      expect(node.nodes[0]).toHaveNode('condition', 'sass(true)');
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
    });

    it("a single entry's properties as a list", () => {
      node.append([{value: true}, {text: 'foo'}]);
      expect(node.nodes[0].parent).toBe(node);
      expect(node.nodes[0]).toHaveNode('condition', 'sass(true)');
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
    });

    it('a list of entry properties as objects', () => {
      node.append([
        {condition: {value: true}, value: {text: 'foo'}},
        {condition: 'else', value: {text: 'bar'}},
      ]);
      expect(node.nodes[0].parent).toBe(node);
      expect(node.nodes[0]).toHaveNode('condition', 'sass(true)');
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[1].parent).toBe(node);
      expect(node.nodes[1].condition).toBe('else');
      expect(node.nodes[1]).toHaveStringExpression('value', 'bar');
    });

    it('a list of entry properties as lists', () => {
      node.append([
        [{value: true}, {text: 'foo'}],
        ['else', {text: 'bar'}],
      ]);
      expect(node.nodes[0].parent).toBe(node);
      expect(node.nodes[0]).toHaveNode('condition', 'sass(true)');
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[1].parent).toBe(node);
      expect(node.nodes[1].condition).toBe('else');
      expect(node.nodes[1]).toHaveStringExpression('value', 'bar');
    });

    it('undefined', () => {
      node.append(undefined);
      expect(node.nodes).toHaveLength(0);
    });
  });

  describe('append', () => {
    beforeEach(
      () =>
        void (node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'qux'}],
          ],
        })),
    );

    it('adds multiple children to the end', () => {
      node.append(
        [{variableName: 'zip'}, {text: 'zap'}],
        [{variableName: 'zop'}, {text: 'zoop'}],
      );
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($zip)');
      expect(node.nodes[2]).toHaveStringExpression('value', 'zap');
      expect(node.nodes[3]).toHaveNode('condition', 'sass($zop)');
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
        () => node.append([{variableName: 'zip'}, {text: 'zap'}]),
      ));

    it('returns itself', () => expect(node.append()).toBe(node));
  });

  describe('each', () => {
    beforeEach(
      () =>
        void (node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'qux'}],
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
        void (node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'bang'}],
            [{variableName: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('returns true if the callback returns true for all elements', () =>
      expect(node.every(() => true)).toBe(true));

    it('returns false if the callback returns false for any element', () =>
      expect(
        node.every(
          element =>
            (element.condition as IfConditionSass).toString() !== 'sass($baz)',
        ),
      ).toBe(false));
  });

  describe('index', () => {
    beforeEach(
      () =>
        void (node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'bang'}],
            [{variableName: 'zip'}, {text: 'zap'}],
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
        void (node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'bang'}],
            [{variableName: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('inserts a node after the given element', () => {
      node.insertAfter(node.nodes[1], [{variableName: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($zop)');
      expect(node.nodes[2]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[3]).toHaveNode('condition', 'sass($zip)');
    });

    it('inserts a node at the beginning', () => {
      node.insertAfter(-1, [{variableName: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($zop)');
      expect(node.nodes[0]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[3]).toHaveNode('condition', 'sass($zip)');
    });

    it('inserts a node at the end', () => {
      node.insertAfter(3, [{variableName: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($zip)');
      expect(node.nodes[3]).toHaveNode('condition', 'sass($zop)');
      expect(node.nodes[3]).toHaveStringExpression('value', 'zoop');
    });

    it('inserts multiple nodes', () => {
      node.insertAfter(1, [
        [{variableName: 'zop'}, {text: 'zoop'}],
        [{variableName: 'flip'}, {text: 'flap'}],
      ]);
      expect(node.nodes).toHaveLength(5);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($zop)');
      expect(node.nodes[2]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[3]).toHaveNode('condition', 'sass($flip)');
      expect(node.nodes[3]).toHaveStringExpression('value', 'flap');
      expect(node.nodes[4]).toHaveNode('condition', 'sass($zip)');
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
            [{variableName: 'zop'}, {text: 'zoop'}],
            [{variableName: 'qux'}, {text: 'qax'}],
            [{variableName: 'flip'}, {text: 'flap'}],
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
            [{variableName: 'zop'}, {text: 'zoop'}],
            [{variableName: 'qux'}, {text: 'qax'}],
            [{variableName: 'flip'}, {text: 'flap'}],
          ]),
      ));

    it('returns itself', () =>
      expect(
        node.insertAfter(node.nodes[0], [{variableName: 'qux'}, {text: 'qax'}]),
      ).toBe(node));
  });

  describe('insertBefore', () => {
    beforeEach(
      () =>
        void (node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'bang'}],
            [{variableName: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('inserts a node before the given element', () => {
      node.insertBefore(node.nodes[1], [{variableName: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($zop)');
      expect(node.nodes[1]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[3]).toHaveNode('condition', 'sass($zip)');
    });

    it('inserts a node at the beginning', () => {
      node.insertBefore(0, [{variableName: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($zop)');
      expect(node.nodes[0]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[3]).toHaveNode('condition', 'sass($zip)');
    });

    it('inserts a node at the end', () => {
      node.insertBefore(4, [{variableName: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($zip)');
      expect(node.nodes[3]).toHaveNode('condition', 'sass($zop)');
      expect(node.nodes[3]).toHaveStringExpression('value', 'zoop');
    });

    it('inserts multiple nodes', () => {
      node.insertBefore(1, [
        [{variableName: 'zop'}, {text: 'zoop'}],
        [{variableName: 'flip'}, {text: 'flap'}],
      ]);
      expect(node.nodes).toHaveLength(5);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($zop)');
      expect(node.nodes[1]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($flip)');
      expect(node.nodes[2]).toHaveStringExpression('value', 'flap');
      expect(node.nodes[3]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[4]).toHaveNode('condition', 'sass($zip)');
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
            [{variableName: 'zop'}, {text: 'zoop'}],
            [{variableName: 'qux'}, {text: 'qax'}],
            [{variableName: 'flip'}, {text: 'flap'}],
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
            [{variableName: 'zop'}, {text: 'zoop'}],
            [{variableName: 'qux'}, {text: 'qax'}],
            [{variableName: 'flip'}, {text: 'flap'}],
          ]),
      ));

    it('returns itself', () =>
      expect(
        node.insertBefore(node.nodes[0], [
          {variableName: 'qux'},
          {text: 'qax'},
        ]),
      ).toBe(node));
  });

  describe('prepend', () => {
    beforeEach(
      () =>
        void (node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'bang'}],
            [{variableName: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('inserts one node', () => {
      node.prepend([{variableName: 'zop'}, {text: 'zoop'}]);
      expect(node.nodes).toHaveLength(4);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($zop)');
      expect(node.nodes[0]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[3]).toHaveNode('condition', 'sass($zip)');
    });

    it('inserts multiple nodes', () => {
      node.prepend([
        [{variableName: 'zop'}, {text: 'zoop'}],
        [{variableName: 'flip'}, {text: 'flap'}],
      ]);
      expect(node.nodes).toHaveLength(5);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($zop)');
      expect(node.nodes[0]).toHaveStringExpression('value', 'zoop');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($flip)');
      expect(node.nodes[1]).toHaveStringExpression('value', 'flap');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[3]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[4]).toHaveNode('condition', 'sass($zip)');
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
            [{variableName: 'zop'}, {text: 'zoop'}],
            [{variableName: 'qux'}, {text: 'qax'}],
            [{variableName: 'flip'}, {text: 'flap'}],
          ),
      ));

    it('returns itself', () =>
      expect(node.prepend([{variableName: 'qux'}, {text: 'qax'}])).toBe(node));
  });

  describe('push', () => {
    beforeEach(
      () =>
        void (node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'bang'}],
          ],
        })),
    );

    it('inserts one node', () => {
      node.push(new IfEntry([{variableName: 'zip'}, {text: 'zap'}]));
      expect(node.nodes).toHaveLength(3);
      expect(node.nodes[0]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($baz)');
      expect(node.nodes[2]).toHaveNode('condition', 'sass($zip)');
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
        () => node.push(new IfEntry([{variableName: 'zip'}, {text: 'zap'}])),
      ));

    it('returns itself', () =>
      expect(
        node.push(new IfEntry([{variableName: 'zip'}, {text: 'zap'}])),
      ).toBe(node));
  });

  describe('removeAll', () => {
    beforeEach(
      () =>
        void (node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'bang'}],
            [{variableName: 'zip'}, {text: 'zap'}],
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
        void (node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'bang'}],
            [{variableName: 'zip'}, {text: 'zap'}],
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
      expect(node.nodes[0]).toHaveNode('condition', 'sass($foo)');
      expect(node.nodes[1]).toHaveNode('condition', 'sass($zip)');
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
        void (node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'bang'}],
            [{variableName: 'zip'}, {text: 'zap'}],
          ],
        })),
    );

    it('returns false if the callback returns false for all elements', () =>
      expect(node.some(() => false)).toBe(false));

    it('returns true if the callback returns true for any element', () =>
      expect(
        node.some(
          element =>
            (element.condition as IfConditionSass).toString() !== '$baz',
        ),
      ).toBe(true));
  });

  describe('first', () => {
    it('returns the first element', () =>
      expect(
        new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'bang'}],
            [{variableName: 'zip'}, {text: 'zap'}],
          ],
        }).first,
      ).toHaveNode('condition', 'sass($foo)'));

    it('returns undefined for an empty if()', () =>
      expect(new IfExpression({nodes: []}).first).toBeUndefined());
  });

  describe('last', () => {
    it('returns the last element', () =>
      expect(
        new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'baz'}, {text: 'bang'}],
            [{variableName: 'zip'}, {text: 'zap'}],
          ],
        }).last,
      ).toHaveNode('condition', 'sass($zip)'));

    it('returns undefined for an empty interpolation', () =>
      expect(new IfExpression({nodes: []}).last).toBeUndefined());
  });

  describe('stringifies', () => {
    describe('empty', () => {
      beforeEach(() => {
        node = new IfExpression({nodes: []});
      });

      it('with default raws', () => expect(node.toString()).toBe('if()'));

      it('with afterOpen', () => {
        node.raws.afterOpen = '/**/';
        expect(node.toString()).toBe('if(/**/)');
      });

      it('with beforeClose', () => {
        node.raws.beforeClose = '/**/';
        expect(node.toString()).toBe('if(/**/)');
      });

      it('with afterOpen and beforeClose', () => {
        node.raws.afterOpen = '/**/';
        node.raws.beforeClose = '  ';
        expect(node.toString()).toBe('if(/**/  )');
      });

      it('ignores trailingSemicolon', () => {
        node.raws.trailingSemi = true;
        expect(node.toString()).toBe('if()');
      });
    });

    describe('one pair', () => {
      beforeEach(() => {
        node = new IfExpression({
          nodes: [[{variableName: 'foo'}, {text: 'bar'}]],
        });
      });

      it('with default raws', () =>
        expect(node.toString()).toBe('if(sass($foo): bar)'));

      describe('with afterOpen', () => {
        it('on its own', () => {
          node.raws.afterOpen = '/**/';
          expect(node.toString()).toBe('if(/**/sass($foo): bar)');
        });

        it('and nodes.before', () => {
          node.raws.afterOpen = '/**/';
          node.first!.raws.before = '  ';
          expect(node.toString()).toBe('if(/**/  sass($foo): bar)');
        });
      });

      describe('with afterClose', () => {
        it('on its own', () => {
          node.raws.beforeClose = '/**/';
          expect(node.toString()).toBe('if(sass($foo): bar/**/)');
        });

        it('and nodes.after', () => {
          node.raws.beforeClose = '/**/';
          node.last!.raws.after = '  ';
          expect(node.toString()).toBe('if(sass($foo): bar  /**/)');
        });
      });

      describe('with trailingSemi', () => {
        it('on its own', () => {
          node.raws.trailingSemi = true;
          expect(node.toString()).toBe('if(sass($foo): bar;)');
        });

        it('and nodes.after', () => {
          node.raws.trailingSemi = true;
          node.last!.raws.after = '  ';
          expect(node.toString()).toBe('if(sass($foo): bar  ;)');
        });

        it('and beforeClose', () => {
          node.raws.trailingSemi = true;
          node.raws.beforeClose = '  ';
          expect(node.toString()).toBe('if(sass($foo): bar;  )');
        });
      });
    });

    describe('multiple pairs', () => {
      beforeEach(() => {
        node = new IfExpression({
          nodes: [
            [{variableName: 'foo'}, {text: 'bar'}],
            [{variableName: 'zip'}, {text: 'zap'}],
          ],
        });
      });

      it('with default raws', () =>
        expect(node.toString()).toBe('if(sass($foo): bar; sass($zip): zap)'));

      it('with nodes.after', () => {
        node.first!.raws.after = '  ';
        expect(node.toString()).toBe('if(sass($foo): bar  ; sass($zip): zap)');
      });

      it('with nodes.before', () => {
        node.last!.raws.before = '  ';
        expect(node.toString()).toBe('if(sass($foo): bar;  sass($zip): zap)');
      });
    });
  });

  describe('clone', () => {
    let original: IfExpression;

    beforeEach(() => {
      original = utils.parseExpression('if(sass($foo): bar; sass($baz): bang)');
      // TODO: remove this once raws are properly parsed.
      original.raws.afterOpen = '  ';
    });

    describe('with no overrides', () => {
      let clone: IfExpression;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('nodes', () => {
          expect(clone.nodes).toHaveLength(2);
          expect(clone.nodes[0]).toHaveNode('condition', 'sass($foo)');
          expect(clone.nodes[0]).toHaveStringExpression('value', 'bar');
          expect(clone.nodes[1]).toHaveNode('condition', 'sass($baz)');
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
            nodes: [[{variableName: 'zip'}, {text: 'zap'}]],
          });
          expect(clone.nodes).toHaveLength(1);
          expect(clone.nodes[0]).toHaveNode('condition', 'sass($zip)');
          expect(clone.nodes[0]).toHaveStringExpression('value', 'zap');
        });

        it('undefined', () => {
          const clone = original.clone({nodes: undefined});
          expect(clone.nodes).toHaveLength(2);
          expect(clone.nodes[0]).toHaveNode('condition', 'sass($foo)');
          expect(clone.nodes[1]).toHaveNode('condition', 'sass($baz)');
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
    expect(
      utils.parseExpression('if(sass($foo): bar; else: baz)'),
    ).toMatchSnapshot());
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
    const [[variableName, value], index] = Array.isArray(element[0])
      ? element
      : [element, i];
    expect(fn).toHaveBeenNthCalledWith(
      i + 1,
      expect.objectContaining({
        condition: expect.objectContaining({
          expression: expect.objectContaining({variableName}),
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
