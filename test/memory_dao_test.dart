import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:pocket_professor/database/app_database.dart';
import 'package:pocket_professor/database/memory_dao.dart';

import 'helpers/database_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryDao dao;

  setUpAll(() => setUpTestDatabase());

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    AppDatabase.databasePath = inMemoryDatabasePath;
    await AppDatabase.reset();
    dao = MemoryDao(await AppDatabase.instance);
  });

  tearDown(() => tearDownTestDatabase());

  group('MemoryDao', () {
    test('inserts and reads a fact', () async {
      final id = await dao.insert('The user studies Computer Science.');

      final all = await dao.getAll();
      expect(all.length, 1);
      expect(all.first.id, id);
      expect(all.first.fact, 'The user studies Computer Science.');
    });

    test('deduplicates identical facts', () async {
      await dao.insert('The user prefers simple explanations.');
      final duplicateId = await dao.insert('The user prefers simple explanations.');

      final all = await dao.getAll();
      expect(all.length, 1);
      expect(duplicateId, isZero);
    });

    test('exists returns true only for stored facts', () async {
      await dao.insert('The user likes Flutter.');
      expect(await dao.exists('The user likes Flutter.'), isTrue);
      expect(await dao.exists('The user likes Swift.'), isFalse);
    });

    test('deletes a fact', () async {
      final id = await dao.insert('Temporary fact');
      await dao.delete(id);

      expect(await dao.getAll(), isEmpty);
    });

    test('lists facts newest first', () async {
      await dao.insert('Old fact', createdAt: DateTime(2026, 1, 1));
      await dao.insert('New fact', createdAt: DateTime(2026, 6, 1));

      final all = await dao.getAll();
      expect(all.first.fact, 'New fact');
    });
  });
}
