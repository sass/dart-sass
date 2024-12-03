// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Root} from './src/statement/root';
import * as sassInternal from './src/sass-internal';
import {Stringifier} from './src/stringifier';

export {
  Configuration,
  ConfigurationProps,
  ConfigurationRaws,
} from './src/configuration';
export {
  ConfiguredVariable,
  ConfiguredVariableObjectProps,
  ConfiguredVariableExpressionProps,
  ConfiguredVariableProps,
  ConfiguredVariableRaws,
} from './src/configured-variable';
export {Container} from './src/container';
export {AnyNode, Node, NodeProps, NodeType} from './src/node';
export {RawWithValue} from './src/raw-with-value';
export {
  AnyExpression,
  Expression,
  ExpressionProps,
  ExpressionType,
} from './src/expression';
export {
  BinaryOperationExpression,
  BinaryOperationExpressionProps,
  BinaryOperationExpressionRaws,
  BinaryOperator,
} from './src/expression/binary-operation';
export {
  StringExpression,
  StringExpressionProps,
  StringExpressionRaws,
} from './src/expression/string';
export {
  BooleanExpression,
  BooleanExpressionProps,
  BooleanExpressionRaws,
} from './src/expression/boolean';
export {
  NumberExpression,
  NumberExpressionProps,
  NumberExpressionRaws,
} from './src/expression/number';
export {
  Interpolation,
  InterpolationProps,
  InterpolationRaws,
  NewNodeForInterpolation,
} from './src/interpolation';
export {
  NewParameters,
  ParameterListObjectProps,
  ParameterListProps,
  ParameterListRaws,
  ParameterList,
} from './src/parameter-list';
export {
  ParameterObjectProps,
  ParameterRaws,
  ParameterExpressionProps,
  ParameterProps,
  Parameter,
} from './src/parameter';
export {
  CssComment,
  CssCommentProps,
  CssCommentRaws,
} from './src/statement/css-comment';
export {
  DebugRule,
  DebugRuleProps,
  DebugRuleRaws,
} from './src/statement/debug-rule';
export {EachRule, EachRuleProps, EachRuleRaws} from './src/statement/each-rule';
export {
  ErrorRule,
  ErrorRuleProps,
  ErrorRuleRaws,
} from './src/statement/error-rule';
export {ForRule, ForRuleProps, ForRuleRaws} from './src/statement/for-rule';
export {
  ForwardMemberList,
  ForwardMemberProps,
  ForwardRule,
  ForwardRuleProps,
  ForwardRuleRaws,
} from './src/statement/forward-rule';
export {
  FunctionRuleRaws,
  FunctionRuleProps,
  FunctionRule,
} from './src/statement/function-rule';
export {
  GenericAtRule,
  GenericAtRuleProps,
  GenericAtRuleRaws,
} from './src/statement/generic-at-rule';
export {Root, RootProps, RootRaws} from './src/statement/root';
export {Rule, RuleProps, RuleRaws} from './src/statement/rule';
export {
  SassComment,
  SassCommentProps,
  SassCommentRaws,
} from './src/statement/sass-comment';
export {UseRule, UseRuleProps, UseRuleRaws} from './src/statement/use-rule';
export {
  AnyStatement,
  AtRule,
  ChildNode,
  ChildProps,
  ContainerProps,
  NewNode,
  Statement,
  StatementType,
  StatementWithChildren,
} from './src/statement';
export {
  VariableDeclaration,
  VariableDeclarationProps,
  VariableDeclarationRaws,
} from './src/statement/variable-declaration';
export {WarnRule, WarnRuleProps, WarnRuleRaws} from './src/statement/warn-rule';
export {
  WhileRule,
  WhileRuleProps,
  WhileRuleRaws,
} from './src/statement/while-rule';

/** Options that can be passed to the Sass parsers to control their behavior. */
export type SassParserOptions = Pick<postcss.ProcessOptions, 'from' | 'map'>;

/** A PostCSS syntax for parsing a particular Sass syntax. */
export interface Syntax extends postcss.Syntax<postcss.Root> {
  parse(css: {toString(): string} | string, opts?: SassParserOptions): Root;
  stringify: postcss.Stringifier;
}

/** The internal implementation of the syntax. */
class _Syntax implements Syntax {
  /** The syntax with which to parse stylesheets. */
  readonly #syntax: sassInternal.Syntax;

  constructor(syntax: sassInternal.Syntax) {
    this.#syntax = syntax;
  }

  parse(css: {toString(): string} | string, opts?: SassParserOptions): Root {
    if (opts?.map) {
      // We might be able to support this as a layer on top of source spans, but
      // is it worth the effort?
      throw "sass-parser doesn't currently support consuming source maps.";
    }

    return new Root(
      undefined,
      sassInternal.parse(css.toString(), this.#syntax, opts?.from),
    );
  }

  stringify(node: postcss.AnyNode, builder: postcss.Builder): void {
    new Stringifier(builder).stringify(node, true);
  }
}

/** A PostCSS syntax for parsing SCSS. */
export const scss: Syntax = new _Syntax('scss');

/** A PostCSS syntax for parsing Sass's indented syntax. */
export const sass: Syntax = new _Syntax('sass');

/** A PostCSS syntax for parsing plain CSS. */
export const css: Syntax = new _Syntax('css');
