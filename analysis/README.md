This package provides a shared set of analysis options for use by Sass team
packages. To use it, add it as a Git dependency to your `pubspec.yaml`:

```yaml
dev_dependencies:
  sass_analysis:
    git: {url: git://github.com/sass/dart-sass.git, path: analysis}
```

and include it in your `analysis_options.yaml`:

```yaml
include: package:sass_analysis/analysis_options.yaml
```
