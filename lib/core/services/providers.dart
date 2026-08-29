import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../ai/memory/memory_manager.dart';
import '../../ai/runtime/llm_service.dart';
import '../../ai/runtime/model_downloader.dart';
import '../../ai/runtime/model_setup_controller.dart';
import '../../ai/runtime/model_setup_state.dart';
import '../../core/models/conversation.dart';
import '../../core/models/memory_fact.dart';
import '../../database/conversation_dao.dart';
import '../../database/memory_dao.dart';
import '../../database/message_dao.dart';
import '../../features/chat/controller/chat_controller.dart';
import '../../features/chat/controller/chat_state.dart';
import '../../features/chat/repository/chat_repository.dart';
import '../../features/history/controller/history_controller.dart';
import '../../features/memory/controller/memory_controller.dart';
import '../../features/profile/controller/user_profile.dart';
import '../../features/profile/controller/user_profile_controller.dart';
import '../../features/settings/controller/app_settings.dart';
import '../../features/settings/controller/settings_controller.dart';

/// Overridden in `main()` after one-time initialization.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden in main()'),
);

/// Overridden in `main()` after one-time initialization.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main()'),
);

final conversationDaoProvider = Provider<ConversationDao>(
  (ref) => ConversationDao(ref.watch(databaseProvider)),
);

final messageDaoProvider = Provider<MessageDao>(
  (ref) => MessageDao(ref.watch(databaseProvider)),
);

final memoryDaoProvider = Provider<MemoryDao>(
  (ref) => MemoryDao(ref.watch(databaseProvider)),
);

final llmServiceProvider = Provider<LlmService>((ref) => LlmService());

final memoryManagerProvider = Provider<MemoryManager>(
  (ref) => MemoryManager(ref.watch(memoryDaoProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(
    conversationDao: ref.watch(conversationDaoProvider),
    messageDao: ref.watch(messageDaoProvider),
    memoryDao: ref.watch(memoryDaoProvider),
    llm: ref.watch(llmServiceProvider),
    memoryManager: ref.watch(memoryManagerProvider),
  ),
);

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);

final historyControllerProvider =
    NotifierProvider<HistoryController, List<Conversation>>(HistoryController.new);

final memoryControllerProvider =
    NotifierProvider<MemoryController, List<MemoryFact>>(MemoryController.new);

final userProfileControllerProvider =
    NotifierProvider<UserProfileController, UserProfile>(
        UserProfileController.new);

final modelDownloaderProvider = Provider<ModelDownloader>(
  (ref) => ModelDownloader(),
);

/// Prepares the AI in the background (download when missing, then load).
/// Kick off from the home shell via `startInBackground()`; the chat awaits
/// `waitForReady()` before generating.
final modelSetupProvider =
    NotifierProvider<ModelSetupController, ModelSetupState>(
        ModelSetupController.new);
