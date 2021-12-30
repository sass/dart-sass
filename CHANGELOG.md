## 1.0.0-beta.15

* Support version 1.0.0-beta.17 of the Sass embedded protocol:

  * Treat invalid host function signatures as function errors rather than
    protocol errors.

  * Allow `ImportResponse.result` to be null.

* Fix a bug where the compiler could return a `CompileFailure` without a span.

## 1.0.0-beta.14

* Support `FileImporter`s.

## 1.0.0-beta.13

* Report a better error message for an empty `CompileRequest.Input.path`.

## 1.0.0-beta.12

* Support version 1.0.0-beta.14 of the Sass embedded protocol:
  * Support `Value.Calculation`.

## 1.0.0-beta.11

* Support version 1.0.0-beta.13 of the Sass embedded protocol:
  * Support `Value.HwbColor`.
  * Emit colors as `Value.HslColor` if that internal representation is
    available.

* Add a `--version` flag that will print a `VersionResponse` as JSON, for ease
  of human identification.

## 1.0.0-beta.10

* Support version 1.0.0-beta.12 of the Sass embedded protocol:
  * Support `Value.ArgumentList`.

* Support slash-separated lists.

## 1.0.0-beta.9

* No user-visible changes.

## 1.0.0-beta.8

* Support version 1.0.0-beta.11 of the Sass embedded protocol:
  * Support `VersionRequest` and `VersionResponse`.
  * Support `CompileRequest.quiet_deps` and `.verbose`.
  * Set `CanonicalizeRequest.from_import`.
  * Set `CompileSuccess.loaded_urls`.

* Properly throw errors for range checks for colors.
