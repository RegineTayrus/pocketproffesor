import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> setUpTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

Future<void> tearDownTestDatabase() async {
  await databaseFactory.deleteDatabase(inMemoryDatabasePath);
}
