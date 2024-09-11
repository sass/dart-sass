// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {GenericAtRule, StringExpression, scss} from '../..';

describe('a @media rule', () => {
  let node: GenericAtRule;

  describe('with no interpolation', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@media screen {}').nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('media'));

    it('has a paramsInterpolation', () =>
      expect(node).toHaveInterpolation('paramsInterpolation', 'screen'));

    it('has matching params', () => expect(node.params).toBe('screen'));
  });

  // TODO: test a variable used directly without interpolation

  describe('with interpolation', () => {
    beforeEach(
      () =>
        void (node = scss.parse('@media (hover: #{hover}) {}')
          .nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('media'));

    it('has a paramsInterpolation', () => {
      const params = node.paramsInterpolation!;
      expect(params.nodes[0]).toBe('(');
      expect(params).toHaveStringExpression(1, 'hover');
      expect(params.nodes[2]).toBe(': ');
      expect(params.nodes[3]).toBeInstanceOf(StringExpression);
      expect((params.nodes[3] as StringExpression).text).toHaveStringExpression(
        0,
        'hover'
      );
      expect(params.nodes[4]).toBe(')');
    });

    it('has matching params', () =>
      expect(node.params).toBe('(hover: #{hover})'));
  });

  describe('stringifies', () => {
    // TODO: Use raws technology to include the actual original text between
    // interpolations.
    it('to SCSS', () =>
      expect(
        (node = scss.parse('@media #{screen} and (hover: #{hover}) {@foo}')
          .nodes[0] as GenericAtRule).toString()
      ).toBe('@media #{screen}  and (hover: #{hover}) {\n    @foo\n}'));
  });
});
