// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  AnyExpression,
  AnyIfConditionExpression,
  AnySimpleSelector,
  ChildNode,
  ChildProps,
  CompoundSelector,
  ExpressionProps,
  GenericAtRule,
  IfConditionExpressionProps,
  IfConditionParenthesized,
  IfExpression,
  Interpolation,
  Root,
  Rule,
  SelectorList,
  SimpleSelectorProps,
  scss,
} from '../lib';

/** Parses a Sass expression from {@link text}. */
export function parseExpression<T extends AnyExpression>(text: string): T {
  const interpolation = (scss.parse(`@#{${text}}`).nodes[0] as GenericAtRule)
    .nameInterpolation;
  const expression = interpolation.nodes[0] as T;
  interpolation.removeChild(expression);
  return expression;
}

/** Parses an `if()` condition expression from {@link text}. */
export function parseIfConditionExpression<T extends AnyIfConditionExpression>(
  text: string,
): T {
  const ifEntry = (parseExpression(`if(${text}: a)`) as IfExpression).nodes[0];
  expect(ifEntry.sassType).toEqual('if-entry');
  return ifEntry.condition! as T;
}

/** Parses selector list from {@link text}. */
export function parseSelector(text: string): SelectorList {
  const rule = scss.parse(`${text} {}`).nodes[0] as Rule;
  expect(rule.type).toEqual('rule');
  return rule.parsedSelector;
}

/** Parses simple selector from {@link text}. */
export function parseSimpleSelector<T extends AnySimpleSelector>(
  text: string,
): T {
  const rule = scss.parse(`${text} {}`).nodes[0] as Rule;
  expect(rule.type).toEqual('rule');
  expect(rule.parsedSelector.nodes).toHaveLength(1);
  const complex = rule.parsedSelector.nodes[0];
  expect(complex.nodes).toHaveLength(1);
  const component = complex.nodes[0];
  expect(component.combinator).toBeUndefined();
  expect(component.compound.nodes).toHaveLength(1);
  return component.compound.nodes[0] as T;
}

/** Constructs a new node from {@link props} as in child node injection. */
export function fromChildProps<T extends ChildNode>(props: ChildProps): T {
  return new Root({nodes: [props]}).nodes[0] as T;
}

/** Constructs a new expression from {@link props}. */
export function fromExpressionProps<T extends AnyExpression>(
  props: ExpressionProps,
): T {
  return new Interpolation({nodes: [props]}).nodes[0] as T;
}

/** Constructs a new `if()` conditoin expression from {@link props}. */
export function fromIfConditionExpressionProps<
  T extends AnyIfConditionExpression,
>(props: IfConditionExpressionProps): T {
  return new IfConditionParenthesized({parenthesized: props})
    .parenthesized as T;
}

/** Constructs a new simple selector from {@link props}. */
export function fromSimpleSelectorProps<T extends AnySimpleSelector>(
  props: SimpleSelectorProps,
): T {
  return new CompoundSelector({nodes: [props]}).nodes[0] as T;
}
