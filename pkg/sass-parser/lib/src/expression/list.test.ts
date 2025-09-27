// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {ListExpression, StringExpression} from '../..';
import * as utils from '../../../test/utils';

type EachFn = Parameters<ListExpression['each']>[0];

let node: ListExpression;
describe('a list expression', () => {
  describe('empty', () => {
    describe('without brackets', () => {
      function describeNode(
        description: string,
        create: () => ListExpression,
      ): void {
        describe(description, () => {
          beforeEach(() => void (node = create()));

          it('has sassType list', () => expect(node.sassType).toBe('list'));

          it('has no brackets', () => expect(node.brackets).toBe(false));

          it('has an unknown separator', () =>
            expect(node.separator).toBe(null));

          it('is empty', () => expect(node.nodes).toHaveLength(0));
        });
      }

      describeNode('parsed', () => utils.parseExpression('()'));

      describeNode(
        'constructed manually',
        () => new ListExpression({separator: null, nodes: []}),
      );

      describeNode('constructed from ExpressionProps', () =>
        utils.fromExpressionProps({separator: null, nodes: []}),
      );
    });

    describe('with brackets', () => {
      function describeNode(
        description: string,
        create: () => ListExpression,
      ): void {
        describe(description, () => {
          beforeEach(() => void (node = create()));

          it('has sassType list', () => expect(node.sassType).toBe('list'));

          it('has brackets', () => expect(node.brackets).toBe(true));

          it('is empty', () => expect(node.nodes).toHaveLength(0));
        });
      }

      describeNode('parsed', () => utils.parseExpression('[]'));

      describeNode(
        'constructed manually',
        () => new ListExpression({separator: null, brackets: true, nodes: []}),
      );

      describeNode('constructed from ExpressionProps', () =>
        utils.fromExpressionProps({
          separator: null,
          brackets: true,
          nodes: [],
        }),
      );
    });
  });

  describe('with one element ', () => {
    describe('without brackets', () => {
      describe('with a comma separator', () => {
        function describeNode(
          description: string,
          create: () => ListExpression,
        ): void {
          describe(description, () => {
            beforeEach(() => void (node = create()));

            it('has sassType list', () => expect(node.sassType).toBe('list'));

            it('has no brackets', () => expect(node.brackets).toBe(false));

            it('has a comma separator', () => expect(node.separator).toBe(','));

            it('has an element', () => {
              expect(node.nodes).toHaveLength(1);
              expect(node).toHaveStringExpression(0, 'foo');
            });
          });
        }

        describeNode('parsed', () => utils.parseExpression('foo,'));

        describeNode(
          'constructed manually',
          () => new ListExpression({separator: ',', nodes: [{text: 'foo'}]}),
        );

        describeNode('constructed from ExpressionProps', () =>
          utils.fromExpressionProps({separator: ',', nodes: [{text: 'foo'}]}),
        );
      });
    });

    describe('with brackets', () => {
      describe('with an unknown separator', () => {
        function describeNode(
          description: string,
          create: () => ListExpression,
        ): void {
          describe(description, () => {
            beforeEach(() => void (node = create()));

            it('has sassType list', () => expect(node.sassType).toBe('list'));

            it('has brackets', () => expect(node.brackets).toBe(true));

            it('has an unknown separator', () =>
              expect(node.separator).toBe(null));

            it('has an element', () => {
              expect(node.nodes).toHaveLength(1);
              expect(node).toHaveStringExpression(0, 'foo');
            });
          });
        }

        describeNode('parsed', () => utils.parseExpression('[foo]'));

        describeNode(
          'constructed manually',
          () =>
            new ListExpression({
              separator: null,
              brackets: true,
              nodes: [{text: 'foo'}],
            }),
        );

        describeNode('constructed from ExpressionProps', () =>
          utils.fromExpressionProps({
            separator: null,
            brackets: true,
            nodes: [{text: 'foo'}],
          }),
        );
      });

      describe('with a comma separator', () => {
        function describeNode(
          description: string,
          create: () => ListExpression,
        ): void {
          describe(description, () => {
            beforeEach(() => void (node = create()));

            it('has sassType list', () => expect(node.sassType).toBe('list'));

            it('has brackets', () => expect(node.brackets).toBe(true));

            it('has a comma separator', () => expect(node.separator).toBe(','));

            it('has an element', () => {
              expect(node.nodes).toHaveLength(1);
              expect(node).toHaveStringExpression(0, 'foo');
            });
          });
        }

        describeNode('parsed', () => utils.parseExpression('[foo,]'));

        describeNode(
          'constructed manually',
          () =>
            new ListExpression({
              separator: ',',
              brackets: true,
              nodes: [{text: 'foo'}],
            }),
        );

        describeNode('constructed from ExpressionProps', () =>
          utils.fromExpressionProps({
            separator: ',',
            brackets: true,
            nodes: [{text: 'foo'}],
          }),
        );
      });
    });
  });

  describe('with multiple elements ', () => {
    describe('without brackets', () => {
      describe('with a space separator', () => {
        function describeNode(
          description: string,
          create: () => ListExpression,
        ): void {
          describe(description, () => {
            beforeEach(() => void (node = create()));

            it('has sassType list', () => expect(node.sassType).toBe('list'));

            it('has no brackets', () => expect(node.brackets).toBe(false));

            it('has a space separator', () => expect(node.separator).toBe(' '));

            it('has elements', () => {
              expect(node.nodes).toHaveLength(2);
              expect(node).toHaveStringExpression(0, 'foo');
              expect(node).toHaveStringExpression(1, 'bar');
            });
          });
        }

        describeNode('parsed', () => utils.parseExpression('foo bar'));

        describeNode(
          'constructed manually',
          () =>
            new ListExpression({
              separator: ' ',
              nodes: [{text: 'foo'}, {text: 'bar'}],
            }),
        );

        describeNode('constructed from ExpressionProps', () =>
          utils.fromExpressionProps({
            separator: ' ',
            nodes: [{text: 'foo'}, {text: 'bar'}],
          }),
        );
      });

      describe('with a comma separator', () => {
        function describeNode(
          description: string,
          create: () => ListExpression,
        ): void {
          describe(description, () => {
            beforeEach(() => void (node = create()));

            it('has sassType list', () => expect(node.sassType).toBe('list'));

            it('has no brackets', () => expect(node.brackets).toBe(false));

            it('has a comma separator', () => expect(node.separator).toBe(','));

            it('has elements', () => {
              expect(node.nodes).toHaveLength(2);
              expect(node).toHaveStringExpression(0, 'foo');
              expect(node).toHaveStringExpression(1, 'bar');
            });
          });
        }

        describeNode('parsed', () => utils.parseExpression('foo, bar'));

        describeNode(
          'constructed manually',
          () =>
            new ListExpression({
              separator: ',',
              nodes: [{text: 'foo'}, {text: 'bar'}],
            }),
        );

        describeNode('constructed from ExpressionProps', () =>
          utils.fromExpressionProps({
            separator: ',',
            nodes: [{text: 'foo'}, {text: 'bar'}],
          }),
        );
      });

      describe('with a slash separator', () => {
        function describeNode(
          description: string,
          create: () => ListExpression,
        ): void {
          describe(description, () => {
            beforeEach(() => void (node = create()));

            it('has sassType list', () => expect(node.sassType).toBe('list'));

            it('has no brackets', () => expect(node.brackets).toBe(false));

            it('has a slash separator', () => expect(node.separator).toBe('/'));

            it('has elements', () => {
              expect(node.nodes).toHaveLength(2);
              expect(node).toHaveStringExpression(0, 'foo');
              expect(node).toHaveStringExpression(1, 'bar');
            });
          });
        }

        // TODO: Enable this once slash separators aren't parsed as division.
        // describeNode('parsed', () => utils.parseExpression('foo / bar'));

        describeNode(
          'constructed manually',
          () =>
            new ListExpression({
              separator: '/',
              nodes: [{text: 'foo'}, {text: 'bar'}],
            }),
        );

        describeNode('constructed from ExpressionProps', () =>
          utils.fromExpressionProps({
            separator: '/',
            nodes: [{text: 'foo'}, {text: 'bar'}],
          }),
        );
      });
    });

    describe('with brackets', () => {
      describe('with a space separator', () => {
        function describeNode(
          description: string,
          create: () => ListExpression,
        ): void {
          describe(description, () => {
            beforeEach(() => void (node = create()));

            it('has sassType list', () => expect(node.sassType).toBe('list'));

            it('has brackets', () => expect(node.brackets).toBe(true));

            it('has a space separator', () => expect(node.separator).toBe(' '));

            it('has elements', () => {
              expect(node.nodes).toHaveLength(2);
              expect(node).toHaveStringExpression(0, 'foo');
              expect(node).toHaveStringExpression(1, 'bar');
            });
          });
        }

        describeNode('parsed', () => utils.parseExpression('[foo bar]'));

        describeNode(
          'constructed manually',
          () =>
            new ListExpression({
              separator: ' ',
              brackets: true,
              nodes: [{text: 'foo'}, {text: 'bar'}],
            }),
        );

        describeNode('constructed from ExpressionProps', () =>
          utils.fromExpressionProps({
            separator: ' ',
            brackets: true,
            nodes: [{text: 'foo'}, {text: 'bar'}],
          }),
        );
      });

      describe('with a comma separator', () => {
        function describeNode(
          description: string,
          create: () => ListExpression,
        ): void {
          describe(description, () => {
            beforeEach(() => void (node = create()));

            it('has sassType list', () => expect(node.sassType).toBe('list'));

            it('has brackets', () => expect(node.brackets).toBe(true));

            it('has a comma separator', () => expect(node.separator).toBe(','));

            it('has elements', () => {
              expect(node.nodes).toHaveLength(2);
              expect(node).toHaveStringExpression(0, 'foo');
              expect(node).toHaveStringExpression(1, 'bar');
            });
          });
        }

        describeNode('parsed', () => utils.parseExpression('[foo, bar]'));

        describeNode(
          'constructed manually',
          () =>
            new ListExpression({
              separator: ',',
              brackets: true,
              nodes: [{text: 'foo'}, {text: 'bar'}],
            }),
        );

        describeNode('constructed from ExpressionProps', () =>
          utils.fromExpressionProps({
            separator: ',',
            brackets: true,
            nodes: [{text: 'foo'}, {text: 'bar'}],
          }),
        );
      });

      describe('with a slash separator', () => {
        function describeNode(
          description: string,
          create: () => ListExpression,
        ): void {
          describe(description, () => {
            beforeEach(() => void (node = create()));

            it('has sassType list', () => expect(node.sassType).toBe('list'));

            it('has brackets', () => expect(node.brackets).toBe(true));

            it('has a slash separator', () => expect(node.separator).toBe('/'));

            it('has elements', () => {
              expect(node.nodes).toHaveLength(2);
              expect(node).toHaveStringExpression(0, 'foo');
              expect(node).toHaveStringExpression(1, 'bar');
            });
          });
        }

        // TODO: Enable this once slash separators aren't parsed as division.
        // describeNode('parsed', () => utils.parseExpression('[foo / bar]'));

        describeNode(
          'constructed manually',
          () =>
            new ListExpression({
              separator: '/',
              brackets: true,
              nodes: [{text: 'foo'}, {text: 'bar'}],
            }),
        );

        describeNode('constructed from ExpressionProps', () =>
          utils.fromExpressionProps({
            separator: '/',
            brackets: true,
            nodes: [{text: 'foo'}, {text: 'bar'}],
          }),
        );
      });
    });
  });

  describe('assigned new', () => {
    beforeEach(() => void (node = utils.parseExpression('[1, 2, 3]')));

    it('separator', () => {
      node.separator = ' ';
      expect(node.separator).toBe(' ');
    });

    it('brackets', () => {
      node.brackets = false;
      expect(node.brackets).toBe(false);
    });
  });

  describe('can add', () => {
    beforeEach(() => void (node = utils.parseExpression('[]')));

    it('a single expression', () => {
      const string = new StringExpression({text: 'foo'});
      node.append(string);
      expect(node.nodes[0]).toBe(string);
      expect(string.parent).toBe(node);
    });

    it('a list of expressions', () => {
      const string1 = new StringExpression({text: 'foo'});
      const string2 = new StringExpression({text: 'bar'});
      node.append([string1, string2]);
      expect(node.nodes[0]).toBe(string1);
      expect(node.nodes[1]).toBe(string2);
      expect(string1.parent).toBe(node);
      expect(string2.parent).toBe(node);
    });

    it("a single expression's properties", () => {
      node.append({text: 'foo'});
      expect(node).toHaveStringExpression(0, 'foo');
    });

    it('a list of properties', () => {
      node.append([{text: 'foo'}, {text: 'bar'}]);
      expect(node).toHaveStringExpression(0, 'foo');
      expect(node).toHaveStringExpression(1, 'bar');
    });

    it('undefined', () => {
      node.append(undefined);
      expect(node.nodes).toHaveLength(0);
    });
  });

  describe('append', () => {
    beforeEach(
      () =>
        void (node = new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}],
        })),
    );

    it('adds multiple children to the end', () => {
      node.append({text: 'baz'}, {text: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveStringExpression(0, 'foo');
      expect(node).toHaveStringExpression(1, 'bar');
      expect(node).toHaveStringExpression(2, 'baz');
      expect(node).toHaveStringExpression(3, 'qux');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () =>
        node.append({text: 'baz'}),
      ));

    it('returns itself', () => expect(node.append()).toBe(node));
  });

  describe('each', () => {
    beforeEach(
      () =>
        void (node = new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}],
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
        void (node = new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
        })),
    );

    it('returns true if the callback returns true for all elements', () =>
      expect(node.every(() => true)).toBe(true));

    it('returns false if the callback returns false for any element', () =>
      expect(
        node.every(
          element => (element as StringExpression).text.asPlain !== 'bar',
        ),
      ).toBe(false));
  });

  describe('index', () => {
    beforeEach(
      () =>
        void (node = new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}, {text: 'qux'}],
        })),
    );

    it('returns the first index of a given expression', () =>
      expect(node.index(node.nodes[2])).toBe(2));

    it('returns a number as-is', () => expect(node.index(3)).toBe(3));
  });

  describe('insertAfter', () => {
    beforeEach(
      () =>
        void (node = new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
        })),
    );

    it('inserts a node after the given element', () => {
      node.insertAfter(node.nodes[1], {text: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveStringExpression(0, 'foo');
      expect(node).toHaveStringExpression(1, 'bar');
      expect(node).toHaveStringExpression(2, 'qux');
      expect(node).toHaveStringExpression(3, 'baz');
    });

    it('inserts a node at the beginning', () => {
      node.insertAfter(-1, {text: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveStringExpression(0, 'qux');
      expect(node).toHaveStringExpression(1, 'foo');
      expect(node).toHaveStringExpression(2, 'bar');
      expect(node).toHaveStringExpression(3, 'baz');
    });

    it('inserts a node at the end', () => {
      node.insertAfter(3, {text: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveStringExpression(0, 'foo');
      expect(node).toHaveStringExpression(1, 'bar');
      expect(node).toHaveStringExpression(2, 'baz');
      expect(node).toHaveStringExpression(3, 'qux');
    });

    it('inserts multiple nodes', () => {
      node.insertAfter(1, [{text: 'qux'}, {text: 'qax'}, {text: 'qix'}]);
      expect(node.nodes).toHaveLength(6);
      expect(node).toHaveStringExpression(0, 'foo');
      expect(node).toHaveStringExpression(1, 'bar');
      expect(node).toHaveStringExpression(2, 'qux');
      expect(node).toHaveStringExpression(3, 'qax');
      expect(node).toHaveStringExpression(4, 'qix');
      expect(node).toHaveStringExpression(5, 'baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertAfter(0, [{text: 'qux'}, {text: 'qax'}, {text: 'qix'}]),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertAfter(1, [{text: 'qux'}, {text: 'qax'}, {text: 'qix'}]),
      ));

    it('returns itself', () =>
      expect(node.insertAfter(node.nodes[0], {text: 'qux'})).toBe(node));
  });

  describe('insertBefore', () => {
    beforeEach(
      () =>
        void (node = new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
        })),
    );

    it('inserts a node before the given element', () => {
      node.insertBefore(node.nodes[1], {text: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveStringExpression(0, 'foo');
      expect(node).toHaveStringExpression(1, 'qux');
      expect(node).toHaveStringExpression(2, 'bar');
      expect(node).toHaveStringExpression(3, 'baz');
    });

    it('inserts a node at the beginning', () => {
      node.insertBefore(0, {text: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveStringExpression(0, 'qux');
      expect(node).toHaveStringExpression(1, 'foo');
      expect(node).toHaveStringExpression(2, 'bar');
      expect(node).toHaveStringExpression(3, 'baz');
    });

    it('inserts a node at the end', () => {
      node.insertBefore(4, {text: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveStringExpression(0, 'foo');
      expect(node).toHaveStringExpression(1, 'bar');
      expect(node).toHaveStringExpression(2, 'baz');
      expect(node).toHaveStringExpression(3, 'qux');
    });

    it('inserts multiple nodes', () => {
      node.insertBefore(1, [{text: 'qux'}, {text: 'qax'}, {text: 'qix'}]);
      expect(node.nodes).toHaveLength(6);
      expect(node).toHaveStringExpression(0, 'foo');
      expect(node).toHaveStringExpression(1, 'qux');
      expect(node).toHaveStringExpression(2, 'qax');
      expect(node).toHaveStringExpression(3, 'qix');
      expect(node).toHaveStringExpression(4, 'bar');
      expect(node).toHaveStringExpression(5, 'baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertBefore(1, [{text: 'qux'}, {text: 'qax'}, {text: 'qix'}]),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertBefore(2, [{text: 'qux'}, {text: 'qax'}, {text: 'qix'}]),
      ));

    it('returns itself', () =>
      expect(node.insertBefore(node.nodes[0], {text: 'qux'})).toBe(node));
  });

  describe('prepend', () => {
    beforeEach(
      () =>
        void (node = new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
        })),
    );

    it('inserts one node', () => {
      node.prepend({text: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveStringExpression(0, 'qux');
      expect(node).toHaveStringExpression(1, 'foo');
      expect(node).toHaveStringExpression(2, 'bar');
      expect(node).toHaveStringExpression(3, 'baz');
    });

    it('inserts multiple nodes', () => {
      node.prepend({text: 'qux'}, {text: 'qax'}, {text: 'qix'});
      expect(node.nodes).toHaveLength(6);
      expect(node).toHaveStringExpression(0, 'qux');
      expect(node).toHaveStringExpression(1, 'qax');
      expect(node).toHaveStringExpression(2, 'qix');
      expect(node).toHaveStringExpression(3, 'foo');
      expect(node).toHaveStringExpression(4, 'bar');
      expect(node).toHaveStringExpression(5, 'baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.prepend({text: 'qux'}, {text: 'qax'}, {text: 'qix'}),
      ));

    it('returns itself', () => expect(node.prepend({text: 'qux'})).toBe(node));
  });

  describe('push', () => {
    beforeEach(
      () =>
        void (node = new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}],
        })),
    );

    it('inserts one node', () => {
      node.push(new StringExpression({text: 'baz'}));
      expect(node.nodes).toHaveLength(3);
      expect(node).toHaveStringExpression(0, 'foo');
      expect(node).toHaveStringExpression(1, 'bar');
      expect(node).toHaveStringExpression(2, 'baz');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () =>
        node.push(new StringExpression({text: 'baz'})),
      ));

    it('returns itself', () =>
      expect(node.push(new StringExpression({text: 'baz'}))).toBe(node));
  });

  describe('removeAll', () => {
    beforeEach(
      () =>
        void (node = new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
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
      testEachMutation(['foo'], 0, () => node.removeAll()));

    it('returns itself', () => expect(node.removeAll()).toBe(node));
  });

  describe('removeChild', () => {
    beforeEach(
      () =>
        void (node = new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
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
      expect(node).toHaveStringExpression(0, 'foo');
      expect(node).toHaveStringExpression(1, 'baz');
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
        void (node = new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
        })),
    );

    it('returns false if the callback returns false for all elements', () =>
      expect(node.some(() => false)).toBe(false));

    it('returns true if the callback returns true for any element', () =>
      expect(
        node.some(
          element => (element as StringExpression).text.asPlain === 'bar',
        ),
      ).toBe(true));
  });

  describe('first', () => {
    it('returns the first element', () =>
      expect(
        new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
        }),
      ).toHaveStringExpression('first', 'foo'));

    it('returns undefined for an empty list', () =>
      expect(
        new ListExpression({separator: null, nodes: []}).first,
      ).toBeUndefined());
  });

  describe('last', () => {
    it('returns the last element', () =>
      expect(
        new ListExpression({
          separator: ',',
          nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
        }),
      ).toHaveStringExpression('last', 'baz'));

    it('returns undefined for an empty list', () =>
      expect(
        new ListExpression({separator: null, nodes: []}).last,
      ).toBeUndefined());
  });

  describe('stringifies', () => {
    describe('with default raws', () => {
      describe('empty', () => {
        describe('unbracketed', () => {
          it('with an unknown separator', () =>
            expect(
              new ListExpression({separator: null, nodes: []}).toString(),
            ).toBe('()'));

          it('with an unsupported separator', () =>
            expect(
              new ListExpression({separator: '/', nodes: []}).toString(),
            ).toBe('()'));
        });

        describe('bracketed', () => {
          it('with an unknown separator', () =>
            expect(
              new ListExpression({
                separator: null,
                brackets: true,
                nodes: [],
              }).toString(),
            ).toBe('[]'));

          it('with an unsupported separator', () =>
            expect(
              new ListExpression({
                separator: '/',
                brackets: true,
                nodes: [],
              }).toString(),
            ).toBe('[]'));

          it('with a comma separator', () =>
            expect(
              new ListExpression({
                separator: ',',
                brackets: true,
                nodes: [],
              }).toString(),
            ).toBe('[,]'));
        });
      });

      describe('with one element', () => {
        describe('unbracketed', () => {
          it('with an unknown separator', () =>
            expect(
              new ListExpression({
                separator: null,
                nodes: [{text: 'foo'}],
              }).toString(),
            ).toBe('foo'));

          it('with an unsupported separator', () =>
            expect(
              new ListExpression({
                separator: '/',
                nodes: [{text: 'foo'}],
              }).toString(),
            ).toBe('foo'));

          it('with a comma separator', () =>
            expect(
              new ListExpression({
                separator: ',',
                nodes: [{text: 'foo'}],
              }).toString(),
            ).toBe('foo,'));
        });

        describe('bracketed', () => {
          it('with an unknown separator', () =>
            expect(
              new ListExpression({
                separator: null,
                brackets: true,
                nodes: [{text: 'foo'}],
              }).toString(),
            ).toBe('[foo]'));

          it('with an unsupported separator', () =>
            expect(
              new ListExpression({
                separator: '/',
                brackets: true,
                nodes: [{text: 'foo'}],
              }).toString(),
            ).toBe('[foo]'));

          it('with a comma separator', () =>
            expect(
              new ListExpression({
                separator: ',',
                brackets: true,
                nodes: [{text: 'foo'}],
              }).toString(),
            ).toBe('[foo,]'));
        });
      });

      describe('with multiple elements', () => {
        describe('unbracketed', () => {
          it('with an unknown separator', () =>
            expect(
              new ListExpression({
                separator: null,
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo bar'));

          it('with a space separator', () =>
            expect(
              new ListExpression({
                separator: ' ',
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo bar'));

          it('with a slash separator', () =>
            expect(
              new ListExpression({
                separator: '/',
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo / bar'));

          it('with a comma separator', () =>
            expect(
              new ListExpression({
                separator: ',',
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo, bar'));
        });

        describe('bracketed', () => {
          it('with an unknown separator', () =>
            expect(
              new ListExpression({
                separator: null,
                brackets: true,
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('[foo bar]'));

          it('with a space separator', () =>
            expect(
              new ListExpression({
                separator: ' ',
                brackets: true,
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('[foo bar]'));

          it('with a slash separator', () =>
            expect(
              new ListExpression({
                separator: '/',
                brackets: true,
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('[foo / bar]'));

          it('with a comma separator', () =>
            expect(
              new ListExpression({
                separator: ',',
                brackets: true,
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('[foo, bar]'));
        });
      });
    });

    describe('afterOpen', () => {
      describe('empty', () => {
        it('no separator', () =>
          expect(
            new ListExpression({
              separator: null,
              raws: {afterOpen: '/**/'},
              nodes: [],
            }).toString(),
          ).toBe('(/**/)'));

        it('separator', () =>
          expect(
            new ListExpression({
              separator: ',',
              raws: {afterOpen: '/**/'},
              nodes: [],
            }).toString(),
          ).toBe('(/**/,)'));

        it('and beforeClose', () =>
          expect(
            new ListExpression({
              separator: null,
              raws: {afterOpen: '/**/', beforeClose: '  '},
              nodes: [],
            }).toString(),
          ).toBe('(/**/  )'));
      });

      describe('one element', () => {
        it('no brackets', () =>
          expect(
            new ListExpression({
              separator: null,
              raws: {afterOpen: '/**/'},
              nodes: [{text: 'foo'}],
            }).toString(),
          ).toBe('foo'));

        it('brackets', () =>
          expect(
            new ListExpression({
              separator: null,
              brackets: true,
              raws: {afterOpen: '/**/'},
              nodes: [{text: 'foo'}],
            }).toString(),
          ).toBe('[/**/foo]'));

        it('and expressions.before', () =>
          expect(
            new ListExpression({
              separator: null,
              brackets: true,
              raws: {afterOpen: '/**/', expressions: [{before: '  '}]},
              nodes: [{text: 'foo'}],
            }).toString(),
          ).toBe('[/**/  foo]'));
      });
    });

    describe('beforeClose', () => {
      it('empty', () =>
        expect(
          new ListExpression({
            separator: null,
            raws: {beforeClose: '/**/'},
            nodes: [],
          }).toString(),
        ).toBe('(/**/)'));

      describe('one element', () => {
        it('no brackets', () =>
          expect(
            new ListExpression({
              separator: null,
              raws: {beforeClose: '/**/'},
              nodes: [{text: 'foo'}],
            }).toString(),
          ).toBe('foo'));

        it('brackets', () =>
          expect(
            new ListExpression({
              separator: null,
              brackets: true,
              raws: {beforeClose: '/**/'},
              nodes: [{text: 'foo'}],
            }).toString(),
          ).toBe('[foo/**/]'));

        it('and expressions.after', () =>
          expect(
            new ListExpression({
              separator: null,
              brackets: true,
              raws: {beforeClose: '/**/', expressions: [{after: '  '}]},
              nodes: [{text: 'foo'}],
            }).toString(),
          ).toBe('[foo  /**/]'));
      });
    });

    describe('trailingComma', () => {
      describe('is ignored for', () => {
        describe('empty', () =>
          expect(
            new ListExpression({
              separator: null,
              raws: {trailingComma: true},
              nodes: [],
            }).toString(),
          ).toBe('()'));

        describe('one element', () => {
          it('no separator', () =>
            expect(
              new ListExpression({
                separator: null,
                raws: {trailingComma: true},
                nodes: [{text: 'foo'}],
              }).toString(),
            ).toBe('foo'));

          it('comma separator', () =>
            expect(
              new ListExpression({
                separator: ',',
                raws: {trailingComma: false},
                nodes: [{text: 'foo'}],
              }).toString(),
            ).toBe('foo,'));
        });
      });

      describe('multiple elements', () => {
        it('is ignored for a non-comma separator', () =>
          expect(
            new ListExpression({
              separator: ' ',
              raws: {trailingComma: true},
              nodes: [{text: 'foo'}, {text: 'bar'}],
            }).toString(),
          ).toBe('foo bar'));

        it('is respected for a comma separator', () =>
          expect(
            new ListExpression({
              separator: ',',
              raws: {trailingComma: true},
              nodes: [{text: 'foo'}, {text: 'bar'}],
            }).toString(),
          ).toBe('foo, bar,'));

        it('with brackets', () =>
          expect(
            new ListExpression({
              separator: ',',
              brackets: true,
              raws: {trailingComma: true},
              nodes: [{text: 'foo'}, {text: 'bar'}],
            }).toString(),
          ).toBe('[foo, bar,]'));

        it('with beforeClose', () =>
          expect(
            new ListExpression({
              separator: ',',
              brackets: true,
              raws: {trailingComma: true, beforeClose: '/**/'},
              nodes: [{text: 'foo'}, {text: 'bar'}],
            }).toString(),
          ).toBe('[foo, bar,/**/]'));

        it('with expressions.after', () =>
          expect(
            new ListExpression({
              separator: ',',
              raws: {
                trailingComma: true,
                expressions: [undefined, {after: '/**/'}],
              },
              nodes: [{text: 'foo'}, {text: 'bar'}],
            }).toString(),
          ).toBe('foo, bar/**/,'));
      });
    });

    describe('expressions', () => {
      describe('with one element', () => {
        it('before', () =>
          expect(
            new ListExpression({
              separator: null,
              raws: {expressions: [{before: '/**/'}]},
              nodes: [{text: 'foo'}],
            }).toString(),
          ).toBe('/**/foo'));

        it('after', () =>
          expect(
            new ListExpression({
              separator: null,
              raws: {expressions: [{after: '/**/'}]},
              nodes: [{text: 'foo'}],
            }).toString(),
          ).toBe('foo/**/'));

        it('both', () =>
          expect(
            new ListExpression({
              separator: null,
              raws: {expressions: [{before: '  ', after: '/**/'}]},
              nodes: [{text: 'foo'}],
            }).toString(),
          ).toBe('  foo/**/'));

        it('ignores extra expression raws', () =>
          expect(
            new ListExpression({
              separator: null,
              raws: {expressions: [undefined, {before: '  ', after: '/**/'}]},
              nodes: [{text: 'foo'}],
            }).toString(),
          ).toBe('foo'));
      });

      describe('with two elements', () => {
        describe('space separator', () => {
          it('before', () =>
            expect(
              new ListExpression({
                separator: ' ',
                raws: {expressions: [undefined, {before: '/**/'}]},
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo /**/bar'));

          it('after', () =>
            expect(
              new ListExpression({
                separator: ' ',
                raws: {expressions: [{after: '/**/'}]},
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo/**/bar'));

          it('both', () =>
            expect(
              new ListExpression({
                separator: ' ',
                raws: {expressions: [{after: '/**/'}, {before: '  '}]},
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo/**/  bar'));
        });

        describe('comma separator', () => {
          it('before', () =>
            expect(
              new ListExpression({
                separator: ',',
                raws: {expressions: [undefined, {before: '/**/'}]},
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo,/**/bar'));

          it('after', () =>
            expect(
              new ListExpression({
                separator: ',',
                raws: {expressions: [{after: '/**/'}]},
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo/**/, bar'));

          it('both', () =>
            expect(
              new ListExpression({
                separator: ',',
                raws: {expressions: [{after: '/**/'}, {before: '  '}]},
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo/**/,  bar'));
        });

        describe('slash separator', () => {
          it('before', () =>
            expect(
              new ListExpression({
                separator: '/',
                raws: {expressions: [undefined, {before: '/**/'}]},
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo //**/bar'));

          it('after', () =>
            expect(
              new ListExpression({
                separator: '/',
                raws: {expressions: [{after: '/**/'}]},
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo/**// bar'));

          it('both', () =>
            expect(
              new ListExpression({
                separator: '/',
                raws: {expressions: [{after: '/**/'}, {before: '  '}]},
                nodes: [{text: 'foo'}, {text: 'bar'}],
              }).toString(),
            ).toBe('foo/**//  bar'));
        });
      });
    });
  });

  describe('clone', () => {
    let original: ListExpression;

    beforeEach(() => {
      original = utils.parseExpression('foo bar');
      // TODO: remove this once raws are properly parsed.
      original.raws.afterOpen = '  ';
    });

    describe('with no overrides', () => {
      let clone: ListExpression;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('nodes', () => {
          expect(clone.nodes).toHaveLength(2);
          expect(clone).toHaveStringExpression(0, 'foo');
          expect(clone).toHaveStringExpression(1, 'bar');
        });

        it('separator', () => expect(clone.separator).toBe(' '));

        it('brackets', () => expect(clone.brackets).toBe(false));

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
          const clone = original.clone({nodes: [{text: 'zip'}]});
          expect(clone.nodes).toHaveLength(1);
          expect(clone).toHaveStringExpression(0, 'zip');
        });

        it('undefined', () => {
          const clone = original.clone({nodes: undefined});
          expect(clone.nodes).toHaveLength(2);
          expect(clone).toHaveStringExpression(0, 'foo');
          expect(clone).toHaveStringExpression(1, 'bar');
        });
      });

      describe('separator', () => {
        it('defined', () =>
          expect(original.clone({separator: ','}).separator).toBe(','));

        it('undefined', () =>
          expect(original.clone({separator: undefined}).separator).toBe(' '));

        it('null', () =>
          expect(original.clone({separator: null}).separator).toBe(null));
      });

      describe('brackets', () => {
        it('defined', () =>
          expect(original.clone({brackets: true}).brackets).toBe(true));

        it('undefined', () =>
          expect(original.clone({brackets: undefined}).brackets).toBe(false));
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
    expect(utils.parseExpression('[foo, bar]')).toMatchSnapshot());
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
        text: expect.objectContaining({asPlain: value}),
      }),
      index,
    );
  }
  expect(fn).toHaveBeenCalledTimes(elements.length);
}
