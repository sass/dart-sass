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

  readonly codeUnits: number[];

  getText(start: number, end?: number): string;
}

export interface DartSet<T> {
  _type: T;

  // A brand to make this function as a nominal type.
  _unique: 'DartSet';
}

export interface DartMap<K, V> {
  _keyType: K;
  _valueType: V;

  // A brand to make this function as a nominal type.
  _unique: 'DartMap';
}

// There may be a better way to declare this, but I can't figure it out.
// eslint-disable-next-line @typescript-eslint/no-namespace
declare namespace SassInternal {
  function parse(css: string, syntax: Syntax, path?: string): Stylesheet;

  function parseIdentifier(
    identifier: string,
    logger?: sass.Logger,
  ): string | null;

  function toCssIdentifier(text: string): string;

  function setToJS<T>(set: DartSet<T>): Set<T>;

  function mapToRecord<T>(set: DartMap<string, T>): Record<string, T>;

  class StatementVisitor<T> {
    private _fakePropertyToMakeThisAUniqueType1: T;
  }

  function createStatementVisitor<T>(
    inner: StatementVisitorObject<T>,
  ): StatementVisitor<T>;

  class ExpressionVisitor<T> {
    private _fakePropertyToMakeThisAUniqueType2: T;
  }

  function createExpressionVisitor<T>(
    inner: ExpressionVisitorObject<T>,
  ): ExpressionVisitor<T>;

  class SassNode {
    readonly span: FileSpan;
  }

  class ArgumentList extends SassNode {
    readonly positional: Expression[];
    readonly named: DartMap<string, Expression>;
    readonly rest?: Expression;
    readonly keywordRest?: Expression;
  }

  class Interpolation extends SassNode {
    contents: (string | Expression)[];
    get asPlain(): string | undefined;
  }

  class ParameterList extends SassNode {
    readonly parameters: Parameter[];
    readonly restParameter?: string;
  }

  class Parameter extends SassNode {
    readonly name: string;
    readonly defaultValue?: Expression;
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

  class ContentBlock extends ParentStatement<Statement[]> {
    readonly name: string;
    readonly parameters: ParameterList;
  }

  class DebugRule extends Statement {
    readonly expression: Expression;
  }

  class Declaration extends ParentStatement<Statement[] | null> {
    readonly name: Interpolation;
    readonly value?: Expression;
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

  class ForwardRule extends Statement {
    readonly url: Object;
    readonly shownMixinsAndFunctions?: DartSet<string>;
    readonly shownVariables?: DartSet<string>;
    readonly hiddenMixinsAndFunctions?: DartSet<string>;
    readonly hiddenVariables?: DartSet<string>;
    readonly prefix?: string;
    readonly configuration: ConfiguredVariable[];
  }

  class FunctionRule extends ParentStatement<Statement[]> {
    readonly name: string;
    readonly parameters: ParameterList;
  }

  class IfRule extends Statement {
    readonly clauses: IfClause[];
    readonly lastClause: ElseClause | null;
  }

  class IfClause {
    readonly expression: Expression;
    readonly children: Statement[];
  }

  class ElseClause {
    readonly children: Statement[];
  }

  class ImportRule extends Statement {
    readonly imports: (DynamicImport | StaticImport)[];
  }

  class DynamicImport extends SassNode {
    readonly urlString: string;
  }

  class StaticImport extends SassNode {
    readonly url: Interpolation;
    readonly modifiers: Interpolation | null;
  }

  class IncludeRule extends Statement {
    readonly namespace: string | null;
    readonly name: string;
    readonly arguments: ArgumentList;
    readonly content: ContentBlock | null;
  }

  class LoudComment extends Statement {
    readonly text: Interpolation;
  }

  class MediaRule extends ParentStatement<Statement[]> {
    readonly query: Interpolation;
  }

  class MixinRule extends ParentStatement<Statement[]> {
    readonly name: string;
    readonly parameters: ParameterList;
  }

  class ReturnRule extends Statement {
    readonly expression: Expression;
  }

  class SilentComment extends Statement {
    readonly text: string;
  }

  class Stylesheet extends ParentStatement<Statement[]> {}

  class StyleRule extends ParentStatement<Statement[]> {
    readonly selector: Interpolation;
  }

  class SupportsRule extends ParentStatement<Statement[]> {
    readonly condition: SupportsCondition;
  }

  type SupportsCondition =
    | SupportsAnything
    | SupportsDeclaration
    | SupportsInterpolation
    | SupportsNegation
    | SupportsOperation;

  class SupportsAnything extends SassNode {
    readonly contents: Interpolation;

    toInterpolation(): Interpolation;
  }

  class SupportsDeclaration extends SassNode {
    readonly name: Interpolation;
    readonly value: Interpolation;

    toInterpolation(): Interpolation;
  }

  class SupportsFunction extends SassNode {
    readonly name: Interpolation;
    readonly arguments: Interpolation;

    toInterpolation(): Interpolation;
  }

  class SupportsInterpolation extends SassNode {
    readonly expression: Expression;

    toInterpolation(): Interpolation;
  }

  class SupportsNegation extends SassNode {
    readonly condition: SupportsCondition;

    toInterpolation(): Interpolation;
  }

  class SupportsOperation extends SassNode {
    readonly left: SupportsCondition;
    readonly right: SupportsCondition;
    readonly operator: 'and' | 'or';

    toInterpolation(): Interpolation;
  }

  class UseRule extends Statement {
    readonly url: Object;
    readonly namespace: string | null;
    readonly configuration: ConfiguredVariable[];
  }

  class VariableDeclaration extends Statement {
    readonly namespace: string | null;
    readonly name: string;
    readonly expression: Expression;
    readonly isGuarded: boolean;
    readonly isGlobal: boolean;
  }

  class WarnRule extends Statement {
    readonly expression: Expression;
  }

  class WhileRule extends ParentStatement<Statement[]> {
    readonly condition: Expression;
  }

  class ConfiguredVariable extends SassNode {
    readonly name: string;
    readonly expression: Expression;
    readonly isGuarded: boolean;
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

  class BooleanExpression extends Expression {
    readonly value: boolean;
  }

  class NumberExpression extends Expression {
    readonly value: number;
    readonly unit: string;
  }
}

const sassInternal = (
  sass as unknown as {loadParserExports_(): typeof SassInternal}
).loadParserExports_();

export type SassNode = SassInternal.SassNode;
export type Statement = SassInternal.Statement;
export type ParentStatement<T extends Statement[] | null> =
  SassInternal.ParentStatement<T>;
export type ArgumentList = SassInternal.ArgumentList;
export type AtRootRule = SassInternal.AtRootRule;
export type AtRule = SassInternal.AtRule;
export type ContentBlock = SassInternal.ContentBlock;
export type DebugRule = SassInternal.DebugRule;
export type Declaration = SassInternal.Declaration;
export type EachRule = SassInternal.EachRule;
export type ErrorRule = SassInternal.ErrorRule;
export type ExtendRule = SassInternal.ExtendRule;
export type ForRule = SassInternal.ForRule;
export type ForwardRule = SassInternal.ForwardRule;
export type FunctionRule = SassInternal.FunctionRule;
export type IfRule = SassInternal.IfRule;
export type IfClause = SassInternal.IfClause;
export type ElseClause = SassInternal.ElseClause;
export type ImportRule = SassInternal.ImportRule;
export type DynamicImport = SassInternal.DynamicImport;
export type StaticImport = SassInternal.StaticImport;
export type IncludeRule = SassInternal.IncludeRule;
export type LoudComment = SassInternal.LoudComment;
export type MediaRule = SassInternal.MediaRule;
export type MixinRule = SassInternal.MixinRule;
export type ReturnRule = SassInternal.ReturnRule;
export type SilentComment = SassInternal.SilentComment;
export type Stylesheet = SassInternal.Stylesheet;
export type StyleRule = SassInternal.StyleRule;
export type SupportsRule = SassInternal.SupportsRule;
export type UseRule = SassInternal.UseRule;
export type VariableDeclaration = SassInternal.VariableDeclaration;
export type WarnRule = SassInternal.WarnRule;
export type WhileRule = SassInternal.WhileRule;
export type Parameter = SassInternal.Parameter;
export type ParameterList = SassInternal.ParameterList;
export type ConfiguredVariable = SassInternal.ConfiguredVariable;
export type Interpolation = SassInternal.Interpolation;
export type Expression = SassInternal.Expression;
export type BinaryOperationExpression = SassInternal.BinaryOperationExpression;
export type StringExpression = SassInternal.StringExpression;
export type BooleanExpression = SassInternal.BooleanExpression;
export type NumberExpression = SassInternal.NumberExpression;

export interface StatementVisitorObject<T> {
  visitAtRootRule(node: AtRootRule): T;
  visitAtRule(node: AtRule): T;
  visitDebugRule(node: DebugRule): T;
  visitDeclaration(node: Declaration): T;
  visitEachRule(node: EachRule): T;
  visitErrorRule(node: ErrorRule): T;
  visitExtendRule(node: ExtendRule): T;
  visitForRule(node: ForRule): T;
  visitForwardRule(node: ForwardRule): T;
  visitFunctionRule(node: FunctionRule): T;
  visitIfRule(node: IfRule): T;
  visitImportRule(node: ImportRule): T;
  visitIncludeRule(node: IncludeRule): T;
  visitLoudComment(node: LoudComment): T;
  visitMediaRule(node: MediaRule): T;
  visitMixinRule(node: MixinRule): T;
  visitReturnRule(node: ReturnRule): T;
  visitSilentComment(node: SilentComment): T;
  visitStyleRule(node: StyleRule): T;
  visitSupportsRule(node: SupportsRule): T;
  visitUseRule(node: UseRule): T;
  visitVariableDeclaration(node: VariableDeclaration): T;
  visitWarnRule(node: WarnRule): T;
  visitWhileRule(node: WhileRule): T;
}

export interface ExpressionVisitorObject<T> {
  visitBinaryOperationExpression(node: BinaryOperationExpression): T;
  visitStringExpression(node: StringExpression): T;
  visitBooleanExpression(node: BooleanExpression): T;
  visitNumberExpression(node: NumberExpression): T;
}

export const createExpressionVisitor = sassInternal.createExpressionVisitor;
export const createStatementVisitor = sassInternal.createStatementVisitor;
export const mapToRecord = sassInternal.mapToRecord;
export const parse = sassInternal.parse;
export const parseIdentifier = sassInternal.parseIdentifier;
export const setToJS = sassInternal.setToJS;
export const toCssIdentifier = sassInternal.toCssIdentifier;
