import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pocket_professor/database/app_database.dart';
import 'package:pocket_professor/database/conversation_dao.dart';

import 'helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ConversationDao dao;

  setUpAll(() => setUpTestDatabase());

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    AppDatabase.databasePath = inMemoryDatabasePath;
    await AppDatabase.reset();
    dao = ConversationDao(await AppDatabase.instance);
  });

  tearDown(() => tearDownTestDatabase());

  group('ConversationDao', () {
    test('inserts and reads back a conversation', () async {
      final conversation = await dao.insert(title: 'What is AI?');

      expect(conversation.id, isNotNull);
      final loaded = await dao.getById(conversation.id!);
      expect(loaded, isNotNull);
      expect(loaded!.title, 'What is AI?');
      expect(loaded.createdAt.isBefore(DateTime.now()), isTrue);
    });

    test('lists conversations newest first', () async {
      await dao.insert(title: 'First');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await dao.insert(title: 'Second');

      final all = await dao.getAll();
      expect(all.length, 2);
      expect(all.first.title, 'Second');
      expect(all.last.title, 'First');
    });

    test('updates conversation title', () async {
      final conversation = await dao.insert(title: 'Old title');
      await dao.updateTitle(conversation.id!, 'New title');

      final loaded = await dao.getById(conversation.id!);
      expect(loaded!.title, 'New title');
    });

    test('deletes a conversation', () async {
      final conversation = await dao.insert(title: 'To delete');
      await dao.delete(conversation.id!);

      expect(await dao.getById(conversation.id!), isNull);
    });

    test('getByMessageId resolves the owning conversation', () async {
      final conversation = await dao.insert(title: 'Owner');
      final db = await AppDatabase.instance;
      final messageId = await db.insert('messages', {
        'conversation_id': conversation.id,
        'role': 'user',
        'message': 'hello',
        'time': DateTime.now().millisecondsSinceEpoch,
      });

      final owner = await dao.getByMessageId(messageId);
      expect(owner!.id, conversation.id);
    });
  });
}
