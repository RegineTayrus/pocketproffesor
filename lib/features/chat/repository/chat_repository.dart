import '../../../ai/memory/memory_manager.dart';
import '../../../ai/prompt/prompt_builder.dart';
import '../../../ai/runtime/llm_service.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/message.dart';
import '../../../database/conversation_dao.dart';
import '../../../database/memory_dao.dart';
import '../../../database/message_dao.dart';

/// Orchestrates persistence and generation for a chat conversation.
class ChatRepository {
  final ConversationDao conversationDao;
  final MessageDao messageDao;
  final MemoryDao memoryDao;
  final LlmService llm;
  final MemoryManager memoryManager;

  ChatRepository({
    required this.conversationDao,
    required this.messageDao,
    required this.memoryDao,
    required this.llm,
    required this.memoryManager,
  });

  Future<Conversation> createConversation({String? title}) {
    return conversationDao.insert(
      title: title ?? 'New conversation',
    );
  }

  Future<List<Message>> loadMessages(int conversationId) {
    return messageDao.getByConversation(conversationId);
  }

  Future<void> deleteConversation(int conversationId) async {
    await conversationDao.delete(conversationId);
  }

  Future<void> updateTitle(int conversationId, String title) async {
    await conversationDao.updateTitle(conversationId, title);
  }

  /// Builds the chat context (system prompt + recent history) and returns
  /// a token stream for the assistant's reply.
  ///
  /// The reply is persisted by [saveMessage] after the stream completes.
  Stream<String> generateReply({
    required List<Message> history,
    required String userText,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async* {
    final memoryFacts = await memoryManager.getAllFacts();
    final systemPrompt = PromptBuilder.buildSystemPrompt(memoryFacts: memoryFacts);

    final historyTuples = PromptBuilder.selectHistory(
      history.map((m) => (role: m.role, content: m.content)).toList(),
    );

    llm.startChat(systemPrompt: systemPrompt, history: historyTuples);

    await for (final token in llm.sendMessage(
      userText,
      maxTokens: maxTokens,
      temperature: temperature,
    )) {
      yield token;
    }
  }

  Future<Message> saveMessage({
    required int conversationId,
    required String role,
    required String content,
  }) {
    return messageDao.insert(
      conversationId: conversationId,
      role: role,
      content: content,
    );
  }

  /// Extracts and persists memory facts from a user message.
  Future<List<String>> extractMemory(String userText) {
    return memoryManager.extractAndSave(userText);
  }

  /// Derives a short title from the first user message.
  static String titleFrom(String text) {
    final trimmed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.length <= 40) return trimmed;
    return '${trimmed.substring(0, 40)}...';
  }
}
