// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as sass from 'sass';
import * as postcss from 'postcss';

import type * as binaryOperation from './expression/binary-operation';

// Type definitions for internal Sass APIs we're wrapping. We cast the Sass
// module to this type to access them.

export type Syntax = 'scss' | 'sass' | 'css';

export interface FileSpan extends sass.SourceSpan {
  readonly file: SourceFile;
}

export interface SourceFile {
  /** Node-only extension that we use to avoid re-creating inputs. */
  _postcssInput?: postcss.Input;

  getText(start: number, end?: number): string;
}

// There may be a better way to declare this, but I can't figure it out.
// eslint-disable-next-line @typescript-eslint/no-namespace
declare namespace SassInternal {
  function parse(
    css: string,
    syntax: Syntax,
    path?: string,
    logger?: sass.Logger
  ): Stylesheet;

  class StatementVisitor<T> {
    private _fakePropertyToMakeThisAUniqueType1: T;
  }

  function createStatementVisitor<T>(
    inner: StatementVisitorObject<T>
  ): StatementVisitor<T>;

  class ExpressionVisitor<T> {
    private _fakePropertyToMakeThisAUniqueType2: T;
  }

  function createExpressionVisitor<T>(
    inner: ExpressionVisitorObject<T>
  ): ExpressionVisitor<T>;

  class SassNode {
    readonly span: FileSpan;
  }

  class Interpolation extends SassNode {
    contents: (string | Expression)[];
    get asPlain(): string | undefined;
  }

  class Statement extends SassNode {
    accept<T>(visitor: StatementVisitor<T>): T;
  }

  class ParentStatement<T extends Statement[] | null> extends Statement {
    readonly children: T;
  }

  class AtRootRule extends ParentStatement<Statement[]> {
    readonly name: Interpolation;
    readonly query?: Interpolation;
  }

  class AtRule extends ParentStatement<Statement[]> {
    readonly name: Interpolation;
    readonly value?: Interpolation;
  }

  class DebugRule extends Statement {
    readonly expression: Expression;
  }

  class EachRule extends ParentStatement<Statement[]> {
    readonly variables: string[];
    readonly list: Expression;
  }

  class ErrorRule extends Statement {
    readonly expression: Expression;
  }

  class ExtendRule extends Statement {
    readonly selector: Interpolation;
    readonly isOptional: boolean;
  }

  class ForRule extends ParentStatement<Statement[]> {
    readonly variable: string;
    readonly from: Expression;
    readonly to: Expression;
    readonly isExclusive: boolean;
  }

  class LoudComment extends Statement {
    readonly text: Interpolation;
  }

  class Stylesheet extends ParentStatement<Statement[]> {}

  class StyleRule extends ParentStatement<Statement[]> {
    readonly selector: Interpolation;
  }

  class Expression extends SassNode {
    accept<T>(visitor: ExpressionVisitor<T>): T;
  }

  class BinaryOperator {
    readonly operator: binaryOperation.BinaryOperator;
  }

  class BinaryOperationExpression extends Expression {
    readonly operator: BinaryOperator;
    readonly left: Expression;
    readonly right: Expression;
    readonly hasQuotes: boolean;
  }

  class StringExpression extends Expression {
    readonly text: Interpolation;
    readonly hasQuotes: boolean;
  }
}

const sassInternal = (
  sass as unknown as {loadParserExports_(): typeof SassInternal}
).loadParserExports_();

export type SassNode = SassInternal.SassNode;
export type Statement = SassInternal.Statement;
export type ParentStatement<T extends Statement[] | null> =
  SassInternal.ParentStatement<T>;
export type AtRootRule = SassInternal.AtRootRule;
export type AtRule = SassInternal.AtRule;
export type DebugRule = SassInternal.DebugRule;
export type EachRule = SassInternal.EachRule;
export type ErrorRule = SassInternal.ErrorRule;
export type ExtendRule = SassInternal.ExtendRule;
export type ForRule = SassInternal.ForRule;
export type LoudComment = SassInternal.LoudComment;
export type Stylesheet = SassInternal.Stylesheet;
export type StyleRule = SassInternal.StyleRule;
export type Interpolation = SassInternal.Interpolation;
export type Expression = SassInternal.Expression;
export type BinaryOperationExpression = SassInternal.BinaryOperationExpression;
export type StringExpression = SassInternal.StringExpression;

export interface StatementVisitorObject<T> {
  visitAtRootRule(node: AtRootRule): T;
  visitAtRule(node: AtRule): T;
  visitDebugRule(node: DebugRule): T;
  visitEachRule(node: EachRule): T;
  visitErrorRule(node: ErrorRule): T;
  visitExtendRule(node: ExtendRule): T;
  visitForRule(node: ForRule): T;
  visitLoudComment(node: LoudComment): T;
  visitStyleRule(node: StyleRule): T;
}

export interface ExpressionVisitorObject<T> {
  visitBinaryOperationExpression(node: BinaryOperationExpression): T;
  visitStringExpression(node: StringExpression): T;
}

export const parse = sassInternal.parse;
export const createStatementVisitor = sassInternal.createStatementVisitor;
export const createExpressionVisitor = sassInternal.createExpressionVisitor;
