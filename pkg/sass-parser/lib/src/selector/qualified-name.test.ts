// Copyright 2025 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Interpolation, QualifiedName, TypeSelector} from '../..';
import * as utils from '../../../test/utils';

/** Parses {@link text} as a qualified name. */
function parseQualifiedName(text: string): QualifiedName {
  const selector = utils.parseSimpleSelector(text);
  expect(selector.sassType).toBe('type');
  return (selector as TypeSelector).type;
}

describe('a qualified name', () => {
  let node: QualifiedName;

  describe('with a namespace', () => {
    function describeNode(
      description: string,
      create: () => QualifiedName,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType qualified-name', () =>
          expect(node.sassType).toBe('qualified-name'));

        it('has a namespace', () =>
          expect(node).toHaveInterpolation('namespace', 'foo'));

        it('has a name', () => expect(node).toHaveInterpolation('name', 'bar'));
      });
    }

    describeNode('parsed', () => parseQualifiedName('foo|bar'));

    describeNode(
      'constructed manually',
      () => new QualifiedName({namespace: 'foo', name: 'bar'}),
    );
  });

  describe('with a universal namespace', () => {
    function describeNode(
      description: string,
      create: () => QualifiedName,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType qualified-name', () =>
          expect(node.sassType).toBe('qualified-name'));

        it('has a namespace', () =>
          expect(node).toHaveInterpolation('namespace', '*'));

        it('has a name', () => expect(node).toHaveInterpolation('name', 'foo'));
      });
    }

    describeNode('parsed', () => parseQualifiedName('*|foo'));

    describeNode(
      'constructed manually',
      () => new QualifiedName({namespace: '*', name: 'foo'}),
    );
  });

  describe('with an empty namespace', () => {
    function describeNode(
      description: string,
      create: () => QualifiedName,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType qualified-name', () =>
          expect(node.sassType).toBe('qualified-name'));

        it('has a namespace', () =>
          expect(node).toHaveInterpolation('namespace', ''));

        it('has a name', () => expect(node).toHaveInterpolation('name', 'foo'));
      });
    }

    describeNode('parsed', () => parseQualifiedName('|foo'));

    describeNode(
      'constructed manually',
      () => new QualifiedName({namespace: '', name: 'foo'}),
    );
  });

  describe('without a namespace', () => {
    function describeNode(
      description: string,
      create: () => QualifiedName,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType qulaified-name', () =>
          expect(node.sassType).toBe('qualified-name'));

        it('has sassType qualified-name', () =>
          expect(node.sassType).toBe('qualified-name'));

        it('has no namespace', () => expect(node.namespace).toBeUndefined());

        it('has a name', () => expect(node).toHaveInterpolation('name', 'bar'));
      });
    }

    describeNode('parsed', () => parseQualifiedName('bar'));

    describeNode(
      'constructed manually',
      () => new QualifiedName({name: 'bar'}),
    );
  });

  describe('with interpolation', () => {
    function describeNode(
      description: string,
      create: () => QualifiedName,
    ): void {
      describe(description, () => {
        beforeEach(() => void (node = create()));

        it('has sassType qualified-name', () =>
          expect(node.sassType).toBe('qualified-name'));

        it('has a namespace', () =>
          expect(node.namespace!).toHaveStringExpression(0, 'foo'));

        it('has a name', () =>
          expect(node.name).toHaveStringExpression(0, 'bar'));
      });
    }

    describeNode('parsed', () => parseQualifiedName('#{foo}|#{bar}'));

    describeNode(
      'constructed manually',
      () =>
        new QualifiedName({namespace: [{text: 'foo'}], name: [{text: 'bar'}]}),
    );
  });

  describe('assigned new', () => {
    beforeEach(() => void (node = parseQualifiedName('foo|bar')));

    describe('namespace', () => {
      it("removes the old namespace's parent", () => {
        const oldNamespace = node.namespace;
        node.namespace = 'bar';
        expect(oldNamespace!.parent).toBeUndefined();
      });

      it('assigns namespace explicitly', () => {
        const namespace = new Interpolation('bar');
        node.namespace = namespace;
        expect(node.namespace).toBe(namespace);
        expect(node).toHaveInterpolation('namespace', 'bar');
      });

      it('assigns namespace as InterpolationProps', () => {
        node.namespace = 'bar';
        expect(node).toHaveInterpolation('namespace', 'bar');
      });

      it('assigns undefined namespace', () => {
        const oldNamespace = node.namespace;
        node.namespace = undefined;
        expect(oldNamespace!.parent).toBeUndefined();
        expect(node.namespace).toBeUndefined();
      });
    });

    describe('name', () => {
      it("removes the old name's parent", () => {
        const oldName = node.name;
        node.name = 'bar';
        expect(oldName.parent).toBeUndefined();
      });

      it('assigns name explicitly', () => {
        const name = new Interpolation('bar');
        node.name = name;
        expect(node.name).toBe(name);
        expect(node).toHaveInterpolation('name', 'bar');
      });

      it('assigns name as InterpolationProps', () => {
        node.name = 'bar';
        expect(node).toHaveInterpolation('name', 'bar');
      });
    });
  });

  describe('stringifies', () => {
    it('with a namespace', () => {
      expect(parseQualifiedName('foo|bar').toString()).toBe('foo|bar');
    });

    it('without a namespace', () => {
      expect(parseQualifiedName('foo').toString()).toBe('foo');
    });
  });

  describe('clone', () => {
    let original: QualifiedName;

    beforeEach(() => {
      original = parseQualifiedName('foo|bar');
    });

    describe('with no overrides', () => {
      let clone: QualifiedName;

      beforeEach(() => void (clone = original.clone()));

      describe('has the same properties:', () => {
        it('namespace', () =>
          expect(clone).toHaveInterpolation('namespace', 'foo'));

        it('name', () => expect(clone).toHaveInterpolation('name', 'bar'));

        it('raws', () => expect(clone.raws).toEqual({}));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        for (const attr of ['namespace', 'name', 'raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('namespace', () => {
        it('defined', () =>
          expect(original.clone({namespace: 'baz'})).toHaveInterpolation(
            'namespace',
            'baz',
          ));

        it('undefined', () =>
          expect(
            original.clone({namespace: undefined}).namespace,
          ).toBeUndefined());
      });

      describe('name', () => {
        it('defined', () =>
          expect(original.clone({name: 'baz'})).toHaveInterpolation(
            'name',
            'baz',
          ));

        it('undefined', () =>
          expect(original.clone({name: undefined})).toHaveInterpolation(
            'name',
            'bar',
          ));
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {}}).raws).toEqual({}));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({}));
      });
    });
  });

  describe('toJSON', () => {
    it('with a namespace', () =>
      expect(parseQualifiedName('foo|bar')).toMatchSnapshot());

    it('without a namespace', () =>
      expect(parseQualifiedName('foo')).toMatchSnapshot());
  });
});
