// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  Expression,
  GenericAtRule,
  Interpolation,
  StringExpression,
  css,
  scss,
} from '..';

type EachFn = Parameters<Interpolation['each']>[0];

let node: Interpolation;
describe('an interpolation', () => {
  describe('empty', () => {
    function describeNode(
      description: string,
      create: () => Interpolation
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType interpolation', () =>
          expect(node.sassType).toBe('interpolation'));

        it('has no nodes', () => expect(node.nodes).toHaveLength(0));

        it('is plain', () => expect(node.isPlain).toBe(true));

        it('has a plain value', () => expect(node.asPlain).toBe(''));
      });
    }

    // TODO: Are there any node types that allow empty interpolation?

    describeNode('constructed manually', () => new Interpolation());
  });

  describe('with no expressions', () => {
    function describeNode(
      description: string,
      create: () => Interpolation
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType interpolation', () =>
          expect(node.sassType).toBe('interpolation'));

        it('has a single node', () => {
          expect(node.nodes).toHaveLength(1);
          expect(node.nodes[0]).toBe('foo');
        });

        it('is plain', () => expect(node.isPlain).toBe(true));

        it('has a plain value', () => expect(node.asPlain).toBe('foo'));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => (scss.parse('@foo').nodes[0] as GenericAtRule).nameInterpolation
    );

    describeNode(
      'parsed as CSS',
      () => (css.parse('@foo').nodes[0] as GenericAtRule).nameInterpolation
    );

    describeNode(
      'constructed manually',
      () => new Interpolation({nodes: ['foo']})
    );
  });

  describe('with only an expression', () => {
    function describeNode(
      description: string,
      create: () => Interpolation
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType interpolation', () =>
          expect(node.sassType).toBe('interpolation'));

        it('has a single node', () =>
          expect(node).toHaveStringExpression(0, 'foo'));

        it('is not plain', () => expect(node.isPlain).toBe(false));

        it('has no plain value', () => expect(node.asPlain).toBe(null));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => (scss.parse('@#{foo}').nodes[0] as GenericAtRule).nameInterpolation
    );

    describeNode(
      'constructed manually',
      () => new Interpolation({nodes: [{text: 'foo'}]})
    );
  });

  describe('with mixed text and expressions', () => {
    function describeNode(
      description: string,
      create: () => Interpolation
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType interpolation', () =>
          expect(node.sassType).toBe('interpolation'));

        it('has multiple nodes', () => {
          expect(node.nodes).toHaveLength(3);
          expect(node.nodes[0]).toBe('foo');
          expect(node).toHaveStringExpression(1, 'bar');
          expect(node.nodes[2]).toBe('baz');
        });

        it('is not plain', () => expect(node.isPlain).toBe(false));

        it('has no plain value', () => expect(node.asPlain).toBe(null));
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@foo#{bar}baz').nodes[0] as GenericAtRule)
          .nameInterpolation
    );

    describeNode(
      'constructed manually',
      () => new Interpolation({nodes: ['foo', {text: 'bar'}, 'baz']})
    );
  });

  describe('can add', () => {
    beforeEach(() => void (node = new Interpolation()));

    it('a single interpolation', () => {
      const interpolation = new Interpolation({nodes: ['foo', {text: 'bar'}]});
      const string = interpolation.nodes[1];
      node.append(interpolation);
      expect(node.nodes).toEqual(['foo', string]);
      expect(string).toHaveProperty('parent', node);
      expect(interpolation.nodes).toHaveLength(0);
    });

    it('a list of interpolations', () => {
      node.append([
        new Interpolation({nodes: ['foo']}),
        new Interpolation({nodes: ['bar']}),
      ]);
      expect(node.nodes).toEqual(['foo', 'bar']);
    });

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

    it('a single string', () => {
      node.append('foo');
      expect(node.nodes).toEqual(['foo']);
    });

    it('a list of strings', () => {
      node.append(['foo', 'bar']);
      expect(node.nodes).toEqual(['foo', 'bar']);
    });

    it('undefined', () => {
      node.append(undefined);
      expect(node.nodes).toHaveLength(0);
    });
  });

  describe('append', () => {
    beforeEach(() => void (node = new Interpolation({nodes: ['foo', 'bar']})));

    it('adds multiple children to the end', () => {
      node.append('baz', 'qux');
      expect(node.nodes).toEqual(['foo', 'bar', 'baz', 'qux']);
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () => node.append('baz')));

    it('returns itself', () => expect(node.append()).toBe(node));
  });

  describe('each', () => {
    beforeEach(() => void (node = new Interpolation({nodes: ['foo', 'bar']})));

    it('calls the callback for each node', () => {
      const fn: EachFn = jest.fn();
      node.each(fn);
      expect(fn).toHaveBeenCalledTimes(2);
      expect(fn).toHaveBeenNthCalledWith(1, 'foo', 0);
      expect(fn).toHaveBeenNthCalledWith(2, 'bar', 1);
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
      () => void (node = new Interpolation({nodes: ['foo', 'bar', 'baz']}))
    );

    it('returns true if the callback returns true for all elements', () =>
      expect(node.every(() => true)).toBe(true));

    it('returns false if the callback returns false for any element', () =>
      expect(node.every(element => element !== 'bar')).toBe(false));
  });

  describe('index', () => {
    beforeEach(
      () =>
        void (node = new Interpolation({
          nodes: ['foo', 'bar', {text: 'baz'}, 'bar'],
        }))
    );

    it('returns the first index of a given string', () =>
      expect(node.index('bar')).toBe(1));

    it('returns the first index of a given expression', () =>
      expect(node.index(node.nodes[2])).toBe(2));

    it('returns a number as-is', () => expect(node.index(3)).toBe(3));
  });

  describe('insertAfter', () => {
    beforeEach(
      () => void (node = new Interpolation({nodes: ['foo', 'bar', 'baz']}))
    );

    it('inserts a node after the given element', () => {
      node.insertAfter('bar', 'qux');
      expect(node.nodes).toEqual(['foo', 'bar', 'qux', 'baz']);
    });

    it('inserts a node at the beginning', () => {
      node.insertAfter(-1, 'qux');
      expect(node.nodes).toEqual(['qux', 'foo', 'bar', 'baz']);
    });

    it('inserts a node at the end', () => {
      node.insertAfter(3, 'qux');
      expect(node.nodes).toEqual(['foo', 'bar', 'baz', 'qux']);
    });

    it('inserts multiple nodes', () => {
      node.insertAfter(1, ['qux', 'qax', 'qix']);
      expect(node.nodes).toEqual(['foo', 'bar', 'qux', 'qax', 'qix', 'baz']);
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertAfter(0, ['qux', 'qax', 'qix'])
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertAfter(1, ['qux', 'qax', 'qix'])
      ));

    it('returns itself', () =>
      expect(node.insertAfter('foo', 'qux')).toBe(node));
  });

  describe('insertBefore', () => {
    beforeEach(
      () => void (node = new Interpolation({nodes: ['foo', 'bar', 'baz']}))
    );

    it('inserts a node before the given element', () => {
      node.insertBefore('bar', 'qux');
      expect(node.nodes).toEqual(['foo', 'qux', 'bar', 'baz']);
    });

    it('inserts a node at the beginning', () => {
      node.insertBefore(0, 'qux');
      expect(node.nodes).toEqual(['qux', 'foo', 'bar', 'baz']);
    });

    it('inserts a node at the end', () => {
      node.insertBefore(4, 'qux');
      expect(node.nodes).toEqual(['foo', 'bar', 'baz', 'qux']);
    });

    it('inserts multiple nodes', () => {
      node.insertBefore(1, ['qux', 'qax', 'qix']);
      expect(node.nodes).toEqual(['foo', 'qux', 'qax', 'qix', 'bar', 'baz']);
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertBefore(1, ['qux', 'qax', 'qix'])
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertBefore(2, ['qux', 'qax', 'qix'])
      ));

    it('returns itself', () =>
      expect(node.insertBefore('foo', 'qux')).toBe(node));
  });

  describe('prepend', () => {
    beforeEach(
      () => void (node = new Interpolation({nodes: ['foo', 'bar', 'baz']}))
    );

    it('inserts one node', () => {
      node.prepend('qux');
      expect(node.nodes).toEqual(['qux', 'foo', 'bar', 'baz']);
    });

    it('inserts multiple nodes', () => {
      node.prepend('qux', 'qax', 'qix');
      expect(node.nodes).toEqual(['qux', 'qax', 'qix', 'foo', 'bar', 'baz']);
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.prepend('qux', 'qax', 'qix')
      ));

    it('returns itself', () => expect(node.prepend('qux')).toBe(node));
  });

  describe('push', () => {
    beforeEach(() => void (node = new Interpolation({nodes: ['foo', 'bar']})));

    it('inserts one node', () => {
      node.push('baz');
      expect(node.nodes).toEqual(['foo', 'bar', 'baz']);
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () => node.push('baz')));

    it('returns itself', () => expect(node.push('baz')).toBe(node));
  });

  describe('removeAll', () => {
    beforeEach(
      () =>
        void (node = new Interpolation({nodes: ['foo', {text: 'bar'}, 'baz']}))
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
        void (node = new Interpolation({nodes: ['foo', {text: 'bar'}, 'baz']}))
    );

    it('removes a matching node', () => {
      const string = node.nodes[1];
      node.removeChild('foo');
      expect(node.nodes).toEqual([string, 'baz']);
    });

    it('removes a node at index', () => {
      node.removeChild(1);
      expect(node.nodes).toEqual(['foo', 'baz']);
    });

    it("removes a node's parents", () => {
      const string = node.nodes[1];
      node.removeAll();
      expect(string).toHaveProperty('parent', undefined);
    });

    it('removes a node before the iterator', () =>
      testEachMutation(['foo', node.nodes[1], ['baz', 1]], 1, () =>
        node.removeChild(1)
      ));

    it('removes a node after the iterator', () =>
      testEachMutation(['foo', node.nodes[1]], 1, () => node.removeChild(2)));

    it('returns itself', () => expect(node.removeChild(0)).toBe(node));
  });

  describe('some', () => {
    beforeEach(
      () => void (node = new Interpolation({nodes: ['foo', 'bar', 'baz']}))
    );

    it('returns false if the callback returns false for all elements', () =>
      expect(node.some(() => false)).toBe(false));

    it('returns true if the callback returns true for any element', () =>
      expect(node.some(element => element === 'bar')).toBe(true));
  });

  describe('first', () => {
    it('returns the first element', () =>
      expect(new Interpolation({nodes: ['foo', 'bar', 'baz']}).first).toBe(
        'foo'
      ));

    it('returns undefined for an empty interpolation', () =>
      expect(new Interpolation().first).toBeUndefined());
  });

  describe('last', () => {
    it('returns the last element', () =>
      expect(new Interpolation({nodes: ['foo', 'bar', 'baz']}).last).toBe(
        'baz'
      ));

    it('returns undefined for an empty interpolation', () =>
      expect(new Interpolation().last).toBeUndefined());
  });

  describe('stringifies', () => {
    it('with no nodes', () => expect(new Interpolation().toString()).toBe(''));

    it('with only text', () =>
      expect(new Interpolation({nodes: ['foo', 'bar', 'baz']}).toString()).toBe(
        'foobarbaz'
      ));

    it('with only expressions', () =>
      expect(
        new Interpolation({nodes: [{text: 'foo'}, {text: 'bar'}]}).toString()
      ).toBe('#{foo}#{bar}'));

    it('with mixed text and expressions', () =>
      expect(
        new Interpolation({nodes: ['foo', {text: 'bar'}, 'baz']}).toString()
      ).toBe('foo#{bar}baz'));

    describe('with text', () => {
      beforeEach(
        () => void (node = new Interpolation({nodes: ['foo', 'bar', 'baz']}))
      );

      it('take precedence when the value matches', () => {
        node.raws.text = [{raw: 'f\\6f o', value: 'foo'}];
        expect(node.toString()).toBe('f\\6f obarbaz');
      });

      it("ignored when the value doesn't match", () => {
        node.raws.text = [{raw: 'f\\6f o', value: 'bar'}];
        expect(node.toString()).toBe('foobarbaz');
      });
    });

    describe('with expressions', () => {
      beforeEach(
        () =>
          void (node = new Interpolation({
            nodes: [{text: 'foo'}, {text: 'bar'}],
          }))
      );

      it('with before', () => {
        node.raws.expressions = [{before: '/**/'}];
        expect(node.toString()).toBe('#{/**/foo}#{bar}');
      });

      it('with after', () => {
        node.raws.expressions = [{after: '/**/'}];
        expect(node.toString()).toBe('#{foo/**/}#{bar}');
      });
    });
  });

  describe('clone', () => {
    let original: Interpolation;
    beforeEach(
      () =>
        void (original = new Interpolation({
          nodes: ['foo', {text: 'bar'}, 'baz'],
          raws: {expressions: [{before: '  '}]},
        }))
    );

    describe('with no overrides', () => {
      let clone: Interpolation;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('nodes', () => {
          expect(clone.nodes).toHaveLength(3);
          expect(clone.nodes[0]).toBe('foo');
          expect(clone.nodes[1]).toHaveInterpolation('text', 'bar');
          expect(clone.nodes[1]).toHaveProperty('parent', clone);
          expect(clone.nodes[2]).toBe('baz');
        });

        it('raws', () =>
          expect(clone.raws).toEqual({expressions: [{before: '  '}]}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['raws', 'nodes'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });

      describe('sets parent for', () => {
        it('nodes', () =>
          expect(clone.nodes[1]).toHaveProperty('parent', clone));
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(
            original.clone({raws: {expressions: [{after: '  '}]}}).raws
          ).toEqual({expressions: [{after: '  '}]}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            expressions: [{before: '  '}],
          }));
      });

      describe('nodes', () => {
        it('defined', () =>
          expect(original.clone({nodes: ['qux']}).nodes).toEqual(['qux']));

        it('undefined', () => {
          const clone = original.clone({nodes: undefined});
          expect(clone.nodes).toHaveLength(3);
          expect(clone.nodes[0]).toBe('foo');
          expect(clone.nodes[1]).toHaveInterpolation('text', 'bar');
          expect(clone.nodes[1]).toHaveProperty('parent', clone);
          expect(clone.nodes[2]).toBe('baz');
        });
      });
    });
  });

  it('toJSON', () =>
    expect(
      (scss.parse('@foo#{bar}baz').nodes[0] as GenericAtRule).nameInterpolation
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
  elements: ([string | Expression, number] | string | Expression)[],
  indexToModify: number,
  modify: () => void
): void {
  const fn: EachFn = jest.fn((child, i) => {
    if (i === indexToModify) modify();
  });
  node.each(fn);

  for (let i = 0; i < elements.length; i++) {
    const element = elements[i];
    const [value, index] = Array.isArray(element) ? element : [element, i];
    expect(fn).toHaveBeenNthCalledWith(i + 1, value, index);
  }
  expect(fn).toHaveBeenCalledTimes(elements.length);
}
