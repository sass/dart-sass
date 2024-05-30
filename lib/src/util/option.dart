// Copyright 2024 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

/// A type that represents either the presence of a value of type `T` or its
/// absence.
///
/// When the option is present, this will be a single-element tuple that
/// contains the value. If it's absent, it will be null. This allows callers to
/// distinguish between a present null value and a value that's absent
/// altogether.
typedef Option<T> = (T,)?;
