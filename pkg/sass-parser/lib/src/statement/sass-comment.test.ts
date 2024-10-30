// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import {Root, Rule, SassComment, sass, scss} from '../..';
import * as utils from '../../../test/utils';

describe('a Sass-style comment', () => {
  let node: SassComment;
  function describeNode(description: string, create: () => SassComment): void {
    describe(description, () => {
      beforeEach(() => void (node = create()));

      it('has type comment', () => expect(node.type).toBe('comment'));

      it('has sassType sass-comment', () =>
        expect(node.sassType).toBe('sass-comment'));

      it('has matching text', () => expect(node.text).toBe('foo\nbar'));

      it('has matching silentText', () => expect(node.text).toBe('foo\nbar'));
    });
  }

  describeNode(
    'parsed as SCSS',
    () => scss.parse('// foo\n// bar').nodes[0] as SassComment
  );

  describeNode(
    'parsed as Sass',
    () => sass.parse('// foo\n// bar').nodes[0] as SassComment
  );

  describeNode(
    'constructed manually',
    () => new SassComment({text: 'foo\nbar'})
  );

  describeNode('constructed from ChildProps', () =>
    utils.fromChildProps({silentText: 'foo\nbar'})
  );

  describe('parses raws', () => {
    describe('in SCSS', () => {
      it('with consistent whitespace before and after //', () => {
        const node = scss.parse('  // foo\n  // bar\n  // baz')
          .nodes[0] as SassComment;
        expect(node.text).toEqual('foo\nbar\nbaz');
        expect(node.raws).toEqual({
          before: '  ',
          beforeLines: ['', '', ''],
          left: ' ',
        });
      });

      it('with an empty line', () => {
        const node = scss.parse('// foo\n//\n// baz').nodes[0] as SassComment;
        expect(node.text).toEqual('foo\n\nbaz');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: ['', '', ''],
          left: ' ',
        });
      });

      it('with a line with only whitespace', () => {
        const node = scss.parse('// foo\n// \t \n// baz')
          .nodes[0] as SassComment;
        expect(node.text).toEqual('foo\n \t \nbaz');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: ['', '', ''],
          left: ' ',
        });
      });

      it('with inconsistent whitespace before //', () => {
        const node = scss.parse('  // foo\n // bar\n   // baz')
          .nodes[0] as SassComment;
        expect(node.text).toEqual('foo\nbar\nbaz');
        expect(node.raws).toEqual({
          before: ' ',
          beforeLines: [' ', '', '  '],
          left: ' ',
        });
      });

      it('with inconsistent whitespace types before //', () => {
        const node = scss.parse(' \t// foo\n  // bar').nodes[0] as SassComment;
        expect(node.text).toEqual('foo\nbar');
        expect(node.raws).toEqual({
          before: ' ',
          beforeLines: ['\t', ' '],
          left: ' ',
        });
      });

      it('with consistent whitespace types before //', () => {
        const node = scss.parse(' \t// foo\n \t// bar').nodes[0] as SassComment;
        expect(node.text).toEqual('foo\nbar');
        expect(node.raws).toEqual({
          before: ' \t',
          beforeLines: ['', ''],
          left: ' ',
        });
      });

      it('with inconsistent whitespace after //', () => {
        const node = scss.parse('//  foo\n// bar\n//   baz')
          .nodes[0] as SassComment;
        expect(node.text).toEqual(' foo\nbar\n  baz');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: ['', '', ''],
          left: ' ',
        });
      });

      it('with inconsistent whitespace types after //', () => {
        const node = scss.parse('//  foo\n// \tbar').nodes[0] as SassComment;
        expect(node.text).toEqual(' foo\n\tbar');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: ['', ''],
          left: ' ',
        });
      });

      it('with consistent whitespace types after //', () => {
        const node = scss.parse('// \tfoo\n// \tbar').nodes[0] as SassComment;
        expect(node.text).toEqual('foo\nbar');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: ['', ''],
          left: ' \t',
        });
      });

      it('with no text after //', () => {
        const node = scss.parse('//').nodes[0] as SassComment;
        expect(node.text).toEqual('');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: [''],
          left: '',
        });
      });
    });

    describe('in Sass', () => {
      it('with an empty line', () => {
        const node = sass.parse('// foo\n//\n// baz').nodes[0] as SassComment;
        expect(node.text).toEqual('foo\n\nbaz');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: ['', '', ''],
          left: ' ',
        });
      });

      it('with a line with only whitespace', () => {
        const node = sass.parse('// foo\n// \t \n// baz')
          .nodes[0] as SassComment;
        expect(node.text).toEqual('foo\n \t \nbaz');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: ['', '', ''],
          left: ' ',
        });
      });

      it('with inconsistent whitespace after //', () => {
        const node = sass.parse('//  foo\n// bar\n//   baz')
          .nodes[0] as SassComment;
        expect(node.text).toEqual(' foo\nbar\n  baz');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: ['', '', ''],
          left: ' ',
        });
      });

      it('with inconsistent whitespace types after //', () => {
        const node = sass.parse('//  foo\n// \tbar').nodes[0] as SassComment;
        expect(node.text).toEqual(' foo\n\tbar');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: ['', ''],
          left: ' ',
        });
      });

      it('with consistent whitespace types after //', () => {
        const node = sass.parse('// \tfoo\n// \tbar').nodes[0] as SassComment;
        expect(node.text).toEqual('foo\nbar');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: ['', ''],
          left: ' \t',
        });
      });

      it('with no text after //', () => {
        const node = sass.parse('//').nodes[0] as SassComment;
        expect(node.text).toEqual('');
        expect(node.raws).toEqual({
          before: '',
          beforeLines: [''],
          left: '',
        });
      });
    });
  });

  describe('stringifies', () => {
    describe('to SCSS', () => {
      it('with default raws', () =>
        expect(new SassComment({text: 'foo\nbar'}).toString()).toBe(
          '// foo\n// bar'
        ));

      it('with left', () =>
        expect(
          new SassComment({
            text: 'foo\nbar',
            raws: {left: '\t'},
          }).toString()
        ).toBe('//\tfoo\n//\tbar'));

      it('with left and an empty line', () =>
        expect(
          new SassComment({
            text: 'foo\n\nbar',
            raws: {left: '\t'},
          }).toString()
        ).toBe('//\tfoo\n//\n//\tbar'));

      it('with left and a whitespace-only line', () =>
        expect(
          new SassComment({
            text: 'foo\n \nbar',
            raws: {left: '\t'},
          }).toString()
        ).toBe('//\tfoo\n// \n//\tbar'));

      it('with before', () =>
        expect(
          new SassComment({
            text: 'foo\nbar',
            raws: {before: '\t'},
          }).toString()
        ).toBe('\t// foo\n\t// bar'));

      it('with beforeLines', () =>
        expect(
          new Root({
            nodes: [
              new SassComment({
                text: 'foo\nbar',
                raws: {beforeLines: [' ', '\t']},
              }),
            ],
          }).toString()
        ).toBe(' // foo\n\t// bar'));

      describe('with a following sibling', () => {
        it('without before', () =>
          expect(
            new Root({
              nodes: [{silentText: 'foo\nbar'}, {name: 'baz'}],
            }).toString()
          ).toBe('// foo\n// bar\n@baz'));

        it('with before with newline', () =>
          expect(
            new Root({
              nodes: [
                {silentText: 'foo\nbar'},
                {name: 'baz', raws: {before: '\n  '}},
              ],
            }).toString()
          ).toBe('// foo\n// bar\n  @baz'));

        it('with before without newline', () =>
          expect(
            new Root({
              nodes: [
                {silentText: 'foo\nbar'},
                {name: 'baz', raws: {before: '  '}},
              ],
            }).toString()
          ).toBe('// foo\n// bar\n  @baz'));
      });

      describe('in a nested rule', () => {
        it('without after', () =>
          expect(
            new Rule({
              selector: '.zip',
              nodes: [{silentText: 'foo\nbar'}],
            }).toString()
          ).toBe('.zip {\n    // foo\n// bar\n}'));

        it('with after with newline', () =>
          expect(
            new Rule({
              selector: '.zip',
              nodes: [{silentText: 'foo\nbar'}],
              raws: {after: '\n  '},
            }).toString()
          ).toBe('.zip {\n    // foo\n// bar\n  }'));

        it('with after without newline', () =>
          expect(
            new Rule({
              selector: '.zip',
              nodes: [{silentText: 'foo\nbar'}],
              raws: {after: '  '},
            }).toString()
          ).toBe('.zip {\n    // foo\n// bar\n  }'));
      });
    });
  });

  describe('assigned new text', () => {
    beforeEach(() => {
      node = scss.parse('// foo').nodes[0] as SassComment;
    });

    it('updates text', () => {
      node.text = 'bar';
      expect(node.text).toBe('bar');
    });

    it('updates silentText', () => {
      node.text = 'bar';
      expect(node.silentText).toBe('bar');
    });
  });

  describe('assigned new silentText', () => {
    beforeEach(() => {
      node = scss.parse('// foo').nodes[0] as SassComment;
    });

    it('updates text', () => {
      node.silentText = 'bar';
      expect(node.text).toBe('bar');
    });

    it('updates silentText', () => {
      node.silentText = 'bar';
      expect(node.silentText).toBe('bar');
    });
  });

  describe('clone', () => {
    let original: SassComment;
    beforeEach(
      () => void (original = scss.parse('// foo').nodes[0] as SassComment)
    );

    describe('with no overrides', () => {
      let clone: SassComment;
      beforeEach(() => {
        clone = original.clone();
      });

      describe('has the same properties:', () => {
        it('text', () => expect(clone.text).toBe('foo'));

        it('silentText', () => expect(clone.silentText).toBe('foo'));

        it('raws', () =>
          expect(clone.raws).toEqual({
            before: '',
            beforeLines: [''],
            left: ' ',
          }));

        it('source', () => expect(clone.source).toBe(original.source));
      });

      describe('creates a new', () => {
        it('self', () => expect(clone).not.toBe(original));

        it('raws.beforeLines', () =>
          expect(clone.raws.beforeLines).not.toBe(original.raws.beforeLines));

        for (const attr of ['raws'] as const) {
          it(attr, () => expect(clone[attr]).not.toBe(original[attr]));
        }
      });
    });

    describe('overrides', () => {
      describe('text', () => {
        describe('defined', () => {
          let clone: SassComment;
          beforeEach(() => {
            clone = original.clone({text: 'bar'});
          });

          it('changes text', () => expect(clone.text).toBe('bar'));

          it('changes silentText', () => expect(clone.silentText).toBe('bar'));
        });

        describe('undefined', () => {
          let clone: SassComment;
          beforeEach(() => {
            clone = original.clone({text: undefined});
          });

          it('preserves text', () => expect(clone.text).toBe('foo'));

          it('preserves silentText', () =>
            expect(clone.silentText).toBe('foo'));
        });
      });

      describe('text', () => {
        describe('defined', () => {
          let clone: SassComment;
          beforeEach(() => {
            clone = original.clone({silentText: 'bar'});
          });

          it('changes text', () => expect(clone.text).toBe('bar'));

          it('changes silentText', () => expect(clone.silentText).toBe('bar'));
        });

        describe('undefined', () => {
          let clone: SassComment;
          beforeEach(() => {
            clone = original.clone({silentText: undefined});
          });

          it('preserves text', () => expect(clone.text).toBe('foo'));

          it('preserves silentText', () =>
            expect(clone.silentText).toBe('foo'));
        });
      });

      describe('raws', () => {
        it('defined', () =>
          expect(original.clone({raws: {left: '  '}}).raws).toEqual({
            left: '  ',
          }));

        it('undefined', () =>
          expect(original.clone({raws: undefined}).raws).toEqual({
            before: '',
            beforeLines: [''],
            left: ' ',
          }));
      });
    });
  });

  it('toJSON', () => expect(scss.parse('// foo').nodes[0]).toMatchSnapshot());
});
