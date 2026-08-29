import 'dart:async';

import 'package:pocket_professor/ai/runtime/model_setup_controller.dart';
import 'package:pocket_professor/ai/runtime/model_setup_state.dart';

/// Reports the model as ready so tests never touch downloads or the engine.
class ReadyModelSetup extends ModelSetupController {
  @override
  ModelSetupState build() =>
      const ModelSetupState(phase: ModelSetupPhase.ready);
}

/// Blocks [waitForReady] until [gate] is completed by the test.
class DeferredModelSetup extends ModelSetupController {
  final Completer<void> gate = Completer<void>();

  @override
  ModelSetupState build() =>
      const ModelSetupState(phase: ModelSetupPhase.preparing);

  @override
  Future<void> waitForReady() => gate.future;
}
