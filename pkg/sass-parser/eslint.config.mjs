import {defineConfig, globalIgnores} from 'eslint/config';
import gts from 'gts';

export default defineConfig([
  globalIgnores(['**/dist/', '**/*.js']),
  {
    extends: [...gts],

    rules: {
      '@typescript-eslint/explicit-function-return-type': [
        'error',
        {
          allowExpressions: true,
        },
      ],

      'func-style': ['error', 'declaration'],

      'prefer-const': [
        'error',
        {
          destructuring: 'all',
        },
      ],

      'sort-imports': [
        'error',
        {
          ignoreDeclarationSort: true,
        },
      ],
    },
  },
]);
