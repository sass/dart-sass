This package provides a shared static analysis configuration for use by Sass
team Dart and TypeScript packages.

## Use from Dart

Add this as a Git dependency to your `pubspec.yaml`:

```yaml
dev_dependencies:
  sass_analysis:
    git: {url: https://github.com/sass/dart-sass.git, path: analysis}
```

and include it in your `analysis_options.yaml`:

```yaml
include: package:sass_analysis/analysis_options.yaml
```

## Use from TypeScript

Add this and [gts] as Git dependencies to your `package.json`, then initialize
gts:

[gts]: https://github.com/google/gts

```sh
$ npm i --save-dev gts 'https://gitpkg.vercel.app/sass/dart-sass/analysis?main'
$ npx gts init
```

Then edit the configuration files to use Sass-specific customizations instead of
the gts defaults:

* `eslintrc.json`:

  ```json
  {
    "extends": "./node_modules/sass-analysis/"
  }
  ```

* `.prettierrc.js`:

  ```json
  module.exports = {
    ...require(sass-analysis/.prettierrc.js')
  }
  ```

* `tsconfig.json`:

  ```json
  {
    "extends": "./node_modules/sass-analysis/tsconfig.json",
    "compilerOptions": {
      "rootDir": ".",
      "outDir": "build"
    },
    "include": [
      "src/**/*.ts",
      "test/**/*.ts"
    ]
  }
  ```
