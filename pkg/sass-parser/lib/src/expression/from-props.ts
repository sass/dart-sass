// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {BinaryOperationExpression} from './binary-operation';
import {Expression, ExpressionProps} from '.';
import {StringExpression} from './string';
import {BooleanExpression} from './boolean';

/** Constructs an expression from {@link ExpressionProps}. */
export function fromProps(props: ExpressionProps): Expression {
  if ('text' in props) return new StringExpression(props);
  if ('left' in props) return new BinaryOperationExpression(props);
  if ('value' in props) return new BooleanExpression(props);
  throw new Error(`Unknown node type: ${props}`);
}
