// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  Argument,
  ArgumentList,
  IncludeRule,
  StringExpression,
  sass,
  scss,
} from '..';

type EachFn = Parameters<ArgumentList['each']>[0];

let node: ArgumentList;
describe('an argument list', () => {
  describe('empty', () => {
    function describeNode(
      description: string,
      create: () => ArgumentList,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () => expect(node.sassType).toBe('argument-list'));

        it('has no nodes', () => expect(node.nodes).toHaveLength(0));
      });
    }

    describeNode(
      'parsed as SCSS',
      () => (scss.parse('@include x()').nodes[0] as IncludeRule).arguments,
    );

    describeNode(
      'parsed as Sass',
      () => (sass.parse('@include x()').nodes[0] as IncludeRule).arguments,
    );

    describe('constructed manually', () => {
      describeNode('with no arguments', () => new ArgumentList());

      describeNode('with an array', () => new ArgumentList([]));

      describeNode('with an object', () => new ArgumentList({}));

      describeNode(
        'with an object with an array',
        () => new ArgumentList({nodes: []}),
      );
    });

    describe('constructed from properties', () => {
      describeNode(
        'an object',
        () => new IncludeRule({includeName: 'x', arguments: {}}).arguments,
      );

      describeNode(
        'an array',
        () => new IncludeRule({includeName: 'x', arguments: []}).arguments,
      );
    });
  });

  describe('with an argument with no name', () => {
    function describeNode(
      description: string,
      create: () => ArgumentList,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () => expect(node.sassType).toBe('argument-list'));

        it('has a node', () => {
          expect(node.nodes.length).toBe(1);
          expect(node.nodes[0].name).toBeUndefined();
          expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
          expect(node.nodes[0].parent).toBe(node);
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () => (scss.parse('@include x(bar)').nodes[0] as IncludeRule).arguments,
    );

    describeNode(
      'parsed as Sass',
      () => (sass.parse('@include x(bar)').nodes[0] as IncludeRule).arguments,
    );

    describe('constructed manually', () => {
      describe('with an array', () => {
        describeNode(
          'with an expression',
          () => new ArgumentList([new StringExpression({text: 'bar'})]),
        );

        describeNode(
          'with an Argument',
          () => new ArgumentList([new Argument({text: 'bar'})]),
        );

        describeNode(
          'with ArgumentProps',
          () => new ArgumentList([{value: {text: 'bar'}}]),
        );

        describeNode(
          'with ExpressionProps',
          () => new ArgumentList([{text: 'bar'}]),
        );
      });

      describe('with an object', () => {
        describeNode(
          'with an expression',
          () =>
            new ArgumentList({nodes: [new StringExpression({text: 'bar'})]}),
        );

        describeNode(
          'with an Argument',
          () => new ArgumentList({nodes: [new Argument({text: 'bar'})]}),
        );

        describeNode(
          'with ArgumentProps',
          () => new ArgumentList({nodes: [{value: {text: 'bar'}}]}),
        );

        describeNode(
          'with ExpressionProps',
          () => new ArgumentList({nodes: [{text: 'bar'}]}),
        );
      });
    });

    describe('constructed from properties', () => {
      describeNode(
        'an object',
        () =>
          new IncludeRule({
            includeName: 'x',
            arguments: {nodes: [{text: 'bar'}]},
          }).arguments,
      );

      describeNode(
        'an array',
        () =>
          new IncludeRule({includeName: 'x', arguments: [{text: 'bar'}]})
            .arguments,
      );
    });
  });

  describe('with an argument with a name', () => {
    function describeNode(
      description: string,
      create: () => ArgumentList,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () => expect(node.sassType).toBe('argument-list'));

        it('has a node', () => {
          expect(node.nodes.length).toBe(1);
          expect(node.nodes[0].name).toBe('foo');
          expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
          expect(node.nodes[0]).toHaveProperty('parent', node);
        });
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@include x($foo: bar)').nodes[0] as IncludeRule).arguments,
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@include x($foo: bar)').nodes[0] as IncludeRule).arguments,
    );

    describe('constructed manually', () => {
      describe('with an array', () => {
        describeNode(
          'with a sub-array',
          () => new ArgumentList([['foo', {text: 'bar'}]]),
        );

        describeNode(
          'with an object',
          () => new ArgumentList([{name: 'foo', value: {text: 'bar'}}]),
        );

        describeNode(
          'with a Argument',
          () =>
            new ArgumentList([
              new Argument({name: 'foo', value: {text: 'bar'}}),
            ]),
        );
      });

      describe('with an object', () => {
        describeNode(
          'with a sub-array',
          () => new ArgumentList({nodes: [['foo', {text: 'bar'}]]}),
        );

        describeNode(
          'with an object',
          () =>
            new ArgumentList({
              nodes: [{name: 'foo', value: {text: 'bar'}}],
            }),
        );

        describeNode(
          'with a Argument',
          () =>
            new ArgumentList({
              nodes: [new Argument({name: 'foo', value: {text: 'bar'}})],
            }),
        );
      });
    });

    describe('constructed from properties', () => {
      describeNode(
        'an object',
        () =>
          new IncludeRule({
            includeName: 'x',
            arguments: {nodes: [['foo', {text: 'bar'}]]},
          }).arguments,
      );

      describeNode(
        'an array',
        () =>
          new IncludeRule({
            includeName: 'x',
            arguments: [['foo', {text: 'bar'}]],
          }).arguments,
      );
    });
  });

  describe('can add', () => {
    beforeEach(() => void (node = new ArgumentList()));

    it('a single argument', () => {
      const argument = new Argument({text: 'foo'});
      node.append(argument);
      expect(node.nodes).toEqual([argument]);
      expect(argument).toHaveProperty('parent', node);
    });

    it('a list of arguments', () => {
      const foo = new Argument({text: 'foo'});
      const bar = new Argument({text: 'bar'});
      node.append([foo, bar]);
      expect(node.nodes).toEqual([foo, bar]);
    });

    it('ExpressionProps', () => {
      node.append({text: 'bar'});
      expect(node.nodes[0]).toBeInstanceOf(Argument);
      expect(node.nodes[0].name).toBeUndefined();
      expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[0]).toHaveProperty('parent', node);
    });

    it('an array of ExpressionProps', () => {
      node.append([{text: 'bar'}]);
      expect(node.nodes[0]).toBeInstanceOf(Argument);
      expect(node.nodes[0].name).toBeUndefined();
      expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[0]).toHaveProperty('parent', node);
    });

    it('a single pair', () => {
      node.append(['foo', {text: 'bar'}]);
      expect(node.nodes[0]).toBeInstanceOf(Argument);
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[0]).toHaveProperty('parent', node);
    });

    it('a list of pairs', () => {
      node.append([
        ['foo', {text: 'bar'}],
        ['baz', {text: 'qux'}],
      ]);
      expect(node.nodes[0]).toBeInstanceOf(Argument);
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[0]).toHaveProperty('parent', node);
      expect(node.nodes[1]).toBeInstanceOf(Argument);
      expect(node.nodes[1].name).toBe('baz');
      expect(node.nodes[1]).toHaveStringExpression('value', 'qux');
      expect(node.nodes[1]).toHaveProperty('parent', node);
    });

    it('a single ArgumentProps', () => {
      node.append({value: {text: 'bar'}});
      expect(node.nodes[0]).toBeInstanceOf(Argument);
      expect(node.nodes[0].name).toBeUndefined();
      expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[0]).toHaveProperty('parent', node);
    });

    it('multiple ArgumentProps', () => {
      node.append([{value: {text: 'bar'}}, {value: {text: 'baz'}}]);
      expect(node.nodes[0]).toBeInstanceOf(Argument);
      expect(node.nodes[0].name).toBeUndefined();
      expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[0]).toHaveProperty('parent', node);
      expect(node.nodes[1]).toBeInstanceOf(Argument);
      expect(node.nodes[1].name).toBeUndefined();
      expect(node.nodes[1]).toHaveStringExpression('value', 'baz');
      expect(node.nodes[1]).toHaveProperty('parent', node);
    });

    it('undefined', () => {
      node.append(undefined);
      expect(node.nodes).toHaveLength(0);
    });
  });

  describe('append', () => {
    beforeEach(
      () => void (node = new ArgumentList([{text: 'foo'}, {text: 'bar'}])),
    );

    it('adds multiple children to the end', () => {
      node.append({text: 'baz'}, {text: 'qux'});
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[2]).toHaveStringExpression('value', 'baz');
      expect(node.nodes[3]).toHaveStringExpression('value', 'qux');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () =>
        node.append({text: 'baz'}),
      ));

    it('returns itself', () => expect(node.append()).toBe(node));
  });

  describe('each', () => {
    beforeEach(
      () => void (node = new ArgumentList([{text: 'foo'}, {text: 'bar'}])),
    );

    it('calls the callback for each node', () => {
      const fn: EachFn = jest.fn();
      node.each(fn);
      expect(fn).toHaveBeenCalledTimes(2);
      expect(fn).toHaveBeenNthCalledWith(
        1,
        expect.toHaveStringExpression('value', 'foo'),
        0,
      );
      expect(fn).toHaveBeenNthCalledWith(
        2,
        expect.toHaveStringExpression('value', 'bar'),
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
        void (node = new ArgumentList([
          {text: 'foo'},
          {text: 'bar'},
          {text: 'baz'},
        ])),
    );

    it('returns true if the callback returns true for all elements', () =>
      expect(node.every(() => true)).toBe(true));

    it('returns false if the callback returns false for any element', () =>
      expect(
        node.every(
          element => (element.value as StringExpression).text.asPlain !== 'bar',
        ),
      ).toBe(false));
  });

  describe('index', () => {
    beforeEach(
      () =>
        void (node = new ArgumentList([
          {text: 'foo'},
          {text: 'bar'},
          {text: 'baz'},
        ])),
    );

    it('returns the first index of a given argument', () =>
      expect(node.index(node.nodes[2])).toBe(2));

    it('returns a number as-is', () => expect(node.index(3)).toBe(3));
  });

  describe('insertAfter', () => {
    beforeEach(
      () =>
        void (node = new ArgumentList({
          nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
        })),
    );

    it('inserts a node after the given element', () => {
      node.insertAfter(node.nodes[1], {text: 'qux'});
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[2]).toHaveStringExpression('value', 'qux');
      expect(node.nodes[3]).toHaveStringExpression('value', 'baz');
    });

    it('inserts a node at the beginning', () => {
      node.insertAfter(-1, {text: 'qux'});
      expect(node.nodes[0]).toHaveStringExpression('value', 'qux');
      expect(node.nodes[1]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[2]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[3]).toHaveStringExpression('value', 'baz');
    });

    it('inserts a node at the end', () => {
      node.insertAfter(3, {text: 'qux'});
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[2]).toHaveStringExpression('value', 'baz');
      expect(node.nodes[3]).toHaveStringExpression('value', 'qux');
    });

    it('inserts multiple nodes', () => {
      node.insertAfter(1, [{text: 'qux'}, {text: 'qax'}, {text: 'qix'}]);
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[2]).toHaveStringExpression('value', 'qux');
      expect(node.nodes[3]).toHaveStringExpression('value', 'qax');
      expect(node.nodes[4]).toHaveStringExpression('value', 'qix');
      expect(node.nodes[5]).toHaveStringExpression('value', 'baz');
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
      expect(node.insertAfter(0, {text: 'qux'})).toBe(node));
  });

  describe('insertBefore', () => {
    beforeEach(
      () =>
        void (node = new ArgumentList([
          {text: 'foo'},
          {text: 'bar'},
          {text: 'baz'},
        ])),
    );

    it('inserts a node before the given element', () => {
      node.insertBefore(node.nodes[1], {text: 'qux'});
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('value', 'qux');
      expect(node.nodes[2]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[3]).toHaveStringExpression('value', 'baz');
    });

    it('inserts a node at the beginning', () => {
      node.insertBefore(0, {text: 'qux'});
      expect(node.nodes[0]).toHaveStringExpression('value', 'qux');
      expect(node.nodes[1]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[2]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[3]).toHaveStringExpression('value', 'baz');
    });

    it('inserts a node at the end', () => {
      node.insertBefore(4, {text: 'qux'});
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[2]).toHaveStringExpression('value', 'baz');
      expect(node.nodes[3]).toHaveStringExpression('value', 'qux');
    });

    it('inserts multiple nodes', () => {
      node.insertBefore(1, [{text: 'qux'}, {text: 'qax'}, {text: 'qix'}]);
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('value', 'qux');
      expect(node.nodes[2]).toHaveStringExpression('value', 'qax');
      expect(node.nodes[3]).toHaveStringExpression('value', 'qix');
      expect(node.nodes[4]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[5]).toHaveStringExpression('value', 'baz');
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
      expect(node.insertBefore(0, {text: 'qux'})).toBe(node));
  });

  describe('prepend', () => {
    beforeEach(
      () =>
        void (node = new ArgumentList([
          {text: 'foo'},
          {text: 'bar'},
          {text: 'baz'},
        ])),
    );

    it('inserts one node', () => {
      node.prepend({text: 'qux'});
      expect(node.nodes[0]).toHaveStringExpression('value', 'qux');
      expect(node.nodes[1]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[2]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[3]).toHaveStringExpression('value', 'baz');
    });

    it('inserts multiple nodes', () => {
      node.prepend({text: 'qux'}, {text: 'qax'}, {text: 'qix'});
      expect(node.nodes[0]).toHaveStringExpression('value', 'qux');
      expect(node.nodes[1]).toHaveStringExpression('value', 'qax');
      expect(node.nodes[2]).toHaveStringExpression('value', 'qix');
      expect(node.nodes[3]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[4]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[5]).toHaveStringExpression('value', 'baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.prepend({text: 'qux'}, {text: 'qax'}, {text: 'qix'}),
      ));

    it('returns itself', () => expect(node.prepend({text: 'qux'})).toBe(node));
  });

  describe('push', () => {
    beforeEach(
      () => void (node = new ArgumentList([{text: 'foo'}, {text: 'bar'}])),
    );

    it('inserts one node', () => {
      node.push(new Argument({text: 'baz'}));
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[2]).toHaveStringExpression('value', 'baz');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () =>
        node.push(new Argument({text: 'baz'})),
      ));

    it('returns itself', () =>
      expect(node.push(new Argument({text: 'baz'}))).toBe(node));
  });

  describe('removeAll', () => {
    beforeEach(
      () =>
        void (node = new ArgumentList([
          {text: 'foo'},
          {text: 'bar'},
          {text: 'baz'},
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
        void (node = new ArgumentList([
          {text: 'foo'},
          {text: 'bar'},
          {text: 'baz'},
        ])),
    );

    it('removes a matching node', () => {
      node.removeChild(node.nodes[0]);
      expect(node.nodes[0]).toHaveStringExpression('value', 'bar');
      expect(node.nodes[1]).toHaveStringExpression('value', 'baz');
    });

    it('removes a node at index', () => {
      node.removeChild(1);
      expect(node.nodes[0]).toHaveStringExpression('value', 'foo');
      expect(node.nodes[1]).toHaveStringExpression('value', 'baz');
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
        void (node = new ArgumentList([
          {text: 'foo'},
          {text: 'bar'},
          {text: 'baz'},
        ])),
    );

    it('returns false if the callback returns false for all elements', () =>
      expect(node.some(() => false)).toBe(false));

    it('returns true if the callback returns true for any element', () =>
      expect(
        node.some(
          element => (element.value as StringExpression).text.asPlain === 'bar',
        ),
      ).toBe(true));
  });

  describe('first', () => {
    it('returns the first element', () =>
      expect(
        new ArgumentList([{text: 'foo'}, {text: 'bar'}, {text: 'baz'}]).first,
      ).toHaveStringExpression('value', 'foo'));

    it('returns undefined for an empty list', () =>
      expect(new ArgumentList().first).toBeUndefined());
  });

  describe('last', () => {
    it('returns the last element', () =>
      expect(
        new ArgumentList({nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}]})
          .last,
      ).toHaveStringExpression('value', 'baz'));

    it('returns undefined for an empty list', () =>
      expect(new ArgumentList().last).toBeUndefined());
  });

  describe('stringifies', () => {
    describe('with no nodes', () => {
      it('with default raws', () =>
        expect(new ArgumentList().toString()).toBe('()'));

      it('ignores comma', () =>
        expect(new ArgumentList({raws: {comma: true}}).toString()).toBe('()'));

      it('with after', () =>
        expect(new ArgumentList({raws: {after: '/**/'}}).toString()).toBe(
          '(/**/)',
        ));
    });

    describe('with arguments', () => {
      it('with default raws', () =>
        expect(
          new ArgumentList([
            {text: 'foo'},
            {text: 'bar'},
            {text: 'baz'},
          ]).toString(),
        ).toBe('(foo, bar, baz)'));

      it('with comma: true', () =>
        expect(
          new ArgumentList({
            nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
            raws: {comma: true},
          }).toString(),
        ).toBe('(foo, bar, baz,)'));

      describe('with after', () => {
        it('with comma: false', () =>
          expect(
            new ArgumentList({
              nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('(foo, bar, baz/**/)'));

        it('with comma: true', () =>
          expect(
            new ArgumentList({
              nodes: [{text: 'foo'}, {text: 'bar'}, {text: 'baz'}],
              raws: {comma: true, after: '/**/'},
            }).toString(),
          ).toBe('(foo, bar, baz,/**/)'));
      });

      describe('with a argument with after', () => {
        it('with comma: false and no after', () =>
          expect(
            new ArgumentList({
              nodes: [
                {text: 'foo'},
                {text: 'bar'},
                new Argument({value: {text: 'baz'}, raws: {after: '  '}}),
              ],
            }).toString(),
          ).toBe('(foo, bar, baz  )'));

        it('with comma: false and after', () =>
          expect(
            new ArgumentList({
              nodes: [
                {text: 'foo'},
                {text: 'bar'},
                new Argument({value: {text: 'baz'}, raws: {after: '  '}}),
              ],
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('(foo, bar, baz  /**/)'));

        it('with comma: true', () =>
          expect(
            new ArgumentList({
              nodes: [
                {text: 'foo'},
                {text: 'bar'},
                new Argument({value: {text: 'baz'}, raws: {after: '  '}}),
              ],
              raws: {comma: true},
            }).toString(),
          ).toBe('(foo, bar, baz  ,)'));
      });
    });
  });

  describe('clone', () => {
    let original: ArgumentList;
    beforeEach(
      () =>
        void (original = new ArgumentList({
          nodes: [{text: 'foo'}, {text: 'bar'}],
          raws: {after: '  '},
        })),
    );

    describe('with no overrides', () => {
      let clone: ArgumentList;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('nodes', () => {
          expect(clone.nodes[0]).toHaveStringExpression('value', 'foo');
          expect(clone.nodes[0].parent).toBe(clone);
          expect(clone.nodes[1]).toHaveStringExpression('value', 'bar');
          expect(clone.nodes[1].parent).toBe(clone);
        });

        it('raws', () => expect(clone.raws).toEqual({after: '  '}));

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
          expect(clone.nodes[0]).toHaveProperty('parent', clone));
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {comma: true}}).raws).toEqual({
            comma: true,
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            after: '  ',
          }));
      });

      describe('nodes', () => {
        it('defined', () => {
          const clone = original.clone({nodes: [{text: 'qux'}]});
          expect(clone.nodes[0]).toHaveStringExpression('value', 'qux');
        });

        it('undefined', () => {
          const clone = original.clone({nodes: undefined});
          expect(clone.nodes).toHaveLength(2);
          expect(clone.nodes[0]).toHaveStringExpression('value', 'foo');
          expect(clone.nodes[1]).toHaveStringExpression('value', 'bar');
        });
      });
    });
  });

  it('toJSON', () =>
    expect(
      (scss.parse('@include x(foo, bar...)').nodes[0] as IncludeRule).arguments,
    ).toMatchSnapshot());
});

/**
 * Runs `node.each`, asserting that it sees an argument with each string value
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
    const [text, index] = Array.isArray(element) ? element : [element, i];
    expect(fn).toHaveBeenNthCalledWith(
      i + 1,
      expect.toHaveStringExpression('value', text),
      index,
    );
  }
  expect(fn).toHaveBeenCalledTimes(elements.length);
}
