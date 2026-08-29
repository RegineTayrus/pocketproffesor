import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pocket_professor/core/services/providers.dart';
import 'package:pocket_professor/features/chat/presentation/chat_screen.dart';
import 'package:pocket_professor/features/home/home_screen.dart';

import 'helpers/fake_llm_service.dart';
import 'helpers/fake_model_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late FakeLlmService fakeLlm;
  late List<Override> overrides;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('''
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
    ''');

    fakeLlm = FakeLlmService();
    overrides = [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      llmServiceProvider.overrideWithValue(fakeLlm),
      modelSetupProvider.overrideWith(ReadyModelSetup.new),
    ];
  });

  tearDown(() async {
    await db.close();
    await databaseFactory.deleteDatabase(inMemoryDatabasePath);
  });

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    );
  }

  testWidgets('home shows all tabs and switches between them',
      (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen()));
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Ask anything'), findsOneWidget);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No conversations yet.'), findsOneWidget);

    await tester.tap(find.text('Memory'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Facts you share'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Max tokens'), findsOneWidget);
    expect(find.text('Temperature'), findsOneWidget);

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.text('Ask anything'), findsOneWidget);

    // Let the sqflite worker isolate finish in-flight queries so their
    // timeout timers are cancelled before the test's timer check.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  });

  testWidgets('chat sends a message and streams the reply', (tester) async {
    await tester.pumpWidget(
      wrap(ChatScreen(initialConversationId: null, onStartNewChat: () {})),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'What is a computer?');

    // DB writes run through the sqflite worker isolate, which only makes
    // progress in the real event loop, so the send+wait runs in runAsync.
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      for (var i = 0; i < 300; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await tester.pump();
        if (find.text('Hello world!').evaluate().isNotEmpty) break;
      }
    });

    expect(find.text('What is a computer?'), findsOneWidget);
    expect(find.text('Hello world!'), findsOneWidget);
    expect(find.text('Thinking...'), findsNothing);
  });
}
