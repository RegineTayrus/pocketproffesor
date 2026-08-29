import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pocket_professor/database/app_database.dart';
import 'package:pocket_professor/database/conversation_dao.dart';
import 'package:pocket_professor/database/message_dao.dart';

import 'helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MessageDao messageDao;
  late ConversationDao conversationDao;
  late int conversationId;

  setUpAll(() => setUpTestDatabase());

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    AppDatabase.databasePath = inMemoryDatabasePath;
    await AppDatabase.reset();
    messageDao = MessageDao(await AppDatabase.instance);
    conversationDao = ConversationDao(await AppDatabase.instance);
    conversationId = (await conversationDao.insert(title: 'Chat')).id!;
  });

  tearDown(() => tearDownTestDatabase());

  group('MessageDao', () {
    test('inserts and reads messages in order', () async {
      await messageDao.insert(
        conversationId: conversationId,
        role: 'user',
        content: 'Hello',
        time: DateTime(2026, 1, 1, 10, 0),
      );
      await messageDao.insert(
        conversationId: conversationId,
        role: 'assistant',
        content: 'Hi there',
        time: DateTime(2026, 1, 1, 10, 1),
      );

      final messages = await messageDao.getByConversation(conversationId);
      expect(messages.length, 2);
      expect(messages.first.role, 'user');
      expect(messages.first.content, 'Hello');
      expect(messages.last.role, 'assistant');
    });

    test('getLastByConversation returns the newest message', () async {
      await messageDao.insert(
        conversationId: conversationId,
        role: 'user',
        content: 'one',
        time: DateTime(2026, 1, 1, 9, 0),
      );
      await messageDao.insert(
        conversationId: conversationId,
        role: 'assistant',
        content: 'two',
        time: DateTime(2026, 1, 1, 9, 1),
      );

      final last = await messageDao.getLastByConversation(conversationId);
      expect(last!.content, 'two');
    });

    test('getLastNByConversation returns the last N in chronological order', () async {
      for (var i = 1; i <= 5; i++) {
        await messageDao.insert(
          conversationId: conversationId,
          role: i.isOdd ? 'user' : 'assistant',
          content: 'msg$i',
          time: DateTime(2026, 1, 1, 8, 0, i),
        );
      }

      final last3 = await messageDao.getLastNByConversation(conversationId, 3);
      expect(last3.length, 3);
      expect(last3.map((m) => m.content).toList(), ['msg3', 'msg4', 'msg5']);
    });

    test('messages are isolated per conversation', () async {
      final otherId = (await conversationDao.insert(title: 'Other')).id!;
      await messageDao.insert(
        conversationId: conversationId,
        role: 'user',
        content: 'in first',
      );
      await messageDao.insert(
        conversationId: otherId,
        role: 'user',
        content: 'in second',
      );

      final first = await messageDao.getByConversation(conversationId);
      final second = await messageDao.getByConversation(otherId);
      expect(first.single.content, 'in first');
      expect(second.single.content, 'in second');
    });
  });
}
