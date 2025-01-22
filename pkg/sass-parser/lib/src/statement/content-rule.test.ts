// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {ArgumentList, ContentRule, MixinRule, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a @content rule', () => {
  let node: ContentRule;
  describe('without arguments', () => {
    function describeNode(
      description: string,
      create: () => ContentRule,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () => expect(node.sassType).toBe('content-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('content'));

        it('has no arguments', () =>
          expect(node.contentArguments.nodes).toHaveLength(0));

        it('has matching params', () => expect(node.params).toBe(''));

        it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
      });
    }

    describe('parsed as SCSS', () => {
      describeNode(
        'without parens',
        () =>
          (scss.parse('@mixin foo {@content}').nodes[0] as MixinRule)
            .nodes[0] as ContentRule,
      );

      describeNode(
        'with parens',
        () =>
          (scss.parse('@mixin foo {@content()}').nodes[0] as MixinRule)
            .nodes[0] as ContentRule,
      );
    });

    describe('parsed as Sass', () => {
      describeNode(
        'without parens',
        () =>
          (sass.parse('@mixin foo\n  @content').nodes[0] as MixinRule)
            .nodes[0] as ContentRule,
      );

      describeNode(
        'with parens',
        () =>
          (sass.parse('@mixin foo\n  @content()').nodes[0] as MixinRule)
            .nodes[0] as ContentRule,
      );
    });

    describe('constructed manually', () => {
      describeNode(
        'with defined contentArguments',
        () => new ContentRule({contentArguments: []}),
      );

      describeNode(
        'with undefined contentArguments',
        () => new ContentRule({contentArguments: undefined}),
      );

      describeNode('without contentArguments', () => new ContentRule());
    });

    describe('constructed from ChildProps', () => {
      describeNode('with defined contentArguments', () =>
        utils.fromChildProps({contentArguments: []}),
      );

      describeNode('with undefined contentArguments', () =>
        utils.fromChildProps({contentArguments: undefined}),
      );
    });
  });

  describe('with arguments', () => {
    function describeNode(
      description: string,
      create: () => ContentRule,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has a sassType', () => expect(node.sassType).toBe('content-rule'));

        it('has a name', () => expect(node.name.toString()).toBe('content'));

        it('has an argument', () =>
          expect(node.contentArguments.nodes[0]).toHaveStringExpression(
            'value',
            'bar',
          ));

        it('has matching params', () => expect(node.params).toBe('(bar)'));

        it('has undefined nodes', () => expect(node.nodes).toBeUndefined());
      });
    }

    describeNode(
      'parsed as SCSS',
      () =>
        (scss.parse('@mixin foo {@content(bar)}').nodes[0] as MixinRule)
          .nodes[0] as ContentRule,
    );

    describeNode(
      'parsed as Sass',
      () =>
        (sass.parse('@mixin foo\n  @content(bar)').nodes[0] as MixinRule)
          .nodes[0] as ContentRule,
    );

    describeNode(
      'constructed manually',
      () => new ContentRule({contentArguments: [{text: 'bar'}]}),
    );

    describeNode('constructed from ChildProps', () =>
      utils.fromChildProps({contentArguments: [{text: 'bar'}]}),
    );
  });

  describe('throws an error when assigned a new', () => {
    beforeEach(
      () => void (node = new ContentRule({contentArguments: [{text: 'bar'}]})),
    );

    it('name', () => expect(() => (node.name = 'qux')).toThrow());

    it('params', () => expect(() => (node.params = '(zap)')).toThrow());
  });

  describe('assigned new arguments', () => {
    beforeEach(
      () => void (node = new ContentRule({contentArguments: [{text: 'bar'}]})),
    );

    it("removes the old arguments' parent", () => {
      const oldArguments = node.contentArguments;
      node.contentArguments = [{text: 'qux'}];
      expect(oldArguments.parent).toBeUndefined();
    });

    it("assigns the new arguments' parent", () => {
      const args = new ArgumentList([{text: 'qux'}]);
      node.contentArguments = args;
      expect(args.parent).toBe(node);
    });

    it('assigns the arguments explicitly', () => {
      const args = new ArgumentList([{text: 'qux'}]);
      node.contentArguments = args;
      expect(node.contentArguments).toBe(args);
    });

    it('assigns the expression as ArgumentProps', () => {
      node.contentArguments = [{text: 'qux'}];
      expect(node.contentArguments.nodes[0]).toHaveStringExpression(
        'value',
        'qux',
      );
      expect(node.contentArguments.parent).toBe(node);
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      describe('with default raws', () => {
        it('with no arguments', () =>
          expect(new ContentRule().toString()).toBe('@content'));

        it('with an argument', () =>
          expect(
            new ContentRule({contentArguments: [{text: 'bar'}]}).toString(),
          ).toBe('@content(bar)'));
      });

      it('with afterName', () =>
        expect(
          new ContentRule({
            contentArguments: [{text: 'bar'}],
            raws: {afterName: '/**/'},
          }).toString(),
        ).toBe('@content/**/(bar)'));

      it('with showArguments = true', () =>
        expect(new ContentRule({raws: {showArguments: true}}).toString()).toBe(
          '@content()',
        ));

      it('ignores showArguments with an argument', () =>
        expect(
          new ContentRule({
            contentArguments: [{text: 'bar'}],
            raws: {showArguments: false},
          }).toString(),
        ).toBe('@content(bar)'));
    });
  });

  describe('clone', () => {
    let original: ContentRule;
    beforeEach(() => {
      original = (
        scss.parse('@mixin foo {@content(bar)}').nodes[0] as MixinRule
      ).nodes[0] as ContentRule;
      // TODO: remove this once raws are properly parsed
      original.raws.afterName = '  ';
    });

    describe('with no overrides', () => {
      let clone: ContentRule;
      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('params', () => expect(clone.params).toBe('(bar)'));

        it('contentArguments', () => {
          expect(clone.contentArguments.nodes[0]).toHaveStringExpression(
            'value',
            'bar',
          );
          expect(clone.contentArguments.parent).toBe(clone);
        });

        it('raws', () => expect(clone.raws).toEqual({afterName: '  '}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['contentArguments', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {showArguments: true}}).raws).toEqual({
            showArguments: true,
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            afterName: '  ',
          }));
      });

      describe('contentArguments', () => {
        describe('defined', () => {
          let clone: ContentRule;
          beforeEach(() => {
            clone = original.clone({contentArguments: [{text: 'qux'}]});
          });

          it('changes params', () => expect(clone.params).toBe('(qux)'));

          it('changes arguments', () => {
            expect(clone.contentArguments.nodes[0]).toHaveStringExpression(
              'value',
              'qux',
            );
            expect(clone.contentArguments.parent).toBe(clone);
          });
        });

        describe('undefined', () => {
          let clone: ContentRule;
          beforeEach(() => {
            clone = original.clone({contentArguments: undefined});
          });

          it('preserves params', () => expect(clone.params).toBe('(bar)'));

          it('preserves arguments', () =>
            expect(clone.contentArguments.nodes[0]).toHaveStringExpression(
              'value',
              'bar',
            ));
        });
      });
    });
  });

  it('toJSON', () =>
    expect(
      (scss.parse('@mixin foo {@content(bar)}').nodes[0] as MixinRule).nodes[0],
    ).toMatchSnapshot());
});
