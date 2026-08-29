import 'dart:async';

import 'package:pocket_professor/ai/runtime/llm_service.dart';

/// Deterministic [LlmService] for tests and widget smoke tests.
class FakeLlmService extends LlmService {
  String? seenSystemPrompt;
  List<({String role, String content})>? seenHistory;
  List<String> replyTokens = ['Hello ', 'world!'];
  bool throwOnGenerate = false;

  @override
  void startChat({
    String? systemPrompt,
    List<({String role, String content})> history = const [],
  }) {
    seenSystemPrompt = systemPrompt;
    seenHistory = history;
  }

  @override
  Future<void> ensureLoaded({int contextSize = 2048}) async {}

  @override
  Stream<String> sendMessage(
    String content, {
    int maxTokens = 512,
    double temperature = 0.7,
  }) async* {
    if (throwOnGenerate) {
      throw Exception('boom');
    }
    for (final token in replyTokens) {
      yield token;
    }
  }
}
