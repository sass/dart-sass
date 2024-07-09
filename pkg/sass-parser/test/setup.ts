// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import type {ExpectationResult, MatcherContext} from 'expect';
import * as p from 'path';
import * as postcss from 'postcss';
// Unclear why eslint considers this extraneous
// eslint-disable-next-line n/no-extraneous-import
import type * as pretty from 'pretty-format';
import 'jest-extended';

import {Interpolation, StringExpression} from '../lib';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace jest {
    interface AsymmetricMatchers {
      /**
       * Asserts that the object being matched has a property named {@link
       * property} whose value is a {@link Interpolation}, that that
       * interpolation's value is {@link value}, and that the interpolation's
       * parent is the object being tested.
       */
      toHaveInterpolation(property: string, value: string): void;

      /**
       * Asserts that the object being matched has a property named {@link
       * property} whose value is a {@link StringExpression}, that that string's
       * value is {@link value}, and that the string's parent is the object
       * being tested.
       *
       * If {@link property} is a number, it's treated as an index into the
       * `nodes` property of the object being matched.
       */
      toHaveStringExpression(property: string | number, value: string): void;
    }

    interface Matchers<R> {
      toHaveInterpolation(property: string, value: string): R;
      toHaveStringExpression(property: string | number, value: string): R;
    }
  }
}

function toHaveInterpolation(
  this: MatcherContext,
  actual: unknown,
  property: unknown,
  value: unknown
): ExpectationResult {
  if (typeof property !== 'string') {
    throw new TypeError(`Property ${property} must be a string.`);
  } else if (typeof value !== 'string') {
    throw new TypeError(`Value ${value} must be a string.`);
  }

  if (typeof actual !== 'object' || !actual || !(property in actual)) {
    return {
      message: () =>
        `expected ${this.utils.printReceived(
          actual
        )} to have a property ${this.utils.printExpected(property)}`,
      pass: false,
    };
  }

  const actualValue = (actual as Record<string, unknown>)[property];
  const message = (): string =>
    `expected (${this.utils.printReceived(
      actual
    )}).${property} ${this.utils.printReceived(
      actualValue
    )} to be an Interpolation with value ${this.utils.printExpected(value)}`;

  if (
    !(actualValue instanceof Interpolation) ||
    actualValue.asPlain !== value
  ) {
    return {
      message,
      pass: false,
    };
  }

  if (actualValue.parent !== actual) {
    return {
      message: () =>
        `expected (${this.utils.printReceived(
          actual
        )}).${property} ${this.utils.printReceived(
          actualValue
        )} to have the correct parent`,
      pass: false,
    };
  }

  return {message, pass: true};
}

expect.extend({toHaveInterpolation});

function toHaveStringExpression(
  this: MatcherContext,
  actual: unknown,
  propertyOrIndex: unknown,
  value: unknown
): ExpectationResult {
  if (
    typeof propertyOrIndex !== 'string' &&
    typeof propertyOrIndex !== 'number'
  ) {
    throw new TypeError(
      `Property ${propertyOrIndex} must be a string or number.`
    );
  } else if (typeof value !== 'string') {
    throw new TypeError(`Value ${value} must be a string.`);
  }

  let index: number | null = null;
  let property: string;
  if (typeof propertyOrIndex === 'number') {
    index = propertyOrIndex;
    property = 'nodes';
  } else {
    property = propertyOrIndex;
  }

  if (typeof actual !== 'object' || !actual || !(property in actual)) {
    return {
      message: () =>
        `expected ${this.utils.printReceived(
          actual
        )} to have a property ${this.utils.printExpected(property)}`,
      pass: false,
    };
  }

  let actualValue = (actual as Record<string, unknown>)[property];
  if (index !== null) actualValue = (actualValue as unknown[])[index];

  const message = (): string => {
    let message = `expected (${this.utils.printReceived(actual)}).${property}`;
    if (index !== null) message += `[${index}]`;

    return (
      message +
      ` ${this.utils.printReceived(
        actualValue
      )} to be a StringExpression with value ${this.utils.printExpected(value)}`
    );
  };

  if (
    !(actualValue instanceof StringExpression) ||
    actualValue.text.asPlain !== value
  ) {
    return {
      message,
      pass: false,
    };
  }

  if (actualValue.parent !== actual) {
    return {
      message: () =>
        `expected (${this.utils.printReceived(
          actual
        )}).${property} ${this.utils.printReceived(
          actualValue
        )} to have the correct parent`,
      pass: false,
    };
  }

  return {message, pass: true};
}

expect.extend({toHaveStringExpression});

// Serialize nodes using toJSON(), but also updating them to avoid run- or
// machine-specific information in the inputs and to make sources and nested
// nodes more concise.
expect.addSnapshotSerializer({
  test(value: unknown): boolean {
    return value instanceof postcss.Node;
  },

  serialize(
    value: postcss.Node,
    config: pretty.Config,
    indentation: string,
    depth: number,
    refs: pretty.Refs,
    printer: pretty.Printer
  ): string {
    if (depth !== 0) return `<${value}>`;

    const json = value.toJSON() as Record<string, unknown>;
    for (const input of (json as {inputs: Record<string, string>[]}).inputs) {
      if ('id' in input) {
        input.id = input.id.replace(/ [^ >]+>$/, ' _____>');
      }
      if ('file' in input) {
        input.file = p
          .relative(process.cwd(), input.file)
          .replaceAll(p.sep, p.posix.sep);
      }
    }

    // Convert JSON-ified Sass nodes back into their original forms so that they
    // can be serialized tersely in snapshots.
    for (const [key, jsonValue] of Object.entries(json)) {
      if (!jsonValue) continue;
      if (Array.isArray(jsonValue)) {
        const originalArray = value[key as keyof typeof value];
        if (!Array.isArray(originalArray)) continue;

        for (let i = 0; i < jsonValue.length; i++) {
          const element = jsonValue[i];
          if (element && typeof element === 'object' && 'sassType' in element) {
            jsonValue[i] = originalArray[i];
          }
        }
      } else if (
        jsonValue &&
        typeof jsonValue === 'object' &&
        'sassType' in jsonValue
      ) {
        json[key] = value[key as keyof typeof value];
      }
    }

    return printer(json, config, indentation, depth, refs, true);
  },
});

/** The JSON serialization of {@link postcss.Range}. */
interface JsonRange {
  start: JsonPosition;
  end: JsonPosition;
  inputId: number;
}

/** The JSON serialization of {@link postcss.Position}. */
interface JsonPosition {
  line: number;
  column: number;
  offset: number;
}

// Serialize source entries as terse strings because otherwise they take up a
// large amount of room for a small amount of information.
expect.addSnapshotSerializer({
  test(value: unknown): boolean {
    return (
      !!value &&
      typeof value === 'object' &&
      'inputId' in value &&
      'start' in value &&
      'end' in value
    );
  },

  serialize(value: JsonRange): string {
    return (
      `<${tersePosition(value.start)}-${tersePosition(value.end)} in ` +
      `${value.inputId}>`
    );
  },
});

/** Converts a {@link JsonPosition} into a terse string representation. */
function tersePosition(position: JsonPosition): string {
  if (position.offset !== position.column - 1) {
    throw new Error(
      'Expected offset to be 1 less than column. Column is ' +
        `${position.column} and offset is ${position.offset}.`
    );
  }

  return `${position.line}:${position.column}`;
}

export {};
