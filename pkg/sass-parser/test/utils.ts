// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {
  ChildNode,
  ChildProps,
  Expression,
  ExpressionProps,
  GenericAtRule,
  Interpolation,
  Root,
  scss,
} from '../lib';

/** Parses a Sass expression from {@link text}. */
export function parseExpression<T extends Expression>(text: string): T {
  const interpolation = (scss.parse(`@#{${text}}`).nodes[0] as GenericAtRule)
    .nameInterpolation;
  const expression = interpolation.nodes[0] as T;
  interpolation.removeChild(expression);
  return expression;
}

/** Constructs a new node from {@link props} as in child node injection. */
export function fromChildProps<T extends ChildNode>(props: ChildProps): T {
  return new Root({nodes: [props]}).nodes[0] as T;
}

/** Constructs a new expression from {@link props}. */
export function fromExpressionProps<T extends Expression>(
  props: ExpressionProps
): T {
  return new Interpolation({nodes: [props]}).nodes[0] as T;
}
