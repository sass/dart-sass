// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Interpolation, PseudoSelector, SelectorList} from '../..';
import {
  fromSimpleSelectorProps,
  parseSimpleSelector,
} from '../../../test/utils';

describe('a pseudo selector', () => {
  let node: PseudoSelector;

  describe('without an argument or selector', () => {
    function describeNode(
      description: string,
      create: () => PseudoSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType pseudo', () => expect(node.sassType).toBe('pseudo'));

        it('has a name', () =>
          expect(node).toHaveInterpolation('pseudo', 'foo'));

        it('is a pseudo-class', () => expect(node.isClass).toBe(true));

        it('is not a pseudo-element', () => expect(node.isElement).toBe(false));

        it('has no argument', () => expect(node.argument).toBeUndefined());

        it('has no selector', () => expect(node.selector).toBeUndefined());
      });
    }

    describeNode('parsed', () => parseSimpleSelector(':foo'));

    describeNode(
      'constructed manually',
      () => new PseudoSelector({pseudo: 'foo'}),
    );

    describeNode('from props', () => fromSimpleSelectorProps({pseudo: 'foo'}));
  });

  describe('a pseudo-element', () => {
    function describeNode(
      description: string,
      create: () => PseudoSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType pseudo', () => expect(node.sassType).toBe('pseudo'));

        it('has a name', () =>
          expect(node).toHaveInterpolation('pseudo', 'foo'));

        it('is not a pseudo-class', () => expect(node.isClass).toBe(false));

        it('is a pseudo-element', () => expect(node.isElement).toBe(true));

        it('has no argument', () => expect(node.argument).toBeUndefined());

        it('has no selector', () => expect(node.selector).toBeUndefined());
      });
    }

    describeNode('parsed', () => parseSimpleSelector('::foo'));

    describe('constructed manually', () => {
      describeNode(
        'with isElement: true',
        () => new PseudoSelector({pseudo: 'foo', isElement: true}),
      );

      describeNode(
        'with isClass: false',
        () => new PseudoSelector({pseudo: 'foo', isClass: false}),
      );
    });

    describe('from props', () => {
      describeNode('with isElement: true', () =>
        fromSimpleSelectorProps({pseudo: 'foo', isElement: true}),
      );

      describeNode('with isClass: false', () =>
        fromSimpleSelectorProps({pseudo: 'foo', isClass: false}),
      );
    });
  });

  describe('a fake pseudo-element', () => {
    function describeNode(
      description: string,
      create: () => PseudoSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType pseudo', () => expect(node.sassType).toBe('pseudo'));

        it('has a name', () =>
          expect(node).toHaveInterpolation('pseudo', 'after'));

        it('is not a pseudo-class', () => expect(node.isClass).toBe(true));

        it('is a pseudo-element', () => expect(node.isElement).toBe(false));

        it('has no argument', () => expect(node.argument).toBeUndefined());

        it('has no selector', () => expect(node.selector).toBeUndefined());
      });
    }

    describeNode('parsed', () => parseSimpleSelector(':after'));

    describeNode(
      'constructed manually',
      () => new PseudoSelector({pseudo: 'after'}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({pseudo: 'after'}),
    );
  });

  describe('with an argument and no selector', () => {
    function describeNode(
      description: string,
      create: () => PseudoSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType pseudo', () => expect(node.sassType).toBe('pseudo'));

        it('has a name', () =>
          expect(node).toHaveInterpolation('pseudo', 'foo'));

        it('is a pseudo-class', () => expect(node.isClass).toBe(true));

        it('is not a pseudo-element', () => expect(node.isElement).toBe(false));

        it('has an argument', () =>
          expect(node).toHaveInterpolation('argument', '&^*#'));

        it('has no selector', () => expect(node.selector).toBeUndefined());
      });
    }

    describeNode('parsed', () => parseSimpleSelector(':foo(&^*#)'));

    describeNode(
      'constructed manually',
      () => new PseudoSelector({pseudo: 'foo', argument: '&^*#'}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({pseudo: 'foo', argument: '&^*#'}),
    );
  });

  describe('with a selector and no argument', () => {
    function describeNode(
      description: string,
      create: () => PseudoSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType pseudo', () => expect(node.sassType).toBe('pseudo'));

        it('has a name', () =>
          expect(node).toHaveInterpolation('pseudo', 'is'));

        it('is a pseudo-class', () => expect(node.isClass).toBe(true));

        it('is not a pseudo-element', () => expect(node.isElement).toBe(false));

        it('has no argument', () => expect(node.argument).toBeUndefined());

        it('has a selector', () => {
          expect(node.selector!.sassType).toEqual('selector-list');
          expect(node.selector!.toString()).toEqual('.foo');
        });
      });
    }

    describeNode('parsed', () => parseSimpleSelector(':is(.foo)'));

    describeNode(
      'constructed manually',
      () => new PseudoSelector({pseudo: 'is', selector: {class: 'foo'}}),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({pseudo: 'is', selector: {class: 'foo'}}),
    );
  });

  describe('with a selector and an argument', () => {
    function describeNode(
      description: string,
      create: () => PseudoSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType pseudo', () => expect(node.sassType).toBe('pseudo'));

        it('has a name', () =>
          expect(node).toHaveInterpolation('pseudo', 'nth-child'));

        it('is a pseudo-class', () => expect(node.isClass).toBe(true));

        it('is not a pseudo-element', () => expect(node.isElement).toBe(false));

        it('has an argument', () =>
          expect(node).toHaveInterpolation('argument', '2n + 1 of'));

        it('has a selector', () => {
          expect(node.selector!.sassType).toEqual('selector-list');
          expect(node.selector!.parent).toBe(node);
          expect(node.selector!.toString()).toEqual('.foo');
        });
      });
    }

    describeNode('parsed', () =>
      parseSimpleSelector(':nth-child(2n + 1 of .foo)'),
    );

    describeNode(
      'constructed manually',
      () =>
        new PseudoSelector({
          pseudo: 'nth-child',
          argument: '2n + 1 of',
          selector: {class: 'foo'},
        }),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({
        pseudo: 'nth-child',
        argument: '2n + 1 of',
        selector: {class: 'foo'},
      }),
    );
  });

  describe('with an interpolated name and argument', () => {
    function describeNode(
      description: string,
      create: () => PseudoSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType pseudo', () => expect(node.sassType).toBe('pseudo'));

        it('has a name', () =>
          expect(node).toHaveInterpolation('pseudo', '#{foo}'));

        it('is a pseudo-class', () => expect(node.isClass).toBe(true));

        it('is not a pseudo-element', () => expect(node.isElement).toBe(false));

        it('has an argument', () =>
          expect(node.argument).toHaveStringExpression(0, 'bar'));

        it('has no selector', () => expect(node.selector).toBeUndefined());
      });
    }

    describeNode('parsed', () => parseSimpleSelector(':#{foo}(#{bar})'));

    describeNode(
      'constructed manually',
      () =>
        new PseudoSelector({
          pseudo: [{text: 'foo'}],
          argument: [{text: 'bar'}],
        }),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({
        pseudo: [{text: 'foo'}],
        argument: [{text: 'bar'}],
      }),
    );
  });

  describe('with an interpolated argument and a selector', () => {
    function describeNode(
      description: string,
      create: () => PseudoSelector,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType pseudo', () => expect(node.sassType).toBe('pseudo'));

        it('has a name', () =>
          expect(node).toHaveInterpolation('pseudo', 'nth-child'));

        it('is a pseudo-class', () => expect(node.isClass).toBe(true));

        it('is not a pseudo-element', () => expect(node.isElement).toBe(false));

        it('has an argument', () => {
          expect(node.argument).toHaveStringExpression(0, 'bar');
          expect(node.argument!.toString()).toEqual('#{bar} of');
        });

        it('has a selector', () => {
          expect(node.selector!.sassType).toEqual('selector-list');
          expect(node.selector!.parent).toBe(node);
          expect(node.selector!.toString()).toEqual('.foo');
        });
      });
    }

    describeNode('parsed', () =>
      parseSimpleSelector(':nth-child(#{bar} of .foo)'),
    );

    describeNode(
      'constructed manually',
      () =>
        new PseudoSelector({
          pseudo: 'nth-child',
          argument: [{text: 'bar'}, ' of'],
          selector: {class: 'foo'},
        }),
    );

    describeNode('from props', () =>
      fromSimpleSelectorProps({
        pseudo: 'nth-child',
        argument: [{text: 'bar'}, ' of'],
        selector: {class: 'foo'},
      }),
    );
  });

  describe('assigned new', () => {
    beforeEach(
      () => void (node = parseSimpleSelector(':nth-child(2n of .foo)')),
    );

    describe('pseudo', () => {
      it("removes the old pseudo's parent", () => {
        const oldPseudo = node.pseudo;
        node.pseudo = 'bar';
        expect(oldPseudo.parent).toBeUndefined();
      });

      it('assigns pseudo explicitly', () => {
        const pseudo = new Interpolation('bar');
        node.pseudo = pseudo;
        expect(node.pseudo).toBe(pseudo);
        expect(node).toHaveInterpolation('pseudo', 'bar');
      });

      it('assigns pseudo as InterpolationProps', () => {
        node.pseudo = 'bar';
        expect(node).toHaveInterpolation('pseudo', 'bar');
      });
    });

    describe('argument', () => {
      it("removes the old argument's parent", () => {
        const oldArgument = node.argument;
        node.argument = 'bar';
        expect(oldArgument!.parent).toBeUndefined();
      });

      it('assigns argument explicitly', () => {
        const argument = new Interpolation('bar');
        node.argument = argument;
        expect(node.argument).toBe(argument);
        expect(node).toHaveInterpolation('argument', 'bar');
      });

      it('assigns argument as InterpolationProps', () => {
        node.argument = 'bar';
        expect(node).toHaveInterpolation('argument', 'bar');
      });

      it('assigns undefined argument', () => {
        const oldArgument = node.argument;
        node.argument = undefined;
        expect(oldArgument!.parent).toBeUndefined();
        expect(node.argument).toBeUndefined();
      });
    });

    describe('selector', () => {
      it("removes the old selector's parent", () => {
        const oldSelector = node.selector;
        node.selector = {class: 'bar'};
        expect(oldSelector!.parent).toBeUndefined();
      });

      it('assigns selector explicitly', () => {
        const selector = new SelectorList({class: 'bar'});
        node.selector = selector;
        expect(node.selector).toBe(selector);
        expect(selector.parent).toBe(node);
      });

      it('assigns selector as SelectorListProps', () => {
        node.selector = {class: 'bar'};
        expect(node.selector!.toString()).toBe('.bar');
        expect(node.selector!.parent).toBe(node);
      });

      it('assigns undefined selector', () => {
        const oldSelector = node.selector;
        node.selector = undefined;
        expect(oldSelector!.parent).toBeUndefined();
        expect(node.selector).toBeUndefined();
      });
    });
  });

  it('assigned new name', () => {
    node = parseSimpleSelector(':foo') as PseudoSelector;
    node.pseudo = 'bar';
    expect(node).toHaveInterpolation('pseudo', 'bar');
  });

  it('assigned new class', () => {
    node = parseSimpleSelector(':foo') as PseudoSelector;
    node.isClass = false;
    expect(node.isClass).toBe(false);
    expect(node.isElement).toBe(true);
  });

  it('assigned new element', () => {
    node = parseSimpleSelector(':foo') as PseudoSelector;
    node.isElement = true;
    expect(node.isClass).toBe(false);
    expect(node.isElement).toBe(true);
  });

  it('assigned new argument', () => {
    node = parseSimpleSelector(':foo(bar)') as PseudoSelector;
    node.argument = 'baz';
    expect(node).toHaveInterpolation('argument', 'baz');
  });

  it('assigned new selector', () => {
    node = parseSimpleSelector(':is(.bar)') as PseudoSelector;
    node.selector = {id: 'baz'};
    expect(node.selector!.parent).toBe(node);
    expect(node.selector!.toString()).toEqual('#baz');
  });

  describe('stringifies', () => {
    describe('without an argument or selector', () => {
      it('with no raws', () =>
        expect(new PseudoSelector({pseudo: 'foo'}).toString()).toBe(':foo'));

      it('ignores all raws', () =>
        expect(
          new PseudoSelector({
            pseudo: 'foo',
            raws: {afterOpen: '  ', beforeClose: '  ', afterArgument: '  '},
          }).toString(),
        ).toBe(':foo'));
    });

    it('a pseudo-element', () =>
      expect(parseSimpleSelector('::foo').toString()).toBe('::foo'));

    it('a fake pseudo-element', () =>
      expect(parseSimpleSelector(':after').toString()).toBe(':after'));

    describe('with an argument and no selector', () => {
      it('with no raws', () =>
        expect(
          new PseudoSelector({pseudo: 'foo', argument: '&#^*'}).toString(),
        ).toBe(':foo(&#^*)'));

      it('with afterOpen', () =>
        expect(
          new PseudoSelector({
            pseudo: 'foo',
            argument: '&#^*',
            raws: {afterOpen: '  '},
          }).toString(),
        ).toBe(':foo(  &#^*)'));

      it('with beforeClose', () =>
        expect(
          new PseudoSelector({
            pseudo: 'foo',
            argument: '&#^*',
            raws: {beforeClose: '  '},
          }).toString(),
        ).toBe(':foo(&#^*  )'));

      it('with afterArgument', () =>
        expect(
          new PseudoSelector({
            pseudo: 'foo',
            argument: '&#^*',
            raws: {afterArgument: '  '},
          }).toString(),
        ).toBe(':foo(&#^*  )'));

      it('with afterArgument and beforeClose', () =>
        expect(
          new PseudoSelector({
            pseudo: 'foo',
            argument: '&#^*',
            raws: {afterArgument: '  ', beforeClose: '/**/'},
          }).toString(),
        ).toBe(':foo(&#^*  /**/)'));
    });

    describe('with a selector and no argument', () => {
      it('with no raws', () =>
        expect(
          new PseudoSelector({
            pseudo: 'is',
            selector: {class: 'foo'},
          }).toString(),
        ).toBe(':is(.foo)'));

      it('with afterOpen', () =>
        expect(
          new PseudoSelector({
            pseudo: 'is',
            selector: {class: 'foo'},
            raws: {afterOpen: '  '},
          }).toString(),
        ).toBe(':is(  .foo)'));

      it('with beforeClose', () =>
        expect(
          new PseudoSelector({
            pseudo: 'is',
            selector: {class: 'foo'},
            raws: {beforeClose: '  '},
          }).toString(),
        ).toBe(':is(.foo  )'));

      it('ignores afterArgument', () =>
        expect(
          new PseudoSelector({
            pseudo: 'is',
            selector: {class: 'foo'},
            raws: {afterArgument: '  '},
          }).toString(),
        ).toBe(':is(.foo)'));
    });

    describe('with an argument and a selector', () => {
      it('with no raws', () =>
        expect(
          new PseudoSelector({
            pseudo: 'nth-child',
            argument: '2n of',
            selector: {class: 'foo'},
          }).toString(),
        ).toBe(':nth-child(2n of .foo)'));

      it('with afterOpen', () =>
        expect(
          new PseudoSelector({
            pseudo: 'nth-child',
            argument: '2n of',
            selector: {class: 'foo'},
            raws: {afterOpen: '  '},
          }).toString(),
        ).toBe(':nth-child(  2n of .foo)'));

      it('with beforeClose', () =>
        expect(
          new PseudoSelector({
            pseudo: 'nth-child',
            argument: '2n of',
            selector: {class: 'foo'},
            raws: {beforeClose: '  '},
          }).toString(),
        ).toBe(':nth-child(2n of .foo  )'));

      it('with afterArgument', () =>
        expect(
          new PseudoSelector({
            pseudo: 'nth-child',
            argument: '2n of',
            selector: {class: 'foo'},
            raws: {afterArgument: '  '},
          }).toString(),
        ).toBe(':nth-child(2n of  .foo)'));
    });
  });

  describe('clone', () => {
    let original: PseudoSelector;

    beforeEach(() => {
      original = parseSimpleSelector(':nth-child(2n of .foo)');
    });

    describe('with no overrides', () => {
      let clone: PseudoSelector;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('pseudo', () =>
          expect(clone).toHaveInterpolation('pseudo', 'nth-child'));

        it('argument', () =>
          expect(clone).toHaveInterpolation('argument', '2n of'));

        it('selector', () => {
          expect(clone.selector!.toString()).toEqual('.foo');
          expect(clone.selector!.parent).toBe(clone);
        });

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of [
          'pseudo',
          'argument',
          'selector',
          'raws',
        ] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('pseudo', () => {
        it('defined', () =>
          expect(original.clone({pseudo: 'bar'})).toHaveInterpolation(
            'pseudo',
            'bar',
          ));

        it('undefined', () =>
          expect(original.clone({pseudo: undefined})).toHaveInterpolation(
            'pseudo',
            'nth-child',
          ));
      });

      describe('class', () => {
        it('defined', () =>
          expect(original.clone({isClass: false}).isClass).toBe(false));

        it('undefined', () =>
          expect(original.clone({isClass: undefined}).isClass).toBe(true));
      });

      describe('element', () => {
        it('defined', () =>
          expect(original.clone({isElement: true}).isElement).toBe(true));

        it('undefined', () =>
          expect(original.clone({isElement: undefined}).isElement).toBe(false));
      });

      describe('argument', () => {
        it('defined', () =>
          expect(original.clone({argument: 'n + 1 of'})).toHaveInterpolation(
            'argument',
            'n + 1 of',
          ));

        it('undefined', () =>
          expect(
            original.clone({argument: undefined}).argument,
          ).toBeUndefined());
      });

      describe('selector', () => {
        it('defined', () => {
          const clone = original.clone({selector: {id: 'bar'}});
          expect(clone.selector!.toString()).toBe('#bar');
          expect(clone.selector!.parent).toBe(clone);
        });

        it('undefined', () =>
          expect(
            original.clone({selector: undefined}).selector,
          ).toBeUndefined());
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {}}).raws).toEqual({}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({}));
      });
    });
  });

  describe('toJSON', () => {
    it('with no argument or selector', () =>
      expect(parseSimpleSelector(':foo')).toMatchSnapshot());

    it('a pseudo-element', () =>
      expect(parseSimpleSelector('::foo')).toMatchSnapshot());

    it('a fake pseudo-element', () =>
      expect(parseSimpleSelector(':after')).toMatchSnapshot());

    it('with an argument and no selector', () =>
      expect(parseSimpleSelector(':foo(&^*#)')).toMatchSnapshot());

    it('with a selector and no argument', () =>
      expect(parseSimpleSelector(':is(.foo)')).toMatchSnapshot());

    it('with an argument and a selector', () =>
      expect(parseSimpleSelector(':nth-child(2n of .foo)')).toMatchSnapshot());
  });
});
