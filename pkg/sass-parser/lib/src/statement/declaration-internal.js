// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

const postcss = require('postcss');

exports._Declaration = postcss.Declaration;

// Inject PostCSS's container implementation into a declaration subclass so we
// can define declarations that have child nodes.
class _DeclarationWithChildren extends postcss.Declaration {}
const containerProperties = Object.getOwnPropertyDescriptors(postcss.Container.prototype);
Object.defineProperties(_DeclarationWithChildren.prototype, containerProperties);

exports._DeclarationWithChildren = _DeclarationWithChildren;
