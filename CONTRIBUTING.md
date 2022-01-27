# How to Contribute

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement. You (or your employer) retain the copyright to your contribution;
this simply gives us permission to use and redistribute your contributions as
part of the project. Head over to <https://cla.developers.google.com/> to see
your current agreements on file or to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Code reviews

All submissions, including submissions by project members, require review. We
use GitHub pull requests for this purpose. Consult
[GitHub Help](https://help.github.com/articles/about-pull-requests/) for more
information on using pull requests.

## Release process

Because this package's version remains in lockstep with the current version of
Dart Sass, it's not released manually from this repository. Instead, a release
commit is automatically generated once a new Dart Sass version has been
released. As such, manual commits should never:

* Update the `pubspec.yaml`'s version to a non-`-dev` number. Changing it from
  non-`-dev` to dev when adding a new feature is fine.

* Update the `pubspec.yaml`'s dependency on `sass` to a non-Git dependency.
  Changing it from non-Git to Git when using a new feature is fine.
