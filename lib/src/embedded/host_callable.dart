// Copyright 2019 Google Inc. Use of this source code is governed by an
// MIT-style license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

import '../callable.dart';
import '../exception.dart';
import '../value/function.dart';
import '../value/mixin.dart';
import 'compilation_dispatcher.dart';
import 'embedded_sass.pb.dart';
import 'opaque_registry.dart';
import 'protofier.dart';
import 'utils.dart';

/// Returns a Sass callable that invokes a function defined on the host with the
/// given [signature].
///
/// If [id] is passed, the function will be called by ID (which is necessary for
/// anonymous functions defined on the host). Otherwise, it will be called using
/// the name defined in the [signature].
///
/// Throws a [SassException] if [signature] is invalid.
Callable hostCallable(
  CompilationDispatcher dispatcher,
  OpaqueRegistry<SassFunction> functions,
  OpaqueRegistry<SassMixin> mixins,
  String signature, {
  int? id,
}) {
  late Callable callable;
  callable = Callable.fromSignature(signature, (arguments) {
    var protofier = Protofier(dispatcher, functions, mixins);
    var request = OutboundMessage_FunctionCallRequest()
      ..arguments.addAll([
        for (var argument in arguments) protofier.protofy(argument),
      ]);

    if (id != null) {
      request.functionId = id;
    } else {
      request.name = callable.name;
    }

    var response = dispatcher.sendFunctionCallRequest(request);
    try {
      switch (response.whichResult()) {
        case InboundMessage_FunctionCallResponse_Result.success:
          return protofier.deprotofyResponse(response);

        case InboundMessage_FunctionCallResponse_Result.error:
          throw response.error;

        case InboundMessage_FunctionCallResponse_Result.notSet:
          throw mandatoryError('FunctionCallResponse.result');
      }
    } on ProtocolError catch (error, stackTrace) {
      dispatcher.sendError(handleError(error, stackTrace));
    }
  });
  return callable;
}
