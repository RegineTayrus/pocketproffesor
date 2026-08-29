import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../settings/controller/app_settings.dart';
import '../repository/chat_repository.dart';
import 'chat_state.dart';

/// Coordinates the chat UI with persistence and the AI runtime.
class ChatController extends Notifier<ChatState> {
  StreamSubscription<String>? _subscription;

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  AppSettings get _settings => ref.read(settingsControllerProvider);

  @override
  ChatState build() {
    return const ChatState();
  }

  /// Resets the UI to an empty, unsaved conversation.
  void startNewConversation() {
    _subscription?.cancel();
    state = const ChatState();
  }

  /// Loads an existing conversation's messages into the UI.
  Future<void> loadConversation(int conversationId) async {
    try {
      final messages = await _repository.loadMessages(conversationId);
      state = ChatState(
        conversationId: conversationId,
        isLoaded: true,
        messages: [
          for (final m in messages)
            ChatUiMessage(dbId: m.id, role: m.role, content: m.content),
        ],
      );
    } catch (e) {
      state = ChatState(error: '$e');
    }
  }

  /// Sends the user's message and streams the assistant's reply.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isGenerating) return;

    var conversationId = state.conversationId;
    if (conversationId == null) {
      final conversation = await _repository.createConversation(
        title: ChatRepository.titleFrom(trimmed),
      );
      conversationId = conversation.id;
      state = state.copyWith(conversationId: conversationId, isLoaded: true);
    }
    final activeConversationId = conversationId!;

    try {
      final savedUser = await _repository.saveMessage(
        conversationId: activeConversationId,
        role: 'user',
        content: trimmed,
      );

      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatUiMessage(dbId: savedUser.id, role: 'user', content: trimmed),
        ],
        isGenerating: true,
        streamingText: '',
        clearError: true,
      );

      unawaited(_repository.extractMemory(trimmed));

      // Waits for the background download + engine load when needed, so
      // messages sent early are answered as soon as the model is ready.
      await ref.read(modelSetupProvider.notifier).waitForReady();

      final history = await _repository.loadMessages(activeConversationId);
      final stream = _repository.generateReply(
        history: history,
        userText: trimmed,
        maxTokens: _settings.maxTokens,
        temperature: _settings.temperature,
      );

      final buffer = StringBuffer();
      _subscription = stream.listen(
        (token) {
          buffer.write(token);
          state = state.copyWith(streamingText: buffer.toString());
        },
        onError: (Object e) {
          state = state.copyWith(
            isGenerating: false,
            streamingText: '',
            error: '$e',
          );
        },
        onDone: () async {
          await _completeReply(activeConversationId, buffer.toString());
        },
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        streamingText: '',
        error: '$e',
      );
    }
  }

  Future<void> _completeReply(int conversationId, String reply) async {
    final saved = await _repository.saveMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: reply,
    );
    if (saved.id == null) {
      state = state.copyWith(
        isGenerating: false,
        streamingText: '',
        error: 'Failed to save reply.',
      );
      return;
    }
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatUiMessage(dbId: saved.id, role: 'assistant', content: reply),
      ],
      isGenerating: false,
      streamingText: '',
    );
  }

  /// Stops the in-flight generation. The partial reply is discarded.
  Future<void> stopGeneration() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    state = state.copyWith(isGenerating: false, streamingText: '');
  }

  Future<void> deleteCurrentConversation() async {
    final conversationId = state.conversationId;
    if (conversationId == null) return;
    await stopGeneration();
    await _repository.deleteConversation(conversationId);
    state = const ChatState();
  }

  /// Updates the conversation title (e.g. first message became the title).
  Future<void> updateTitle(String title) async {
    final conversationId = state.conversationId;
    if (conversationId == null) return;
    await _repository.updateTitle(conversationId, title);
  }

  /// Clears the error shown in the UI.
  void dismissError() {
    state = state.copyWith(clearError: true);
  }
}
