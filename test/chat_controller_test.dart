import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pocket_professor/core/services/providers.dart';
import 'package:pocket_professor/features/chat/controller/chat_controller.dart';
import 'package:pocket_professor/features/settings/controller/app_settings.dart';

import 'helpers/fake_llm_service.dart';
import 'helpers/fake_model_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeLlmService fakeLlm;
  late ChatController controller;
  late SharedPreferences prefs;
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    final schema = '''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        message TEXT NOT NULL,
        time INTEGER NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
      );
      CREATE TABLE memory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fact TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
      CREATE UNIQUE INDEX idx_memory_fact_unique ON memory (fact);
    ''';
    await db.execute(schema);

    fakeLlm = FakeLlmService();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        llmServiceProvider.overrideWithValue(fakeLlm),
        modelSetupProvider.overrideWith(ReadyModelSetup.new),
      ],
    );
    addTearDown(container.dispose);
    controller = container.read(chatControllerProvider.notifier);
  });

  tearDown(() async {
    await db.close();
    await databaseFactory.deleteDatabase(inMemoryDatabasePath);
  });

  Future<void> waitForIdle() async {
    for (var i = 0; i < 200; i++) {
      if (!container.read(chatControllerProvider).isGenerating) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Timed out waiting for generation to finish.');
  }

  group('ChatController', () {
    test('sends a message and streams the reply into state', () async {
      await controller.sendMessage('What is a computer?');

      var state = container.read(chatControllerProvider);
      expect(state.conversationId, isNotNull);
      expect(state.messages.length, 1);
      expect(state.messages.last.role, 'user');
      expect(state.isGenerating, isTrue);

      await waitForIdle();
      state = container.read(chatControllerProvider);

      expect(state.isGenerating, isFalse);
      expect(state.streamingText, isEmpty);
      expect(state.messages.length, 2);
      expect(state.messages.last.role, 'assistant');
      expect(state.messages.last.content, 'Hello world!');
    });

    test('message sent before setup finishes waits for the model', () async {
      final deferred = DeferredModelSetup();
      final setupContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          llmServiceProvider.overrideWithValue(fakeLlm),
          modelSetupProvider.overrideWith(() => deferred),
        ],
      );
      addTearDown(setupContainer.dispose);

      final chatController = setupContainer.read(chatControllerProvider.notifier);
      final sending = chatController.sendMessage('What is a computer?');

      // Give the send time to persist the user message and hit the gate.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      var state = setupContainer.read(chatControllerProvider);
      expect(state.messages.length, 1);
      expect(state.messages.last.role, 'user');
      expect(state.isGenerating, isTrue);

      deferred.gate.complete();
      await sending;
      for (var i = 0; i < 200; i++) {
        if (!setupContainer.read(chatControllerProvider).isGenerating) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      state = setupContainer.read(chatControllerProvider);
      expect(state.isGenerating, isFalse);
      expect(state.messages.length, 2);
      expect(state.messages.last.role, 'assistant');
      expect(state.messages.last.content, 'Hello world!');
    });

    test('persists user and assistant messages', () async {
      await controller.sendMessage('Hello');
      await waitForIdle();

      final dao = container.read(messageDaoProvider);
      final conversationId = container.read(chatControllerProvider).conversationId!;
      final messages = await dao.getByConversation(conversationId);

      expect(messages.length, 2);
      expect(messages[0].role, 'user');
      expect(messages[0].content, 'Hello');
      expect(messages[1].role, 'assistant');
      expect(messages[1].content, 'Hello world!');
    });

    test('derives conversation title from first message', () async {
      await controller.sendMessage('Explain the water cycle please');
      await waitForIdle();

      final dao = container.read(conversationDaoProvider);
      final conversations = await dao.getAll();
      expect(conversations.single.title, 'Explain the water cycle please');
    });

    test('seeds the chat with history and memory facts', () async {
      await container.read(memoryDaoProvider).insert('The user is learning Flutter.');
      await controller.sendMessage('Explain StatefulWidget');
      await waitForIdle();

      expect(fakeLlm.seenSystemPrompt, contains('The user is learning Flutter.'));
      expect(fakeLlm.seenHistory, isNotNull);
    });

    test('extracts memory facts from user messages', () async {
      await controller.sendMessage("I'm learning Dart.");
      await waitForIdle();

      final facts = await container.read(memoryDaoProvider).getAll();
      expect(facts.single.fact, 'The user is learning Dart.');
    });

    test('second message is appended to the same conversation', () async {
      fakeLlm.replyTokens = ['first'];
      await controller.sendMessage('Message one');
      await waitForIdle();

      fakeLlm.replyTokens = ['second'];
      await controller.sendMessage('Message two');
      await waitForIdle();

      final state = container.read(chatControllerProvider);
      expect(state.messages.length, 4);
      expect(state.messages.map((m) => m.content).toList(),
          ['Message one', 'first', 'Message two', 'second']);
    });

    test('reports errors during generation', () async {
      fakeLlm.throwOnGenerate = true;
      await controller.sendMessage('Will fail');
      await waitForIdle();

      final state = container.read(chatControllerProvider);
      expect(state.isGenerating, isFalse);
      expect(state.error, isNotNull);
    });

    test('loads an existing conversation', () async {
      final conversation =
          await container.read(conversationDaoProvider).insert(title: 'Old chat');
      final dao = container.read(messageDaoProvider);
      await dao.insert(conversationId: conversation.id!, role: 'user', content: 'Hi');

      await controller.loadConversation(conversation.id!);

      final state = container.read(chatControllerProvider);
      expect(state.conversationId, conversation.id);
      expect(state.isLoaded, isTrue);
      expect(state.messages.single.content, 'Hi');
    });

    test('deleteCurrentConversation removes it from the database', () async {
      await controller.sendMessage('Temporary');
      await waitForIdle();

      await controller.deleteCurrentConversation();

      final conversations =
          await container.read(conversationDaoProvider).getAll();
      expect(conversations, isEmpty);
      final state = container.read(chatControllerProvider);
      expect(state.conversationId, isNull);
    });
  });

  group('SettingsController', () {
    test('persists settings changes', () async {
      final settingsController =
          container.read(settingsControllerProvider.notifier);
      await settingsController.setMaxTokens(256);
      await settingsController.setTemperature(0.9);
      await settingsController.setReduceTransparency(true);

      final settings = container.read(settingsControllerProvider);
      expect(settings.maxTokens, 256);
      expect(settings.temperature, 0.9);
      expect(settings.contextSize, AppSettings.defaults.contextSize);
      expect(settings.reduceTransparency, true);
    });

    test('resetToDefaults restores reduceTransparency', () async {
      final settingsController =
          container.read(settingsControllerProvider.notifier);
      await settingsController.setReduceTransparency(true);

      await settingsController.resetToDefaults();

      expect(
        container.read(settingsControllerProvider).reduceTransparency,
        AppSettings.defaults.reduceTransparency,
      );
    });
  });

  group('UserProfileController', () {
    test('persists a trimmed display name', () async {
      final profileController =
          container.read(userProfileControllerProvider.notifier);

      await profileController.setName('  Alex  ');

      expect(container.read(userProfileControllerProvider).name, 'Alex');
    });

    test('ignores empty names', () async {
      final profileController =
          container.read(userProfileControllerProvider.notifier);

      await profileController.setName('   ');

      expect(container.read(userProfileControllerProvider).hasName, isFalse);
    });

    test('loads a previously stored name', () async {
      final prefs = container.read(sharedPreferencesProvider);
      await prefs.setString('profile.name', 'Sam');

      expect(container.read(userProfileControllerProvider).name, 'Sam');
    });
  });
}
