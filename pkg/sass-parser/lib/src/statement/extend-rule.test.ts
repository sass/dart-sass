// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {GenericAtRule, Rule, scss} from '../..';

describe('an @extend rule', () => {
  let node: GenericAtRule;

  describe('with no interpolation', () => {
    beforeEach(
      () =>
        void (node = (scss.parse('.foo {@extend .bar}').nodes[0] as Rule)
          .nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('extend'));

    it('has a paramsInterpolation', () =>
      expect(node).toHaveInterpolation('paramsInterpolation', '.bar'));

    it('has matching params', () => expect(node.params).toBe('.bar'));
  });

  describe('with interpolation', () => {
    beforeEach(
      () =>
        void (node = (scss.parse('.foo {@extend .#{bar}}').nodes[0] as Rule)
          .nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('extend'));

    it('has a paramsInterpolation', () => {
      const params = node.paramsInterpolation!;
      expect(params.nodes[0]).toBe('.');
      expect(params).toHaveStringExpression(1, 'bar');
    });

    it('has matching params', () => expect(node.params).toBe('.#{bar}'));
  });

  describe('with !optional', () => {
    beforeEach(
      () =>
        void (node = (
          scss.parse('.foo {@extend .bar !optional}').nodes[0] as Rule
        ).nodes[0] as GenericAtRule)
    );

    it('has a name', () => expect(node.name).toBe('extend'));

    it('has a paramsInterpolation', () =>
      expect(node).toHaveInterpolation(
        'paramsInterpolation',
        '.bar !optional'
      ));

    it('has matching params', () => expect(node.params).toBe('.bar !optional'));
  });
});
