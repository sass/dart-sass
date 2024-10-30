// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {GenericAtRule, Rule, scss} from '../..';

describe('an @at-root rule', () => {
  let node: GenericAtRule;

  describe('with no params', () => {
    beforeEach(
      () => void (node = scss.parse('@at-root {}').nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('at-root'));

    it('has no paramsInterpolation', () =>
      expect(node.paramsInterpolation).toBeUndefined());

    it('has no params', () => expect(node.params).toBe(''));
  });

  describe('with no interpolation', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@at-root (with: rule) {}')
          .nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('at-root'));

    it('has a paramsInterpolation', () =>
      expect(node).toHaveInterpolation('paramsInterpolation', '(with: rule)'));

    it('has matching params', () => expect(node.params).toBe('(with: rule)'));
  });

  // TODO: test a variable used directly without interpolation

  describe('with interpolation', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@at-root (with: #{rule}) {}')
          .nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('at-root'));

    it('has a paramsInterpolation', () => {
      const params = node.paramsInterpolation!;
      expect(params.nodes[0]).toBe('(with: ');
      expect(params).toHaveStringExpression(1, 'rule');
      expect(params.nodes[2]).toBe(')');
    });

    it('has matching params', () =>
      expect(node.params).toBe('(with: #{rule})'));
  });

  describe('with style rule shorthand', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@at-root .foo {}').nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('at-root'));

    it('has no paramsInterpolation', () =>
      expect(node.paramsInterpolation).toBeUndefined());

    it('has no params', () => expect(node.params).toBe(''));

    it('contains a Rule', () => {
      const rule = node.nodes[0] as Rule;
      expect(rule).toHaveInterpolation('selectorInterpolation', '.foo ');
      expect(rule.parent).toBe(node);
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with atRootShorthand: false', () =>
        expect(
          new GenericAtRule({
            name: 'at-root',
            nodes: [{selector: '.foo'}],
            raws: {atRootShorthand: false},
          }).toString()
        ).toBe('@at-root {\n    .foo {}\n}'));

      describe('with atRootShorthand: true', () => {
        it('with no params and only a style rule child', () =>
          expect(
            new GenericAtRule({
              name: 'at-root',
              nodes: [{selector: '.foo'}],
              raws: {atRootShorthand: true},
            }).toString()
          ).toBe('@at-root .foo {}'));

        it('with no params and multiple children', () =>
          expect(
            new GenericAtRule({
              name: 'at-root',
              nodes: [{selector: '.foo'}, {selector: '.bar'}],
              raws: {atRootShorthand: true},
            }).toString()
          ).toBe('@at-root {\n    .foo {}\n    .bar {}\n}'));

        it('with no params and a non-style-rule child', () =>
          expect(
            new GenericAtRule({
              name: 'at-root',
              nodes: [{name: 'foo'}],
              raws: {atRootShorthand: true},
            }).toString()
          ).toBe('@at-root {\n    @foo\n}'));

        it('with params and only a style rule child', () =>
          expect(
            new GenericAtRule({
              name: 'at-root',
              params: '(with: rule)',
              nodes: [{selector: '.foo'}],
              raws: {atRootShorthand: true},
            }).toString()
          ).toBe('@at-root (with: rule) {\n    .foo {}\n}'));

        it("that's not @at-root", () =>
          expect(
            new GenericAtRule({
              name: 'at-wrong',
              nodes: [{selector: '.foo'}],
              raws: {atRootShorthand: true},
            }).toString()
          ).toBe('@at-wrong {\n    .foo {}\n}'));
      });
    });
  });
});
