import 'dart:async';
import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../../core/services/file_manager.dart';

/// Wraps [LlamaEngine] and exposes a simplified chat API for the app.
///
/// The engine runs inference on its own worker isolate, so streaming
/// tokens does not block the UI thread.
class LlmService {
  LlamaEngine? _engine;
  EngineChat? _chat;
  bool _loading = false;

  bool get isLoaded => _engine != null && _chat != null;
  bool get isLoading => _loading;

  /// Loads the app model from disk if it is not already loaded.
  Future<void> ensureLoaded({int contextSize = 2048}) async {
    if (isLoaded || isLoading) return;
    final file = await FileManager.modelFile();
    await load(modelPath: file.path, contextSize: contextSize);
  }

  /// Loads the GGUF model and prepares a fresh chat session.
  Future<void> load({
    required String modelPath,
    int contextSize = 2048,
  }) async {
    await dispose();
    _loading = true;
    try {
      final engine = await LlamaEngine.spawn(
        libraryPath: 'libllama.so',
        modelParams: ModelParams(path: modelPath, gpuLayers: 0),
        contextParams: ContextParams(
          nCtx: contextSize,
          nThreads: Platform.numberOfProcessors,
          nThreadsBatch: Platform.numberOfProcessors,
        ),
      );
      _engine = engine;
      _chat = await engine.createChat();
    } finally {
      _loading = false;
    }
  }

  /// Starts a fresh conversation. [systemPrompt] is applied as the
  /// system message; [history] is replayed in order (roles: user/assistant).
  void startChat({
    String? systemPrompt,
    List<({String role, String content})> history = const [],
  }) {
    final chat = _chat;
    if (chat == null) {
      throw StateError('Model is not loaded.');
    }
    chat.clearHistory();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      chat.addSystem(systemPrompt);
    }
    for (final message in history) {
      if (message.role == 'user') {
        chat.addUser(message.content);
      } else if (message.role == 'assistant') {
        chat.addAssistant(message.content);
      }
    }
  }

  /// Sends the user's message and streams the assistant's reply.
  ///
  /// The reply is appended to the chat's internal history on completion.
  Stream<String> sendMessage(
    String content, {
    int maxTokens = 512,
    double temperature = 0.7,
  }) async* {
    final chat = _chat;
    if (chat == null) {
      throw StateError('Model is not loaded.');
    }
    chat.addUser(content);
    await for (final event in chat.generate(
      maxTokens: maxTokens,
      sampler: SamplerParams(temperature: temperature),
    )) {
      if (event is TokenEvent && event.text.isNotEmpty) {
        yield event.text;
      }
    }
  }

  /// Messages currently in the chat session.
  List<ChatMessage> get messages => _chat?.messages ?? const [];

  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    _chat = null;
    if (engine != null) {
      try {
        await engine.dispose();
      } catch (_) {}
    }
  }
}
