/// Builds the system prompt and conversation context sent to the model.
class PromptBuilder {
  PromptBuilder._();

  /// Builds the system prompt for a chat session.
  ///
  /// [memoryFacts] are injected when available so the model knows about the
  /// user's background and preferences.
  static String buildSystemPrompt({List<String> memoryFacts = const []}) {
    final buffer = StringBuffer()
      ..writeln('You are Pocket Professor, a helpful offline AI tutor.')
      ..writeln('Answer clearly.')
      ..writeln('Use simple English.')
      ..writeln('Keep answers short and to the point: a few sentences unless')
      ..writeln('the topic needs more detail.')
      ..writeln('Use code blocks when explaining code.')
      ..writeln('If you do not know something, say so honestly.');

    if (memoryFacts.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('About the user:');
      for (final fact in memoryFacts) {
        buffer.writeln('- $fact');
      }
    }

    return buffer.toString();
  }

  /// Selects the messages to send to the model from the full history.
  ///
  /// Keeps the most recent [maxMessages] messages to stay within the
  /// model's context window. Older messages are dropped.
  static List<({String role, String content})> selectHistory(
    List<({String role, String content})> history, {
    int maxMessages = 20,
  }) {
    if (history.length <= maxMessages) {
      return history;
    }
    return history.sublist(history.length - maxMessages);
  }
}
