// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Root} from './src/statement/root';
import * as sassInternal from './src/sass-internal';
import {Stringifier} from './src/stringifier';

export {
  Argument,
  ArgumentExpressionProps,
  ArgumentObjectProps,
  ArgumentProps,
  ArgumentRaws,
} from './src/argument';
export {
  ArgumentList,
  ArgumentListObjectProps,
  ArgumentListProps,
  ArgumentListRaws,
  NewArguments,
} from './src/argument-list';
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
export {
  DynamicImport,
  DynamicImportObjectProps,
  DynamicImportProps,
  DynamicImportRaws,
} from './src/dynamic-import';
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
  ColorExpression,
  ColorExpressionProps,
  ColorExpressionRaws,
} from './src/expression/color';
export {
  FunctionExpression,
  FunctionExpressionProps,
  FunctionExpressionRaws,
} from './src/expression/function';
export {
  InterpolatedFunctionExpression,
  InterpolatedFunctionExpressionProps,
  InterpolatedFunctionExpressionRaws,
} from './src/expression/interpolated-function';
export {
  ListExpression,
  ListExpressionProps,
  ListExpressionRaws,
  ListSeparator,
  NewNodeForListExpression,
} from './src/expression/list';
export {
  MapEntry,
  MapEntryProps,
  MapEntryRaws,
} from './src/expression/map-entry';
export {
  MapExpression,
  MapExpressionProps,
  MapExpressionRaws,
  NewNodeForMapExpression,
} from './src/expression/map';
export {
  NullExpression,
  NullExpressionProps,
  NullExpressionRaws,
} from './src/expression/null';
export {
  NumberExpression,
  NumberExpressionProps,
  NumberExpressionRaws,
} from './src/expression/number';
export {
  ParenthesizedExpression,
  ParenthesizedExpressionProps,
  ParenthesizedExpressionRaws,
} from './src/expression/parenthesized';
export {
  ImportList,
  ImportListObjectProps,
  ImportListProps,
  ImportListRaws,
  NewImport,
} from './src/import-list';
export {
  ImportRule,
  ImportRuleProps,
  ImportRuleRaws,
} from './src/statement/import-rule';
export {
  IncludeRule,
  IncludeRuleProps,
  IncludeRuleRaws,
} from './src/statement/include-rule';
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
  AnySimpleSelector,
  SimpleSelectorType,
  SimpleSelectorProps,
  SimpleSelector,
} from './src/selector';
export {
  AttributeSelectorOperator,
  AttributeSelectorProps,
  AttributeSelectorRaws,
  AttributeSelector,
} from './src/selector/attribute';
export {
  ClassSelectorProps,
  ClassSelectorRaws,
  ClassSelector,
} from './src/selector/class';
export {
  ComplexSelectorComponentObjectProps,
  ComplexSelectorComponentProps,
  ComplexSelectorComponentRaws,
  ComplexSelectorComponent,
} from './src/selector/complex-component';
export {
  ComplexSelectorObjectProps,
  ComplexSelectorProps,
  NewNodeForComplexSelector,
  ComplexSelectorRaws,
  ComplexSelector,
  SelectorCombinator,
} from './src/selector/complex';
export {
  CompoundSelectorObjectProps,
  CompoundSelectorProps,
  NewNodeForCompoundSelector,
  CompoundSelectorRaws,
  CompoundSelector,
} from './src/selector/compound';
export {IDSelectorProps, IDSelectorRaws, IDSelector} from './src/selector/id';
export {
  SelectorListObjectProps,
  SelectorListProps,
  NewNodeForSelectorList,
  SelectorListRaws,
  SelectorList,
} from './src/selector/list';
export {
  ParentSelectorProps,
  ParentSelectorRaws,
  ParentSelector,
} from './src/selector/parent';
export {
  PlaceholderSelectorProps,
  PlaceholderSelectorRaws,
  PlaceholderSelector,
} from './src/selector/placeholder';
export {
  PseudoSelectorProps,
  PseudoSelectorRaws,
  PseudoSelector,
} from './src/selector/pseudo';
export {
  QualifiedNameObjectProps,
  QualifiedNameProps,
  QualifiedNameRaws,
  QualifiedName,
} from './src/selector/qualified-name';
export {
  TypeSelectorProps,
  TypeSelectorRaws,
  TypeSelector,
} from './src/selector/type';
export {
  UniversalSelectorProps,
  UniversalSelectorRaws,
  UniversalSelector,
} from './src/selector/universal';
export {
  ContentRule,
  ContentRuleProps,
  ContentRuleRaws,
} from './src/statement/content-rule';
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
export {
  Declaration,
  DeclarationProps,
  DeclarationRaws,
} from './src/statement/declaration';
export {EachRule, EachRuleProps, EachRuleRaws} from './src/statement/each-rule';
export {ElseRule, ElseRuleProps, ElseRuleRaws} from './src/statement/else-rule';
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
export {IfRule, IfRuleProps, IfRuleRaws} from './src/statement/if-rule';
export {
  MixinRule,
  MixinRuleProps,
  MixinRuleRaws,
} from './src/statement/mixin-rule';
export {
  ReturnRule,
  ReturnRuleProps,
  ReturnRuleRaws,
} from './src/statement/return-rule';
export {Root, RootProps, RootRaws} from './src/statement/root';
export {Rule, RuleProps, RuleRaws} from './src/statement/rule';
export {
  SassComment,
  SassCommentProps,
  SassCommentRaws,
} from './src/statement/sass-comment';
export {UseRule, UseRuleProps, UseRuleRaws} from './src/statement/use-rule';
export {
  AnyDeclaration,
  AnyStatement,
  AtRule,
  ChildNode,
  ChildProps,
  Comment,
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
export {
  SelectorExpression,
  SelectorExpressionProps,
  SelectorExpressionRaws,
} from './src/expression/selector';
export {
  StaticImport,
  StaticImportProps,
  StaticImportRaws,
} from './src/static-import';
export {
  UnaryOperationExpression,
  UnaryOperationExpressionProps,
  UnaryOperationExpressionRaws,
} from './src/expression/unary-operation';
export {
  VariableExpression,
  VariableExpressionProps,
  VariableExpressionRaws,
} from './src/expression/variable';

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
    new Stringifier(builder).stringify(node, false);
  }
}

/** A PostCSS syntax for parsing SCSS. */
export const scss: Syntax = new _Syntax('scss');

/** A PostCSS syntax for parsing Sass's indented syntax. */
export const sass: Syntax = new _Syntax('sass');

/** A PostCSS syntax for parsing plain CSS. */
export const css: Syntax = new _Syntax('css');
