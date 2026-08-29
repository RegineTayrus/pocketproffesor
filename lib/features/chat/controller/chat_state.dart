/// A chat message shown in the UI.
class ChatUiMessage {
  final int? dbId;
  final String role;
  final String content;

  const ChatUiMessage({
    this.dbId,
    required this.role,
    required this.content,
  });

  ChatUiMessage copyWith({int? dbId, String? content}) {
    return ChatUiMessage(
      dbId: dbId ?? this.dbId,
      role: role,
      content: content ?? this.content,
    );
  }
}

class ChatState {
  final int? conversationId;
  final List<ChatUiMessage> messages;
  final bool isGenerating;
  final String streamingText;
  final String? error;
  final bool isLoaded;

  const ChatState({
    this.conversationId,
    this.messages = const [],
    this.isGenerating = false,
    this.streamingText = '',
    this.error,
    this.isLoaded = false,
  });

  ChatState copyWith({
    int? conversationId,
    List<ChatUiMessage>? messages,
    bool? isGenerating,
    String? streamingText,
    String? error,
    bool? isLoaded,
    bool clearError = false,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      streamingText: streamingText ?? this.streamingText,
      error: clearError ? null : (error ?? this.error),
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}
