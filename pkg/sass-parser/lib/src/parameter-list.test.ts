// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {FunctionRule, Parameter, ParameterList, sass, scss} from '..';

type EachFn = Parameters<ParameterList['each']>[0];

let node: ParameterList;
describe('a parameter list', () => {
  describe('empty', () => {
    function describeNode(
      description: string,
      create: () => ParameterList,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () =>
          expect(node.sassType).toBe('parameter-list'));

        it('has no nodes', () => expect(node.nodes).toHaveLength(0));

        it('has no rest parameter', () =>
          expect(node.restParameter).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@function x() {}').nodes[0] as FunctionRule).parameters,
    );

    describeNode(
      'parsed as Sass',
      () => (sass.parse('@function x()').nodes[0] as FunctionRule).parameters,
    );

    describe('constructed manually', () => {
      describeNode('with no arguments', () => new ParameterList());

      describeNode('with an array', () => new ParameterList([]));

      describeNode('with an object', () => new ParameterList({}));

      describeNode(
        'with an object with an array',
        () => new ParameterList({nodes: []}),
      );
    });

    describe('constructed from properties', () => {
      describeNode(
        'an object',
        () => new FunctionRule({functionName: 'x', parameters: {}}).parameters,
      );

      describeNode(
        'an array',
        () => new FunctionRule({functionName: 'x', parameters: []}).parameters,
      );
    });
  });

  describe('with an argument with no default', () => {
    function describeNode(
      description: string,
      create: () => ParameterList,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () =>
          expect(node.sassType).toBe('parameter-list'));

        it('has a node', () => {
          expect(node.nodes.length).toBe(1);
          expect(node.nodes[0].name).toBe('foo');
          expect(node.nodes[0].defaultValue).toBeUndefined();
          expect(node.nodes[0].parent).toBe(node);
        });

        it('has no rest parameter', () =>
          expect(node.restParameter).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@function x($foo) {}').nodes[0] as FunctionRule)
          .parameters,
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@function x($foo)').nodes[0] as FunctionRule).parameters,
    );

    describe('constructed manually', () => {
      describe('with an array', () => {
        describeNode('with a string', () => new ParameterList(['foo']));

        describeNode(
          'with an object',
          () => new ParameterList([{name: 'foo'}]),
        );

        describeNode(
          'with a Parameter',
          () => new ParameterList([new Parameter('foo')]),
        );
      });

      describe('with an object', () => {
        describeNode(
          'with a string',
          () => new ParameterList({nodes: ['foo']}),
        );

        describeNode(
          'with an object',
          () => new ParameterList({nodes: [{name: 'foo'}]}),
        );

        describeNode(
          'with a Parameter',
          () => new ParameterList({nodes: [new Parameter('foo')]}),
        );
      });
    });

    describe('constructed from properties', () => {
      describeNode(
        'an object',
        () =>
          new FunctionRule({functionName: 'x', parameters: {nodes: ['foo']}})
            .parameters,
      );

      describeNode(
        'an array',
        () =>
          new FunctionRule({functionName: 'x', parameters: ['foo']}).parameters,
      );
    });
  });

  describe('with an argument with a default', () => {
    function describeNode(
      description: string,
      create: () => ParameterList,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () =>
          expect(node.sassType).toBe('parameter-list'));

        it('has a node', () => {
          expect(node.nodes.length).toBe(1);
          expect(node.nodes[0].name).toBe('foo');
          expect(node.nodes[0]).toHaveStringExpression('defaultValue', 'bar');
          expect(node.nodes[0]).toHaveProperty('parent', node);
        });

        it('has no rest parameter', () =>
          expect(node.restParameter).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@function x($foo: "bar") {}').nodes[0] as FunctionRule)
          .parameters,
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@function x($foo: "bar")').nodes[0] as FunctionRule)
          .parameters,
    );

    describe('constructed manually', () => {
      describe('with an array', () => {
        describeNode(
          'with a sub-array',
          () => new ParameterList([['foo', {text: 'bar'}]]),
        );

        describeNode(
          'with an object',
          () => new ParameterList([{name: 'foo', defaultValue: {text: 'bar'}}]),
        );

        describeNode(
          'with a Parameter',
          () =>
            new ParameterList([
              new Parameter({name: 'foo', defaultValue: {text: 'bar'}}),
            ]),
        );
      });

      describe('with an object', () => {
        describeNode(
          'with a sub-array',
          () => new ParameterList({nodes: [['foo', {text: 'bar'}]]}),
        );

        describeNode(
          'with an object',
          () =>
            new ParameterList({
              nodes: [{name: 'foo', defaultValue: {text: 'bar'}}],
            }),
        );

        describeNode(
          'with a Parameter',
          () =>
            new ParameterList({
              nodes: [
                new Parameter({name: 'foo', defaultValue: {text: 'bar'}}),
              ],
            }),
        );
      });
    });

    describe('constructed from properties', () => {
      describeNode(
        'an object',
        () =>
          new FunctionRule({
            functionName: 'x',
            parameters: {nodes: [['foo', {text: 'bar'}]]},
          }).parameters,
      );

      describeNode(
        'an array',
        () =>
          new FunctionRule({
            functionName: 'x',
            parameters: [['foo', {text: 'bar'}]],
          }).parameters,
      );
    });
  });

  describe('with a rest parameter', () => {
    function describeNode(
      description: string,
      create: () => ParameterList,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () =>
          expect(node.sassType).toBe('parameter-list'));

        it('has no nodes', () => expect(node.nodes).toHaveLength(0));

        it('has a rest parameter', () =>
          expect(node.restParameter).toBe('foo'));
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@function x($foo...) {}').nodes[0] as FunctionRule)
          .parameters,
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@function x($foo...)').nodes[0] as FunctionRule)
          .parameters,
    );

    describeNode(
      'constructed manually',
      () => new ParameterList({restParameter: 'foo'}),
    );

    describeNode(
      'constructed from properties',
      () =>
        new FunctionRule({
          functionName: 'x',
          parameters: {restParameter: 'foo'},
        }).parameters,
    );
  });

  it('assigned a new rest parameter', () => {
    node.restParameter = 'qux';
    expect(node.restParameter).toBe('qux');
  });

  describe('can add', () => {
    beforeEach(() => void (node = new ParameterList()));

    it('a single parameter', () => {
      const parameter = new Parameter('foo');
      node.append(parameter);
      expect(node.nodes).toEqual([parameter]);
      expect(parameter).toHaveProperty('parent', node);
    });

    it('a list of parameters', () => {
      const foo = new Parameter('foo');
      const bar = new Parameter('bar');
      node.append([foo, bar]);
      expect(node.nodes).toEqual([foo, bar]);
    });

    it('a single string', () => {
      node.append('foo');
      expect(node.nodes[0]).toBeInstanceOf(Parameter);
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[0].defaultValue).toBeUndefined();
      expect(node.nodes[0]).toHaveProperty('parent', node);
    });

    it('a string array', () => {
      node.append(['foo']);
      expect(node.nodes[0]).toBeInstanceOf(Parameter);
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[0].defaultValue).toBeUndefined();
      expect(node.nodes[0]).toHaveProperty('parent', node);
    });

    it('a single pair', () => {
      node.append(['foo', {text: 'bar'}]);
      expect(node.nodes[0]).toBeInstanceOf(Parameter);
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[0]).toHaveStringExpression('defaultValue', 'bar');
      expect(node.nodes[0]).toHaveProperty('parent', node);
    });

    it('a list of pairs', () => {
      node.append([
        ['foo', {text: 'bar'}],
        ['baz', {text: 'qux'}],
      ]);
      expect(node.nodes[0]).toBeInstanceOf(Parameter);
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[0]).toHaveStringExpression('defaultValue', 'bar');
      expect(node.nodes[0]).toHaveProperty('parent', node);
      expect(node.nodes[1]).toBeInstanceOf(Parameter);
      expect(node.nodes[1].name).toBe('baz');
      expect(node.nodes[1]).toHaveStringExpression('defaultValue', 'qux');
      expect(node.nodes[1]).toHaveProperty('parent', node);
    });

    it("a single parameter's properties", () => {
      node.append({name: 'foo'});
      expect(node.nodes[0]).toBeInstanceOf(Parameter);
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[0].defaultValue).toBeUndefined();
      expect(node.nodes[0]).toHaveProperty('parent', node);
    });

    it("multiple parameters' properties", () => {
      node.append([{name: 'foo'}, {name: 'bar'}]);
      expect(node.nodes[0]).toBeInstanceOf(Parameter);
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[0].defaultValue).toBeUndefined();
      expect(node.nodes[0]).toHaveProperty('parent', node);
      expect(node.nodes[1]).toBeInstanceOf(Parameter);
      expect(node.nodes[1].name).toBe('bar');
      expect(node.nodes[1].defaultValue).toBeUndefined();
      expect(node.nodes[1]).toHaveProperty('parent', node);
    });

    it('undefined', () => {
      node.append(undefined);
      expect(node.nodes).toHaveLength(0);
    });
  });

  describe('append', () => {
    beforeEach(() => void (node = new ParameterList(['foo', 'bar'])));

    it('adds multiple children to the end', () => {
      node.append('baz', 'qux');
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[1].name).toBe('bar');
      expect(node.nodes[2].name).toBe('baz');
      expect(node.nodes[3].name).toBe('qux');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () => node.append('baz')));

    it('returns itself', () => expect(node.append()).toBe(node));
  });

  describe('each', () => {
    beforeEach(() => void (node = new ParameterList(['foo', 'bar'])));

    it('calls the callback for each node', () => {
      const fn: EachFn = jest.fn();
      node.each(fn);
      expect(fn).toHaveBeenCalledTimes(2);
      expect(fn).toHaveBeenNthCalledWith(
        1,
        expect.objectContaining({name: 'foo'}),
        0,
      );
      expect(fn).toHaveBeenNthCalledWith(
        2,
        expect.objectContaining({name: 'bar'}),
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
    beforeEach(() => void (node = new ParameterList(['foo', 'bar', 'baz'])));

    it('returns true if the callback returns true for all elements', () =>
      expect(node.every(() => true)).toBe(true));

    it('returns false if the callback returns false for any element', () =>
      expect(node.every(element => element.name !== 'bar')).toBe(false));
  });

  describe('index', () => {
    beforeEach(() => void (node = new ParameterList(['foo', 'bar', 'baz'])));

    it('returns the first index of a given parameter', () =>
      expect(node.index(node.nodes[2])).toBe(2));

    it('returns a number as-is', () => expect(node.index(3)).toBe(3));
  });

  describe('insertAfter', () => {
    beforeEach(
      () => void (node = new ParameterList({nodes: ['foo', 'bar', 'baz']})),
    );

    it('inserts a node after the given element', () => {
      node.insertAfter(node.nodes[1], 'qux');
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[1].name).toBe('bar');
      expect(node.nodes[2].name).toBe('qux');
      expect(node.nodes[3].name).toBe('baz');
    });

    it('inserts a node at the beginning', () => {
      node.insertAfter(-1, 'qux');
      expect(node.nodes[0].name).toBe('qux');
      expect(node.nodes[1].name).toBe('foo');
      expect(node.nodes[2].name).toBe('bar');
      expect(node.nodes[3].name).toBe('baz');
    });

    it('inserts a node at the end', () => {
      node.insertAfter(3, 'qux');
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[1].name).toBe('bar');
      expect(node.nodes[2].name).toBe('baz');
      expect(node.nodes[3].name).toBe('qux');
    });

    it('inserts multiple nodes', () => {
      node.insertAfter(1, ['qux', 'qax', 'qix']);
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[1].name).toBe('bar');
      expect(node.nodes[2].name).toBe('qux');
      expect(node.nodes[3].name).toBe('qax');
      expect(node.nodes[4].name).toBe('qix');
      expect(node.nodes[5].name).toBe('baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertAfter(0, ['qux', 'qax', 'qix']),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertAfter(1, ['qux', 'qax', 'qix']),
      ));

    it('returns itself', () => expect(node.insertAfter(0, 'qux')).toBe(node));
  });

  describe('insertBefore', () => {
    beforeEach(() => void (node = new ParameterList(['foo', 'bar', 'baz'])));

    it('inserts a node before the given element', () => {
      node.insertBefore(node.nodes[1], 'qux');
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[1].name).toBe('qux');
      expect(node.nodes[2].name).toBe('bar');
      expect(node.nodes[3].name).toBe('baz');
    });

    it('inserts a node at the beginning', () => {
      node.insertBefore(0, 'qux');
      expect(node.nodes[0].name).toBe('qux');
      expect(node.nodes[1].name).toBe('foo');
      expect(node.nodes[2].name).toBe('bar');
      expect(node.nodes[3].name).toBe('baz');
    });

    it('inserts a node at the end', () => {
      node.insertBefore(4, 'qux');
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[1].name).toBe('bar');
      expect(node.nodes[2].name).toBe('baz');
      expect(node.nodes[3].name).toBe('qux');
    });

    it('inserts multiple nodes', () => {
      node.insertBefore(1, ['qux', 'qax', 'qix']);
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[1].name).toBe('qux');
      expect(node.nodes[2].name).toBe('qax');
      expect(node.nodes[3].name).toBe('qix');
      expect(node.nodes[4].name).toBe('bar');
      expect(node.nodes[5].name).toBe('baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.insertBefore(1, ['qux', 'qax', 'qix']),
      ));

    it('inserts after an iterator', () =>
      testEachMutation(['foo', 'bar', 'qux', 'qax', 'qix', 'baz'], 1, () =>
        node.insertBefore(2, ['qux', 'qax', 'qix']),
      ));

    it('returns itself', () => expect(node.insertBefore(0, 'qux')).toBe(node));
  });

  describe('prepend', () => {
    beforeEach(() => void (node = new ParameterList(['foo', 'bar', 'baz'])));

    it('inserts one node', () => {
      node.prepend('qux');
      expect(node.nodes[0].name).toBe('qux');
      expect(node.nodes[1].name).toBe('foo');
      expect(node.nodes[2].name).toBe('bar');
      expect(node.nodes[3].name).toBe('baz');
    });

    it('inserts multiple nodes', () => {
      node.prepend('qux', 'qax', 'qix');
      expect(node.nodes[0].name).toBe('qux');
      expect(node.nodes[1].name).toBe('qax');
      expect(node.nodes[2].name).toBe('qix');
      expect(node.nodes[3].name).toBe('foo');
      expect(node.nodes[4].name).toBe('bar');
      expect(node.nodes[5].name).toBe('baz');
    });

    it('inserts before an iterator', () =>
      testEachMutation(['foo', 'bar', ['baz', 5]], 1, () =>
        node.prepend('qux', 'qax', 'qix'),
      ));

    it('returns itself', () => expect(node.prepend('qux')).toBe(node));
  });

  describe('push', () => {
    beforeEach(() => void (node = new ParameterList(['foo', 'bar'])));

    it('inserts one node', () => {
      node.push(new Parameter('baz'));
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[1].name).toBe('bar');
      expect(node.nodes[2].name).toBe('baz');
    });

    it('can be called during iteration', () =>
      testEachMutation(['foo', 'bar', 'baz'], 0, () =>
        node.push(new Parameter('baz')),
      ));

    it('returns itself', () =>
      expect(node.push(new Parameter('baz'))).toBe(node));
  });

  describe('removeAll', () => {
    beforeEach(() => void (node = new ParameterList(['foo', 'bar', 'baz'])));

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
    beforeEach(() => void (node = new ParameterList(['foo', 'bar', 'baz'])));

    it('removes a matching node', () => {
      node.removeChild(node.nodes[0]);
      expect(node.nodes[0].name).toBe('bar');
      expect(node.nodes[1].name).toBe('baz');
    });

    it('removes a node at index', () => {
      node.removeChild(1);
      expect(node.nodes[0].name).toBe('foo');
      expect(node.nodes[1].name).toBe('baz');
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
    beforeEach(() => void (node = new ParameterList(['foo', 'bar', 'baz'])));

    it('returns false if the callback returns false for all elements', () =>
      expect(node.some(() => false)).toBe(false));

    it('returns true if the callback returns true for any element', () =>
      expect(node.some(element => element.name === 'bar')).toBe(true));
  });

  describe('first', () => {
    it('returns the first element', () =>
      expect(new ParameterList(['foo', 'bar', 'baz']).first!.name).toBe('foo'));

    it('returns undefined for an empty list', () =>
      expect(new ParameterList().first).toBeUndefined());
  });

  describe('last', () => {
    it('returns the last element', () =>
      expect(new ParameterList({nodes: ['foo', 'bar', 'baz']}).last!.name).toBe(
        'baz',
      ));

    it('returns undefined for an empty list', () =>
      expect(new ParameterList().last).toBeUndefined());
  });

  describe('stringifies', () => {
    describe('with no nodes or rest parameter', () => {
      it('with default raws', () =>
        expect(new ParameterList().toString()).toBe('()'));

      it('ignores restParameter', () =>
        expect(
          new ParameterList({
            raws: {restParameter: {value: 'foo', raw: 'foo'}},
          }).toString(),
        ).toBe('()'));

      it('ignores comma', () =>
        expect(new ParameterList({raws: {comma: true}}).toString()).toBe('()'));

      it('with after', () =>
        expect(new ParameterList({raws: {after: '/**/'}}).toString()).toBe(
          '(/**/)',
        ));
    });

    describe('with parameters', () => {
      it('with default raws', () =>
        expect(new ParameterList(['foo', 'bar', 'baz']).toString()).toBe(
          '($foo, $bar, $baz)',
        ));

      it('ignores beforeRestParameter', () =>
        expect(
          new ParameterList({
            nodes: ['foo', 'bar', 'baz'],
            raws: {beforeRestParameter: '/**/'},
          }).toString(),
        ).toBe('($foo, $bar, $baz)'));

      it('ignores restParameter', () =>
        expect(
          new ParameterList({
            nodes: ['foo', 'bar', 'baz'],
            raws: {restParameter: {value: 'foo', raw: 'foo'}},
          }).toString(),
        ).toBe('($foo, $bar, $baz)'));

      it('with comma: true', () =>
        expect(
          new ParameterList({
            nodes: ['foo', 'bar', 'baz'],
            raws: {comma: true},
          }).toString(),
        ).toBe('($foo, $bar, $baz,)'));

      describe('with after', () => {
        it('with comma: false', () =>
          expect(
            new ParameterList({
              nodes: ['foo', 'bar', 'baz'],
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('($foo, $bar, $baz/**/)'));

        it('with comma: true', () =>
          expect(
            new ParameterList({
              nodes: ['foo', 'bar', 'baz'],
              raws: {comma: true, after: '/**/'},
            }).toString(),
          ).toBe('($foo, $bar, $baz,/**/)'));
      });

      describe('with a parameter with after', () => {
        it('with comma: false and no after', () =>
          expect(
            new ParameterList({
              nodes: [
                'foo',
                'bar',
                new Parameter({name: 'baz', raws: {after: '  '}}),
              ],
            }).toString(),
          ).toBe('($foo, $bar, $baz  )'));

        it('with comma: false and after', () =>
          expect(
            new ParameterList({
              nodes: [
                'foo',
                'bar',
                new Parameter({name: 'baz', raws: {after: '  '}}),
              ],
              raws: {after: '/**/'},
            }).toString(),
          ).toBe('($foo, $bar, $baz  /**/)'));

        it('with comma: true', () =>
          expect(
            new ParameterList({
              nodes: [
                'foo',
                'bar',
                new Parameter({name: 'baz', raws: {after: '  '}}),
              ],
              raws: {comma: true},
            }).toString(),
          ).toBe('($foo, $bar, $baz  ,)'));
      });
    });

    describe('with restParameter', () => {
      it('with default raws', () =>
        expect(new ParameterList({restParameter: 'foo'}).toString()).toBe(
          '($foo...)',
        ));

      it("that's not an identifier", () =>
        expect(new ParameterList({restParameter: 'f o'}).toString()).toBe(
          '($f\\20o...)',
        ));

      it('with parameters', () =>
        expect(
          new ParameterList({
            nodes: ['foo', 'bar'],
            restParameter: 'baz',
          }).toString(),
        ).toBe('($foo, $bar, $baz...)'));

      describe('with beforeRestParameter', () => {
        it('with no parameters', () =>
          expect(
            new ParameterList({
              restParameter: 'foo',
              raws: {beforeRestParameter: '/**/'},
            }).toString(),
          ).toBe('(/**/$foo...)'));

        it('with parameters', () =>
          expect(
            new ParameterList({
              nodes: ['foo', 'bar'],
              restParameter: 'baz',
              raws: {beforeRestParameter: '/**/'},
            }).toString(),
          ).toBe('($foo, $bar,/**/$baz...)'));
      });

      it('with matching restParameter', () =>
        expect(
          new ParameterList({
            restParameter: 'foo',
            raws: {restParameter: {value: 'foo', raw: 'f\\6fo'}},
          }).toString(),
        ).toBe('($f\\6fo...)'));

      it('with non-matching restParameter', () =>
        expect(
          new ParameterList({
            restParameter: 'foo',
            raws: {restParameter: {value: 'bar', raw: 'b\\61r'}},
          }).toString(),
        ).toBe('($foo...)'));

      it('ignores comma', () =>
        expect(
          new ParameterList({
            restParameter: 'foo',
            raws: {comma: true},
          }).toString(),
        ).toBe('($foo...)'));

      it('with after', () =>
        expect(
          new ParameterList({
            restParameter: 'foo',
            raws: {after: '/**/'},
          }).toString(),
        ).toBe('($foo.../**/)'));
    });
  });

  describe('clone', () => {
    let original: ParameterList;
    beforeEach(
      () =>
        void (original = new ParameterList({
          nodes: ['foo', 'bar'],
          restParameter: 'baz',
          raws: {after: '  '},
        })),
    );

    describe('with no overrides', () => {
      let clone: ParameterList;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('nodes', () => {
          expect(clone.nodes[0].name).toBe('foo');
          expect(clone.nodes[0].parent).toBe(clone);
          expect(clone.nodes[1].name).toBe('bar');
          expect(clone.nodes[1].parent).toBe(clone);
          expect(clone.restParameter).toBe('baz');
        });

        it('restParameter', () => expect(clone.restParameter).toBe('baz'));

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
          const clone = original.clone({nodes: ['qux']});
          expect(clone.nodes[0].name).toBe('qux');
        });

        it('undefined', () => {
          const clone = original.clone({nodes: undefined});
          expect(clone.nodes).toHaveLength(2);
          expect(clone.nodes[0].name).toBe('foo');
          expect(clone.nodes[1].name).toBe('bar');
        });
      });

      describe('restParameter', () => {
        it('defined', () =>
          expect(original.clone({restParameter: 'qux'}).restParameter).toBe(
            'qux',
          ));

        it('undefined', () =>
          expect(
            original.clone({restParameter: undefined}).restParameter,
          ).toBeUndefined());
      });
    });
  });

  it('toJSON', () =>
    expect(
      (scss.parse('@function x($foo, $bar...) {}').nodes[0] as FunctionRule)
        .parameters,
    ).toMatchSnapshot());
});

/**
 * Runs `node.each`, asserting that it sees a parameter with each name and index
 * in {@link elements} in order. If an index isn't explicitly provided, it
 * defaults to the index in {@link elements}.
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
    const [name, index] = Array.isArray(element) ? element : [element, i];
    expect(fn).toHaveBeenNthCalledWith(
      i + 1,
      expect.objectContaining({name}),
      index,
    );
  }
  expect(fn).toHaveBeenCalledTimes(elements.length);
}
