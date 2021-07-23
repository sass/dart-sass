## 1.0.0-beta.8

* Support version 1.0.0-beta.11 of the Sass embedded protocol:
  * Support `VersionRequest` and `VersionResponse`.
  * Support `CompileRequest.quiet_deps` and `.verbose`.
  * Set `CanonicalizeRequest.from_import`.
  * Set `CompileSuccess.loaded_urls`.

* Properly throw errors for range checks for colors.
