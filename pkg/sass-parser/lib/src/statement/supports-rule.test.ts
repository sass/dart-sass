// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {GenericAtRule, scss} from '../..';

describe('a @supports rule', () => {
  let node: GenericAtRule;

  describe('SupportsAnything', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@supports ( foo $&#{bar} baz) {}')
          .nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('supports'));

    it('has a paramsInterpolation', () => {
      const params = node.paramsInterpolation!;
      expect(params.nodes[0]).toBe('( foo $&');
      expect(params).toHaveStringExpression(1, 'bar');
      expect(params.nodes[2]).toBe(' baz)');
    });

    it('has matching params', () =>
      expect(node.params).toBe('( foo $&#{bar} baz)'));

    it('stringifies to SCSS', () =>
      expect(node.toString()).toBe('@supports ( foo $&#{bar} baz) {}'));
  });

  describe('SupportsDeclaration', () => {
    describe('with plain CSS on both sides', () => {
      beforeEach(
        () =>
          void (node = scss.parse('@supports ( foo : bar, #abc, []) {}')
            .nodes[0] as GenericAtRule)
      );

      it('has a name', () => expect(node.name).toBe('supports'));

      it('has a paramsInterpolation', () =>
        expect(node).toHaveInterpolation(
          'paramsInterpolation',
          '( foo : bar, #abc, [])'
        ));

      it('has matching params', () =>
        expect(node.params).toBe('( foo : bar, #abc, [])'));

      it('stringifies to SCSS', () =>
        expect(node.toString()).toBe('@supports ( foo : bar, #abc, []) {}'));
    });

    // Can't test this until variable expressions are supported
    describe.skip('with raw SassScript on both sides', () => {
      beforeEach(
        () =>
          void (node = scss.parse('@supports ($foo: $bar) {}')
            .nodes[0] as GenericAtRule)
      );

      it('has a name', () => expect(node.name).toBe('supports'));

      it('has a paramsInterpolation', () =>
        expect(node).toHaveInterpolation(
          'paramsInterpolation',
          '(#{$foo}: #{$bar})'
        ));

      it('has matching params', () => expect(node.params).toBe('($foo: $bar)'));

      it('stringifies to SCSS', () =>
        expect(node.toString()).toBe('@supports ($foo: $bar) {}'));
    });

    describe('with explicit interpolation on both sides', () => {
      beforeEach(
        () =>
          void (node = scss.parse('@supports (#{"foo"}: #{"bar"}) {}')
            .nodes[0] as GenericAtRule)
      );

      it('has a name', () => expect(node.name).toBe('supports'));

      it('has a paramsInterpolation', () =>
        expect(node).toHaveInterpolation(
          'paramsInterpolation',
          '(#{"foo"}: #{"bar"})'
        ));

      it('has matching params', () =>
        expect(node.params).toBe('(#{"foo"}: #{"bar"})'));

      it('stringifies to SCSS', () =>
        expect(node.toString()).toBe('@supports (#{"foo"}: #{"bar"}) {}'));
    });
  });

  describe('SupportsFunction', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@supports foo#{"bar"}(baz &*^ #{"bang"}) {}')
          .nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('supports'));

    it('has a paramsInterpolation', () =>
      expect(node).toHaveInterpolation(
        'paramsInterpolation',
        'foo#{"bar"}(baz &*^ #{"bang"})'
      ));

    it('has matching params', () =>
      expect(node.params).toBe('foo#{"bar"}(baz &*^ #{"bang"})'));

    it('stringifies to SCSS', () =>
      expect(node.toString()).toBe(
        '@supports foo#{"bar"}(baz &*^ #{"bang"}) {}'
      ));
  });

  describe('SupportsInterpolation', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@supports #{"bar"} {}')
          .nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('supports'));

    it('has a paramsInterpolation', () =>
      expect(node).toHaveInterpolation('paramsInterpolation', '#{"bar"}'));

    it('has matching params', () => expect(node.params).toBe('#{"bar"}'));

    it('stringifies to SCSS', () =>
      expect(node.toString()).toBe('@supports #{"bar"} {}'));
  });

  describe('SupportsNegation', () => {
    describe('with one space', () => {
      beforeEach(
        () =>
          void (node = scss.parse('@supports not #{"bar"} {}')
            .nodes[0] as GenericAtRule)
      );

      it('has a name', () => expect(node.name).toBe('supports'));

      it('has a paramsInterpolation', () =>
        expect(node).toHaveInterpolation(
          'paramsInterpolation',
          'not #{"bar"}'
        ));

      it('has matching params', () => expect(node.params).toBe('not #{"bar"}'));

      it('stringifies to SCSS', () =>
        expect(node.toString()).toBe('@supports not #{"bar"} {}'));
    });

    describe('with a comment', () => {
      beforeEach(
        () =>
          void (node = scss.parse('@supports not/**/#{"bar"} {}')
            .nodes[0] as GenericAtRule)
      );

      it('has a name', () => expect(node.name).toBe('supports'));

      it('has a paramsInterpolation', () =>
        expect(node).toHaveInterpolation(
          'paramsInterpolation',
          'not/**/#{"bar"}'
        ));

      it('has matching params', () =>
        expect(node.params).toBe('not/**/#{"bar"}'));

      it('stringifies to SCSS', () =>
        expect(node.toString()).toBe('@supports not/**/#{"bar"} {}'));
    });
  });

  describe('SupportsOperation', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@supports (#{"foo"} or #{"bar"}) {}')
          .nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('supports'));

    it('has a paramsInterpolation', () =>
      expect(node).toHaveInterpolation(
        'paramsInterpolation',
        '(#{"foo"} or #{"bar"})'
      ));

    it('has matching params', () =>
      expect(node.params).toBe('(#{"foo"} or #{"bar"})'));

    it('stringifies to SCSS', () =>
      expect(node.toString()).toBe('@supports (#{"foo"} or #{"bar"}) {}'));
  });
});
