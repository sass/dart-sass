// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  IfConditionOperation,
  IfConditionSass,
  VariableExpression,
} from '../../..';
import * as utils from '../../../../test/utils';

type EachFn = Parameters<IfConditionOperation['each']>[0];

let node: IfConditionOperation;

describe('an if() condition operation', () => {
  beforeEach(() => {
    node = new IfConditionOperation({
      operator: 'and',
      nodes: [{variableName: 'foo'}, {variableName: 'bar'}],
    });
  });

  describe('two operands', () => {
    function describeNode(
      description: string,
      create: () => IfConditionOperation,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('if-condition-operation'));

        it('has an operator', () => expect(node.operator).toBe('and'));

        it('has operands', () => {
          expect(node).toHaveNode(0, 'sass($foo)', 'if-condition-sass');
          expect(node).toHaveNode(1, 'sass($bar)', 'if-condition-sass');
        });
      });
    }

    describeNode('parsed', () =>
      utils.parseIfConditionExpression('sass($foo) and sass($bar)'),
    );

    describeNode(
      'constructed manually',
      () =>
        new IfConditionOperation({
          operator: 'and',
          nodes: [{variableName: 'foo'}, {variableName: 'bar'}],
        }),
    );

    describeNode('constructed from IfConditionExpressionProps', () =>
      utils.fromIfConditionExpressionProps({
        operator: 'and',
        nodes: [{variableName: 'foo'}, {variableName: 'bar'}],
      }),
    );
  });

  describe('three operands', () => {
    function describeNode(
      description: string,
      create: () => IfConditionOperation,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('if-condition-operation'));

        it('has an operator', () => expect(node.operator).toBe('and'));

        it('has operands', () => {
          expect(node).toHaveNode(0, 'sass($foo)', 'if-condition-sass');
          expect(node).toHaveNode(1, 'sass($bar)', 'if-condition-sass');
          expect(node).toHaveNode(2, 'sass($baz)', 'if-condition-sass');
        });
      });
    }

    describeNode('parsed', () =>
      utils.parseIfConditionExpression(
        'sass($foo) and sass($bar) and sass($baz)',
      ),
    );

    describeNode(
      'constructed manually',
      () =>
        new IfConditionOperation({
          operator: 'and',
          nodes: [
            {variableName: 'foo'},
            {variableName: 'bar'},
            {variableName: 'baz'},
          ],
        }),
    );

    describeNode('constructed from IfConditionExpressionProps', () =>
      utils.fromIfConditionExpressionProps({
        operator: 'and',
        nodes: [
          {variableName: 'foo'},
          {variableName: 'bar'},
          {variableName: 'baz'},
        ],
      }),
    );
  });

  describe('an or expression', () => {
    function describeNode(
      description: string,
      create: () => IfConditionOperation,
    ): void {
      describe(description, () => {
        beforeEach(() => (node = create()));

        it('has a sassType', () =>
          expect(node.sassType.toString()).toBe('if-condition-operation'));

        it('has an operator', () => expect(node.operator).toBe('or'));

        it('has operands', () => {
          expect(node).toHaveNode(0, 'sass($foo)', 'if-condition-sass');
          expect(node).toHaveNode(1, 'sass($bar)', 'if-condition-sass');
        });
      });
    }

    describeNode('parsed', () =>
      utils.parseIfConditionExpression('sass($foo) or sass($bar)'),
    );

    describeNode(
      'constructed manually',
      () =>
        new IfConditionOperation({
          operator: 'or',
          nodes: [{variableName: 'foo'}, {variableName: 'bar'}],
        }),
    );

    describeNode('constructed from IfConditionExpressionProps', () =>
      utils.fromIfConditionExpressionProps({
        operator: 'or',
        nodes: [{variableName: 'foo'}, {variableName: 'bar'}],
      }),
    );
  });

  it('assigned a new operator', () => {
    node.operator = 'or';
    expect(node.operator).toBe('or');
  });

  describe('can add', () => {
    beforeEach(
      () =>
        void (node = new IfConditionOperation({operator: 'and', nodes: []})),
    );

    it('a single if condition', () => {
      const condition = new IfConditionSass({variableName: 'foo'});
      node.append(condition);
      expect(node.nodes[0]).toBe(condition);
      expect(condition.parent).toBe(node);
    });

    it('a list of conditions', () => {
      const condition1 = new IfConditionSass({variableName: 'foo'});
      const condition2 = new IfConditionSass({variableName: 'bar'});
      node.append([condition1, condition2]);
      expect(node.nodes[0]).toBe(condition1);
      expect(node.nodes[1]).toBe(condition2);
      expect(condition1.parent).toBe(node);
      expect(condition2.parent).toBe(node);
    });

    it("a single condition's properties", () => {
      node.append({expression: {variableName: 'foo'}});
      expect(node).toHaveNode(0, 'sass($foo)');
    });

    it('a list of condition properties', () => {
      node.append([
        {expression: {variableName: 'foo'}},
        {expression: {variableName: 'bar'}},
      ]);
      expect(node).toHaveNode(0, 'sass($foo)');
      expect(node).toHaveNode(1, 'sass($bar)');
    });

    it('a single expression', () => {
      const variable = new VariableExpression({variableName: 'foo'});
      node.append(variable);
      expect((node.nodes[0] as IfConditionSass).expression).toBe(variable);
      expect(variable.parent?.parent).toBe(node);
    });

    it('a list of expressions', () => {
      const variable1 = new VariableExpression({variableName: 'foo'});
      const variable2 = new VariableExpression({variableName: 'bar'});
      node.append([variable1, variable2]);
      expect((node.nodes[0] as IfConditionSass).expression).toBe(variable1);
      expect((node.nodes[1] as IfConditionSass).expression).toBe(variable2);
      expect(variable1.parent?.parent).toBe(node);
      expect(variable2.parent?.parent).toBe(node);
    });

    it("a single expression's properties", () => {
      node.append({variableName: 'foo'});
      expect(node).toHaveNode(0, 'sass($foo)');
    });

    it('a list of properties', () => {
      node.append([{variableName: 'foo'}, {variableName: 'bar'}]);
      expect(node).toHaveNode(0, 'sass($foo)');
      expect(node).toHaveNode(1, 'sass($bar)');
    });

    it('undefined', () => {
      node.append(undefined);
      expect(node.nodes).toHaveLength(0);
    });
  });

  describe('append', () => {
    beforeEach(
      () =>
        void (node = new IfConditionOperation({
          operator: 'and',
          nodes: [{variableName: 'foo'}, {variableName: 'bar'}],
        })),
    );

    it('adds multiple children to the end', () => {
      node.append({variableName: 'baz'}, {variableName: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, 'sass($foo)');
      expect(node).toHaveNode(1, 'sass($bar)');
      expect(node).toHaveNode(2, 'sass($baz)');
      expect(node).toHaveNode(3, 'sass($qux)');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () =>
        node.append({variableName: 'baz'}),
      ));

    it('returns itself', () => expect(node.append()).toBe(node));
  });

  describe('each', () => {
    beforeEach(
      () =>
        void (node = new IfConditionOperation({
          operator: 'and',
          nodes: [{variableName: 'foo'}, {variableName: 'bar'}],
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
        void (node = new IfConditionOperation({
          operator: 'and',
          nodes: [
            {variableName: 'foo'},
            {variableName: 'bar'},
            {variableName: 'baz'},
          ],
        })),
    );

    it('returns true if the callback returns true for all elements', () =>
      expect(node.every(() => true)).toBe(true));

    it('returns false if the callback returns false for any element', () =>
      expect(node.every(element => element.toString() !== 'sass($bar)')).toBe(
        false,
      ));
  });

  describe('index', () => {
    beforeEach(
      () =>
        void (node = new IfConditionOperation({
          operator: 'and',
          nodes: [
            {variableName: 'foo'},
            {variableName: 'bar'},
            {variableName: 'baz'},
            {variableName: 'qux'},
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
        void (node = new IfConditionOperation({
          operator: 'and',
          nodes: [
            {variableName: 'foo'},
            {variableName: 'bar'},
            {variableName: 'baz'},
          ],
        })),
    );

    it('inserts a node after the given element', () => {
      node.insertAfter(node.nodes[1], {variableName: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, 'sass($foo)');
      expect(node).toHaveNode(1, 'sass($bar)');
      expect(node).toHaveNode(2, 'sass($qux)');
      expect(node).toHaveNode(3, 'sass($baz)');
    });

    it('inserts a node at the beginning', () => {
      node.insertAfter(-1, {variableName: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, 'sass($qux)');
      expect(node).toHaveNode(1, 'sass($foo)');
      expect(node).toHaveNode(2, 'sass($bar)');
      expect(node).toHaveNode(3, 'sass($baz)');
    });

    it('inserts a node at the end', () => {
      node.insertAfter(3, {variableName: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, 'sass($foo)');
      expect(node).toHaveNode(1, 'sass($bar)');
      expect(node).toHaveNode(2, 'sass($baz)');
      expect(node).toHaveNode(3, 'sass($qux)');
    });

    it('inserts multiple nodes', () => {
      node.insertAfter(1, [
        {variableName: 'qux'},
        {variableName: 'qax'},
        {variableName: 'qix'},
      ]);
      expect(node.nodes).toHaveLength(6);
      expect(node).toHaveNode(0, 'sass($foo)');
      expect(node).toHaveNode(1, 'sass($bar)');
      expect(node).toHaveNode(2, 'sass($qux)');
      expect(node).toHaveNode(3, 'sass($qax)');
      expect(node).toHaveNode(4, 'sass($qix)');
      expect(node).toHaveNode(5, 'sass($baz)');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertAfter(0, [
          {variableName: 'qux'},
          {variableName: 'qax'},
          {variableName: 'qix'},
        ]),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertAfter(1, [
          {variableName: 'qux'},
          {variableName: 'qax'},
          {variableName: 'qix'},
        ]),
      ));

    it('returns itself', () =>
      expect(node.insertAfter(node.nodes[0], {variableName: 'qux'})).toBe(
        node,
      ));
  });

  describe('insertBefore', () => {
    beforeEach(
      () =>
        void (node = new IfConditionOperation({
          operator: 'and',
          nodes: [
            {variableName: 'foo'},
            {variableName: 'bar'},
            {variableName: 'baz'},
          ],
        })),
    );

    it('inserts a node before the given element', () => {
      node.insertBefore(node.nodes[1], {variableName: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, 'sass($foo)');
      expect(node).toHaveNode(1, 'sass($qux)');
      expect(node).toHaveNode(2, 'sass($bar)');
      expect(node).toHaveNode(3, 'sass($baz)');
    });

    it('inserts a node at the beginning', () => {
      node.insertBefore(0, {variableName: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, 'sass($qux)');
      expect(node).toHaveNode(1, 'sass($foo)');
      expect(node).toHaveNode(2, 'sass($bar)');
      expect(node).toHaveNode(3, 'sass($baz)');
    });

    it('inserts a node at the end', () => {
      node.insertBefore(4, {variableName: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, 'sass($foo)');
      expect(node).toHaveNode(1, 'sass($bar)');
      expect(node).toHaveNode(2, 'sass($baz)');
      expect(node).toHaveNode(3, 'sass($qux)');
    });

    it('inserts multiple nodes', () => {
      node.insertBefore(1, [
        {variableName: 'qux'},
        {variableName: 'qax'},
        {variableName: 'qix'},
      ]);
      expect(node.nodes).toHaveLength(6);
      expect(node).toHaveNode(0, 'sass($foo)');
      expect(node).toHaveNode(1, 'sass($qux)');
      expect(node).toHaveNode(2, 'sass($qax)');
      expect(node).toHaveNode(3, 'sass($qix)');
      expect(node).toHaveNode(4, 'sass($bar)');
      expect(node).toHaveNode(5, 'sass($baz)');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertBefore(1, [
          {variableName: 'qux'},
          {variableName: 'qax'},
          {variableName: 'qix'},
        ]),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertBefore(2, [
          {variableName: 'qux'},
          {variableName: 'qax'},
          {variableName: 'qix'},
        ]),
      ));

    it('returns itself', () =>
      expect(node.insertBefore(node.nodes[0], {variableName: 'qux'})).toBe(
        node,
      ));
  });

  describe('prepend', () => {
    beforeEach(
      () =>
        void (node = new IfConditionOperation({
          operator: 'and',
          nodes: [
            {variableName: 'foo'},
            {variableName: 'bar'},
            {variableName: 'baz'},
          ],
        })),
    );

    it('inserts one node', () => {
      node.prepend({variableName: 'qux'});
      expect(node.nodes).toHaveLength(4);
      expect(node).toHaveNode(0, 'sass($qux)');
      expect(node).toHaveNode(1, 'sass($foo)');
      expect(node).toHaveNode(2, 'sass($bar)');
      expect(node).toHaveNode(3, 'sass($baz)');
    });

    it('inserts multiple nodes', () => {
      node.prepend(
        {variableName: 'qux'},
        {variableName: 'qax'},
        {variableName: 'qix'},
      );
      expect(node.nodes).toHaveLength(6);
      expect(node).toHaveNode(0, 'sass($qux)');
      expect(node).toHaveNode(1, 'sass($qax)');
      expect(node).toHaveNode(2, 'sass($qix)');
      expect(node).toHaveNode(3, 'sass($foo)');
      expect(node).toHaveNode(4, 'sass($bar)');
      expect(node).toHaveNode(5, 'sass($baz)');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.prepend(
          {variableName: 'qux'},
          {variableName: 'qax'},
          {variableName: 'qix'},
        ),
      ));

    it('returns itself', () =>
      expect(node.prepend({variableName: 'qux'})).toBe(node));
  });

  describe('push', () => {
    beforeEach(
      () =>
        void (node = new IfConditionOperation({
          operator: 'and',
          nodes: [{variableName: 'foo'}, {variableName: 'bar'}],
        })),
    );

    it('inserts one node', () => {
      node.push(new IfConditionSass({variableName: 'baz'}));
      expect(node.nodes).toHaveLength(3);
      expect(node).toHaveNode(0, 'sass($foo)');
      expect(node).toHaveNode(1, 'sass($bar)');
      expect(node).toHaveNode(2, 'sass($baz)');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () =>
        node.push(new IfConditionSass({variableName: 'baz'})),
      ));

    it('returns itself', () =>
      expect(node.push(new IfConditionSass({variableName: 'baz'}))).toBe(node));
  });

  describe('removeAll', () => {
    beforeEach(
      () =>
        void (node = new IfConditionOperation({
          operator: 'and',
          nodes: [
            {variableName: 'foo'},
            {variableName: 'bar'},
            {variableName: 'baz'},
          ],
        })),
    );

    it('removes all nodes', () => {
      node.removeAll();
      expect(node.nodes).toHaveLength(0);
    });

    it("removes a node's parents", () => {
      const variable = node.nodes[1];
      node.removeAll();
      expect(variable).toHaveProperty('parent', undefined);
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo'], 0, () => node.removeAll()));

    it('returns itself', () => expect(node.removeAll()).toBe(node));
  });

  describe('removeChild', () => {
    beforeEach(
      () =>
        void (node = new IfConditionOperation({
          operator: 'and',
          nodes: [
            {variableName: 'foo'},
            {variableName: 'bar'},
            {variableName: 'baz'},
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
      expect(node).toHaveNode(0, 'sass($foo)');
      expect(node).toHaveNode(1, 'sass($baz)');
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
        void (node = new IfConditionOperation({
          operator: 'and',
          nodes: [
            {variableName: 'foo'},
            {variableName: 'bar'},
            {variableName: 'baz'},
          ],
        })),
    );

    it('returns false if the callback returns false for all elements', () =>
      expect(node.some(() => false)).toBe(false));

    it('returns true if the callback returns true for any element', () =>
      expect(node.some(element => element.toString() === 'sass($bar)')).toBe(
        true,
      ));
  });

  describe('first', () => {
    it('returns the first element', () =>
      expect(
        new IfConditionOperation({
          operator: 'and',
          nodes: [
            {variableName: 'foo'},
            {variableName: 'bar'},
            {variableName: 'baz'},
          ],
        }),
      ).toHaveNode('first', 'sass($foo)'));

    it('returns undefined for an empty list', () =>
      expect(
        new IfConditionOperation({operator: 'and', nodes: []}).first,
      ).toBeUndefined());
  });

  describe('last', () => {
    it('returns the last element', () =>
      expect(
        new IfConditionOperation({
          operator: 'and',
          nodes: [
            {variableName: 'foo'},
            {variableName: 'bar'},
            {variableName: 'baz'},
          ],
        }),
      ).toHaveNode('last', 'sass($baz)'));

    it('returns undefined for an empty list', () =>
      expect(
        new IfConditionOperation({operator: 'and', nodes: []}).last,
      ).toBeUndefined());
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with two operands', () => {
        beforeEach(() => {
          node = new IfConditionOperation({
            operator: 'and',
            nodes: [{variableName: 'foo'}, {variableName: 'bar'}],
          });
        });

        it('with default raws', () =>
          expect(node.toString()).toBe('sass($foo) and sass($bar)'));

        it('with matching operator', () => {
          node.raws.operators = [{operator: {value: 'and', raw: 'AND'}}];
          expect(node.toString()).toBe('sass($foo) AND sass($bar)');
        });

        it('with non-matching operator', () => {
          node.raws.operators = [{operator: {value: 'or', raw: 'OR'}}];
          expect(node.toString()).toBe('sass($foo) and sass($bar)');
        });

        it('with before', () => {
          node.raws.operators = [{before: '  '}];
          expect(node.toString()).toBe('sass($foo)  and sass($bar)');
        });

        it('with after', () => {
          node.raws.operators = [{after: '  '}];
          expect(node.toString()).toBe('sass($foo) and  sass($bar)');
        });

        it('ignores operators after the end', () => {
          node.raws.operators = [
            undefined,
            {operator: {value: 'and', raw: 'AND'}, before: '  ', after: '  '},
          ];
          expect(node.toString()).toBe('sass($foo) and sass($bar)');
        });
      });

      describe('with three operands', () => {
        beforeEach(() => {
          node = new IfConditionOperation({
            operator: 'and',
            nodes: [
              {variableName: 'foo'},
              {variableName: 'bar'},
              {variableName: 'baz'},
            ],
          });
        });

        it('with default raws', () =>
          expect(node.toString()).toBe(
            'sass($foo) and sass($bar) and sass($baz)',
          ));

        it('with different operators', () => {
          node.raws.operators = [
            {operator: {value: 'and', raw: 'AnD'}},
            {operator: {value: 'and', raw: 'aNd'}},
          ];
          expect(node.toString()).toBe(
            'sass($foo) AnD sass($bar) aNd sass($baz)',
          );
        });

        it('with only one matching operator', () => {
          node.raws.operators = [
            {operator: {value: 'or', raw: 'OR'}},
            {operator: {value: 'and', raw: 'AND'}},
          ];
          expect(node.toString()).toBe(
            'sass($foo) and sass($bar) AND sass($baz)',
          );
        });

        it('with only one operator', () => {
          node.raws.operators = [
            undefined,
            {operator: {value: 'and', raw: 'AND'}},
          ];
          expect(node.toString()).toBe(
            'sass($foo) and sass($bar) AND sass($baz)',
          );
        });

        it('with different befores', () => {
          node.raws.operators = [{before: '  '}, {before: '/**/'}];
          expect(node.toString()).toBe(
            'sass($foo)  and sass($bar)/**/and sass($baz)',
          );
        });

        it('with only one before', () => {
          node.raws.operators = [{before: '  '}];
          expect(node.toString()).toBe(
            'sass($foo)  and sass($bar) and sass($baz)',
          );
        });

        it('with different afters', () => {
          node.raws.operators = [{after: '  '}, {after: '/**/'}];
          expect(node.toString()).toBe(
            'sass($foo) and  sass($bar) and/**/sass($baz)',
          );
        });

        it('with only one after', () => {
          node.raws.operators = [undefined, {after: '/**/'}];
          expect(node.toString()).toBe(
            'sass($foo) and sass($bar) and/**/sass($baz)',
          );
        });

        it('ignores operators after the end', () => {
          node.raws.operators = [
            undefined,
            undefined,
            {operator: {value: 'and', raw: 'AND'}, before: '  ', after: '  '},
          ];
          expect(node.toString()).toBe(
            'sass($foo) and sass($bar) and sass($baz)',
          );
        });
      });
    });
  });

  describe('clone()', () => {
    beforeEach(() => {
      node.raws.operators = [{before: '  '}];
    });

    describe('with no overrides', () => {
      let clone: IfConditionOperation;
      beforeEach(() => void (clone = node.clone()));

      describe('has the same properties:', () => {
        it('operator', () => expect(clone.operator).toBe('and'));

        it('nodes', () => {
          expect(clone).toHaveNode(0, 'sass($foo)');
          expect(clone).toHaveNode(1, 'sass($bar)');
        });
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(node));

        for (const attr of ['nodes', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(node[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(node.clone({raws: {operators: [{after: '  '}]}}).raws).toEqual(
            {operators: [{after: '  '}]},
          ));

        it('undefined', () =>
          expect(node.clone({raws: undefined}).raws).toEqual({
            operators: [{before: '  '}],
          }));
      });

      describe('operator', () => {
        it('defined', () =>
          expect(node.clone({operator: 'or'}).operator).toBe('or'));

        it('undefined', () =>
          expect(node.clone({operator: undefined}).operator).toBe('and'));
      });

      describe('nodes', () => {
        it('defined', () => {
          const clone = node.clone({nodes: [{variableName: 'baz'}]});
          expect(clone.nodes).toHaveLength(1);
          expect(clone).toHaveNode(0, 'sass($baz)');
        });

        it('undefined', () => {
          const clone = node.clone({nodes: undefined});
          expect(clone.nodes).toHaveLength(2);
          expect(clone).toHaveNode(0, 'sass($foo)');
          expect(clone).toHaveNode(1, 'sass($bar)');
        });
      });
    });
  });

  describe('toJSON', () => {
    it('and', () =>
      expect(
        utils.parseIfConditionExpression('sass($foo) and sass($bar)'),
      ).toMatchSnapshot());

    it('or', () =>
      expect(
        utils.parseIfConditionExpression('sass($foo) or sass($bar)'),
      ).toMatchSnapshot());
  });
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
        expression: expect.objectContaining({variableName: value}),
      }),
      index,
    );
  }
  expect(fn).toHaveBeenCalledTimes(elements.length);
}
