// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import * as postcss from 'postcss';

import {Node} from './node';

/**
 * A type that matches any constructor for {@link T}. From
 * https://www.typescriptlang.org/docs/handbook/mixins.html.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type Constructor<T> = new (...args: any[]) => T;

/**
 * An explicit field description passed to `cloneNode` that describes in detail
 * how to clone it.
 */
interface ExplicitClonableField<Name extends string> {
  /** The field's name. */
  name: Name;

  /**
   * Whether the field can be set to an explicit undefined value which means
   * something different than an absent field.
   */
  explicitUndefined?: boolean;
}

/** The type of field names that can be passed into `cloneNode`. */
type ClonableField<Name extends string> = Name | ExplicitClonableField<Name>;

/** Makes a {@link ClonableField} explicit. */
function parseClonableField<Name extends string>(
  field: ClonableField<Name>
): ExplicitClonableField<Name> {
  return typeof field === 'string' ? {name: field} : field;
}

/**
 * Creates a copy of {@link node} by passing all the properties in {@link
 * constructorFields} as an object to its constructor.
 *
 * If {@link overrides} is passed, it overrides any existing constructor field
 * values. It's also used to assign {@link assignedFields} after the cloned
 * object has been constructed.
 */
export function cloneNode<T extends Pick<postcss.Node, 'source'>>(
  node: T,
  overrides: Record<string, unknown> | undefined,
  constructorFields: ClonableField<keyof T & string>[],
  assignedFields?: ClonableField<keyof T & string>[]
): T {
  // We have to do these casts because the actual `...Prop` types that get
  // passed in and used for the constructor aren't actually subtypes of
  // `Partial<T>`. They use `never` types to ensure that various properties are
  // mutually exclusive, which is not compatible.
  const typedOverrides = overrides as Partial<T> | undefined;
  const constructorFn = node.constructor as new (defaults: Partial<T>) => T;

  const constructorParams: Partial<T> = {};
  for (const field of constructorFields) {
    const {name, explicitUndefined} = parseClonableField(field);
    let value: T[keyof T & string] | undefined;
    if (
      typedOverrides &&
      (explicitUndefined
        ? Object.hasOwn(typedOverrides, name)
        : typedOverrides[name] !== undefined)
    ) {
      value = typedOverrides[name];
    } else {
      value = maybeClone(node[name]);
    }
    if (value !== undefined) constructorParams[name] = value;
  }
  const cloned = new constructorFn(constructorParams);

  if (typedOverrides && assignedFields) {
    for (const field of assignedFields) {
      const {name, explicitUndefined} = parseClonableField(field);
      if (
        explicitUndefined
          ? Object.hasOwn(typedOverrides, name)
          : typedOverrides[name]
      ) {
        // This isn't actually guaranteed to be non-null, but TypeScript
        // (correctly) complains that we could be passing an undefined value to
        // a field that doesn't allow undefined. We don't have a good way of
        // forbidding that while still allowing users to override values that do
        // explicitly allow undefined, though.
        cloned[name] = typedOverrides[name]!;
      }
    }
  }

  cloned.source = node.source;
  return cloned;
}

/**
 * If {@link value} is a Sass node, a record, or an array, clones it and returns
 * the clone. Otherwise, returns it as-is.
 */
function maybeClone<T>(value: T): T {
  if (Array.isArray(value)) return value.map(maybeClone) as T;
  if (typeof value !== 'object' || value === null) return value;
  // The only records we care about are raws, which only contain primitives and
  // arrays of primitives, so structued cloning is safe.
  if (value.constructor === Object) return structuredClone(value);
  if (value instanceof postcss.Node) return value.clone() as T;
  return value;
}

/**
 * Converts {@link node} into a JSON-safe object, with the given {@link fields}
 * included.
 *
 * This always includes the `type`, `sassType`, `raws`, and `source` fields if
 * set. It converts multiple references to the same source input object into
 * indexes into a top-level list.
 */
export function toJSON<T extends Node>(
  node: T,
  fields: (keyof T & string)[],
  inputs?: Map<postcss.Input, number>
): object {
  // Only include the inputs field at the top level.
  const includeInputs = !inputs;
  inputs ??= new Map();
  let inputIndex = inputs.size;

  const result: Record<string, unknown> = {};
  if ('type' in node) result.type = (node as {type: string}).type;

  fields = ['sassType', 'raws', ...fields];
  for (const field of fields) {
    const value = node[field];
    if (value !== undefined) result[field] = toJsonField(field, value, inputs);
  }

  if (node.source) {
    let inputId = inputs.get(node.source.input);
    if (inputId === undefined) {
      inputId = inputIndex++;
      inputs.set(node.source.input, inputId);
    }

    result.source = {
      start: node.source.start,
      end: node.source.end,
      inputId,
    };
  }

  if (includeInputs) {
    result.inputs = [...inputs.keys()].map(input => input.toJSON());
  }
  return result;
}

/**
 * Converts a single field with name {@link field} and value {@link value} to a
 * JSON-safe object.
 *
 * The {@link inputs} map works the same as it does in {@link toJSON}.
 */
function toJsonField(
  field: string,
  value: unknown,
  inputs: Map<postcss.Input, number>
): unknown {
  if (typeof value !== 'object' || value === null) {
    return value;
  } else if (Symbol.iterator in value) {
    return (
      Array.isArray(value) ? value : [...(value as IterableIterator<unknown>)]
    ).map((element, i) => toJsonField(i.toString(), element, inputs));
  } else if ('toJSON' in value) {
    if ('sassType' in value) {
      return (
        value as {
          toJSON: (field: string, inputs: Map<postcss.Input, number>) => object;
        }
      ).toJSON('', inputs);
    } else {
      return (value as {toJSON: (field: string) => object}).toJSON(field);
    }
  } else {
    return value;
  }
}

/**
 * Returns the longest string (of code units) that's an initial substring of
 * every string in
 * {@link strings}.
 */
export function longestCommonInitialSubstring(strings: string[]): string {
  let candidate: string | undefined;
  for (const string of strings) {
    if (candidate === undefined) {
      candidate = string;
    } else {
      for (let i = 0; i < candidate.length && i < string.length; i++) {
        if (candidate.charCodeAt(i) !== string.charCodeAt(i)) {
          candidate = candidate.substring(0, i);
          break;
        }
      }
      candidate = candidate.substring(
        0,
        Math.min(candidate.length, string.length)
      );
    }
  }
  return candidate ?? '';
}
