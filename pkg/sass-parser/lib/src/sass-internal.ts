// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';
import * as sass from 'sass';

import type * as binaryOperation from './expression/binary-operation';
import type * as unaryOperation from './expression/unary-operation';

// Type definitions for internal Sass APIs we're wrapping. We cast the Sass
// module to this type to access them.

export type Syntax = 'scss' | 'sass' | 'css';

export interface FileSpan extends sass.SourceSpan {
  readonly file: SourceFile;
}

export interface SourceFile {
  /** Node-only extension that we use to avoid re-creating inputs. */
  _postcssInput?: postcss.Input;

  length: number;

  readonly codeUnits: number[];

  getText(start: number, end?: number): string;

  span(start: number, end?: number): FileSpan;
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

export interface DartPair<E1, E2> {
  _0: E1;
  _1: E2;
}

/// An interface representing simple Dart enums whose string values will be used
/// by JS.
export interface DartEnum<N extends string> {
  name: N;
}

// There may be a better way to declare this, but I can't figure it out.
// eslint-disable-next-line @typescript-eslint/no-namespace
declare namespace SassInternal {
  function parse(css: string, syntax: Syntax, path?: string): Stylesheet;

  function parseSelectorList(contents: string, path?: string): SelectorList;

  function parseIdentifier(
    identifier: string,
    logger?: sass.Logger,
  ): string | null;

  function createSourceFile(text: string, path?: string): SourceFile;

  function toCssIdentifier(text: string): string;

  function setToJS<T>(set: DartSet<T>): Set<T>;

  function mapToRecord<T>(set: DartMap<string, T>): Record<string, T>;

  class StatementVisitor<T> {
    private _fakePropertyToMakeStatementVisitorAUniqueType: T;
  }

  function createStatementVisitor<T>(
    inner: StatementVisitorObject<T>,
  ): StatementVisitor<T>;

  class ExpressionVisitor<T> {
    private _fakePropertyToMakeExpressionVisitorAUniqueType: T;
  }

  function createExpressionVisitor<T>(
    inner: ExpressionVisitorObject<T>,
  ): ExpressionVisitor<T>;

  class IfConditionExpressionVisitor<T> {
    private _fakePropertyToMakeIfConditionExpressionVisitorAUniqueType: T;
  }

  function createIfConditionExpressionVisitor<T>(
    inner: IfConditionExpressionVisitorObject<T>,
  ): IfConditionExpressionVisitor<T>;

  class SassNode {
    readonly span: FileSpan;
  }

  class CssValue<T> extends SassNode {
    readonly value: T;
  }

  class ArgumentList extends SassNode {
    readonly positional: Expression[];
    readonly named: DartMap<string, Expression>;
    readonly rest?: Expression;
    readonly keywordRest?: Expression;
  }

  class Interpolation extends SassNode {
    spans: (FileSpan | undefined)[];
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

  class ContentRule extends Statement {
    readonly arguments: ArgumentList;
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
    readonly url: object;
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
    readonly parsedSelector: SelectorList;
  }

  class SupportsRule extends ParentStatement<Statement[]> {
    readonly condition: SupportsCondition;
  }

  interface SupportsCondition extends SassNode {
    toInterpolation(): Interpolation;
  }

  class UseRule extends Statement {
    readonly url: object;
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

  // Expressions

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
  }

  class FunctionExpression extends Expression {
    readonly namespace: string | null | undefined;
    readonly name: string;
    readonly arguments: ArgumentList;
  }

  class LegacyIfExpression extends Expression {
    readonly arguments: ArgumentList;
  }

  class InterpolatedFunctionExpression extends Expression {
    readonly name: Interpolation;
    readonly arguments: ArgumentList;
  }

  class ListExpression extends Expression {
    readonly contents: Expression[];
    readonly separator: ListSeparator;
    readonly hasBrackets: boolean;
  }

  class ListSeparator {
    readonly separator: ' ' | ',' | '/' | null | undefined;
  }

  class MapExpression extends Expression {
    readonly pairs: DartPair<Expression, Expression>[];
  }

  class BooleanExpression extends Expression {
    readonly value: boolean;
  }

  class ColorExpression extends Expression {
    readonly value: sass.SassColor;
  }

  class IfExpression extends Expression {
    readonly branches: DartPair<
      IfConditionExpression | undefined,
      Expression
    >[];
  }

  class IfConditionExpression extends SassNode {
    accept<T>(visitor: IfConditionExpressionVisitor<T>): T;
  }

  class IfConditionParenthesized extends IfConditionExpression {
    readonly expression: IfConditionExpression;
  }

  class IfConditionNegation extends IfConditionExpression {
    readonly expression: IfConditionExpression;
  }

  class IfConditionOperation extends IfConditionExpression {
    readonly expressions: IfConditionExpression[];
    readonly op: DartEnum<'and' | 'or'>;
  }

  class IfConditionFunction extends IfConditionExpression {
    readonly name: Interpolation;
    readonly arguments: Interpolation;
  }

  class IfConditionSass extends IfConditionExpression {
    readonly expression: Expression;
  }

  class IfConditionRaw extends IfConditionExpression {
    readonly text: Interpolation;
  }

  class NullExpression extends Expression {}

  class NumberExpression extends Expression {
    readonly value: number;
    readonly unit: string;
  }

  class ParenthesizedExpression extends Expression {
    readonly expression: Expression;
  }

  class SelectorExpression extends Expression {}

  class StringExpression extends Expression {
    readonly text: Interpolation;
    readonly hasQuotes: boolean;
  }

  class SupportsExpression extends Expression {
    readonly condition: SupportsCondition;
  }

  class UnaryOperator {
    readonly operator: unaryOperation.UnaryOperator;
  }

  class UnaryOperationExpression extends Expression {
    readonly operator: UnaryOperator;
    readonly operand: Expression;
  }

  class VariableExpression extends Expression {
    readonly namespace?: string | null;
    readonly name: string;
  }

  // Selectors

  class SimpleSelectorVisitor<T> {
    private _fakePropertyToMakeSimpleSelectorVisitorAUniqueType: T;
  }

  function createSimpleSelectorVisitor<T>(
    inner: SimpleSelectorVisitorObject<T>,
  ): SimpleSelectorVisitor<T>;

  class SimpleSelector extends SassNode {
    accept<T>(visitor: SimpleSelectorVisitor<T>): T;
  }

  class AttributeSelector extends SimpleSelector {
    readonly name: QualifiedName;
    readonly op: object;
    readonly value: Interpolation | null | undefined;
    readonly modifier: Interpolation | null | undefined;
  }

  class ClassSelector extends SimpleSelector {
    readonly name: Interpolation;
  }

  class ComplexSelector extends SassNode {
    readonly leadingCombinator: CssValue<object> | null | undefined;
    readonly components: ComplexSelectorComponent[];
  }

  class ComplexSelectorComponent extends SassNode {
    readonly selector: CompoundSelector;
    readonly combinator: CssValue<object> | null | undefined;
  }

  class CompoundSelector extends SassNode {
    readonly components: SimpleSelector[];
  }

  class IDSelector extends SimpleSelector {
    readonly name: Interpolation;
  }

  class SelectorList extends SassNode {
    readonly components: ComplexSelector[];
  }

  class ParentSelector extends SimpleSelector {
    readonly suffix: Interpolation | undefined;
  }

  class PlaceholderSelector extends SimpleSelector {
    readonly name: Interpolation;
  }

  class PseudoSelector extends SimpleSelector {
    readonly name: Interpolation;
    readonly isSyntacticClass: boolean;
    readonly argument: Interpolation | null | undefined;
    readonly selector: SelectorList | null | undefined;
  }

  class QualifiedName extends SassNode {
    readonly name: Interpolation;
    readonly namespace: Interpolation | null | undefined;
  }

  class TypeSelector extends SimpleSelector {
    readonly name: QualifiedName;
  }

  class UniversalSelector extends SimpleSelector {
    readonly namespace: Interpolation | null | undefined;
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
export type ContentRule = SassInternal.ContentRule;
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

// Expressions
export type Expression = SassInternal.Expression;
export type BinaryOperationExpression = SassInternal.BinaryOperationExpression;
export type FunctionExpression = SassInternal.FunctionExpression;
export type IfExpression = SassInternal.IfExpression;
export type IfConditionExpression = SassInternal.IfConditionExpression;
export type IfConditionParenthesized = SassInternal.IfConditionParenthesized;
export type IfConditionNegation = SassInternal.IfConditionNegation;
export type IfConditionOperation = SassInternal.IfConditionOperation;
export type IfConditionFunction = SassInternal.IfConditionFunction;
export type IfConditionSass = SassInternal.IfConditionSass;
export type IfConditionRaw = SassInternal.IfConditionRaw;

export type InterpolatedFunctionExpression =
  SassInternal.InterpolatedFunctionExpression;
export type LegacyIfExpression = SassInternal.LegacyIfExpression;
export type ListExpression = SassInternal.ListExpression;
export type ListSeparator = SassInternal.ListSeparator;
export type MapExpression = SassInternal.MapExpression;
export type BooleanExpression = SassInternal.BooleanExpression;
export type ColorExpression = SassInternal.ColorExpression;
export type NullExpression = SassInternal.NullExpression;
export type NumberExpression = SassInternal.NumberExpression;
export type ParenthesizedExpression = SassInternal.ParenthesizedExpression;
export type SelectorExpression = SassInternal.SelectorExpression;
export type StringExpression = SassInternal.StringExpression;
export type SupportsExpression = SassInternal.SupportsExpression;
export type UnaryOperationExpression = SassInternal.UnaryOperationExpression;
export type VariableExpression = SassInternal.VariableExpression;

// Selectors
export type SimpleSelector = SassInternal.SimpleSelector;
export type AttributeSelector = SassInternal.AttributeSelector;
export type ClassSelector = SassInternal.ClassSelector;
export type ComplexSelector = SassInternal.ComplexSelector;
export type ComplexSelectorComponent = SassInternal.ComplexSelectorComponent;
export type CompoundSelector = SassInternal.CompoundSelector;
export type IDSelector = SassInternal.IDSelector;
export type SelectorList = SassInternal.SelectorList;
export type ParentSelector = SassInternal.ParentSelector;
export type PlaceholderSelector = SassInternal.PlaceholderSelector;
export type PseudoSelector = SassInternal.PseudoSelector;
export type QualifiedName = SassInternal.QualifiedName;
export type TypeSelector = SassInternal.TypeSelector;
export type UniversalSelector = SassInternal.UniversalSelector;

export interface StatementVisitorObject<T> {
  visitAtRootRule(node: AtRootRule): T;
  visitAtRule(node: AtRule): T;
  visitContentRule(node: ContentRule): T;
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
  visitBooleanExpression(node: BooleanExpression): T;
  visitColorExpression(node: ColorExpression): T;
  visitFunctionExpression(node: FunctionExpression): T;
  visitIfExpression(node: IfExpression): T;
  visitInterpolatedFunctionExpression(node: InterpolatedFunctionExpression): T;
  visitLegacyIfExpression(node: LegacyIfExpression): T;
  visitListExpression(node: ListExpression): T;
  visitMapExpression(node: MapExpression): T;
  visitNullExpression(node: NullExpression): T;
  visitNumberExpression(node: NumberExpression): T;
  visitParenthesizedExpression(node: ParenthesizedExpression): T;
  visitSelectorExpression(node: SelectorExpression): T;
  visitStringExpression(node: StringExpression): T;
  visitSupportsExpression(node: SupportsExpression): T;
  visitUnaryOperationExpression(node: UnaryOperationExpression): T;
  visitVariableExpression(node: VariableExpression): T;
}

export interface IfConditionExpressionVisitorObject<T> {
  visitIfConditionFunction(node: IfConditionFunction): T;
  visitIfConditionNegation(node: IfConditionNegation): T;
  visitIfConditionOperation(node: IfConditionOperation): T;
  visitIfConditionParenthesized(node: IfConditionParenthesized): T;
  visitIfConditionRaw(node: IfConditionRaw): T;
  visitIfConditionSass(node: IfConditionSass): T;
}

export interface SimpleSelectorVisitorObject<T> {
  visitAttributeSelector(node: AttributeSelector): T;
  visitClassSelector(node: ClassSelector): T;
  visitIDSelector(node: IDSelector): T;
  visitParentSelector(node: ParentSelector): T;
  visitPlaceholderSelector(node: PlaceholderSelector): T;
  visitPseudoSelector(node: PseudoSelector): T;
  visitTypeSelector(node: TypeSelector): T;
  visitUniversalSelector(node: UniversalSelector): T;
}

export const createExpressionVisitor = sassInternal.createExpressionVisitor;
export const createIfConditionExpressionVisitor =
  sassInternal.createIfConditionExpressionVisitor;
export const createSimpleSelectorVisitor =
  sassInternal.createSimpleSelectorVisitor;
export const createSourceFile = sassInternal.createSourceFile;
export const createStatementVisitor = sassInternal.createStatementVisitor;
export const mapToRecord = sassInternal.mapToRecord;
export const parse = sassInternal.parse;
export const parseIdentifier = sassInternal.parseIdentifier;
export const parseSelectorList = sassInternal.parseSelectorList;
export const setToJS = sassInternal.setToJS;
export const toCssIdentifier = sassInternal.toCssIdentifier;
