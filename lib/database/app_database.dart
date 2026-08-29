import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const int _version = 1;
  static const String _databaseName = 'pocket_professor.db';

  static Database? _instance;

  /// Override the database path (used by tests, e.g. [inMemoryDatabasePath]).
  static String databasePath = _databaseName;

  static Future<Database> get instance async {
    final existing = _instance;
    if (existing != null && existing.isOpen) {
      return existing;
    }
    final db = await openDatabase(
      databasePath,
      version: _version,
      onCreate: _onCreate,
    );
    _instance = db;
    return db;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        message TEXT NOT NULL,
        time INTEGER NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX idx_messages_conversation
      ON messages (conversation_id, time)
    ''');
    await db.execute('''
      CREATE TABLE memory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fact TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX idx_memory_fact_unique
      ON memory (fact)
    ''');
  }

  static Future<void> reset() async {
    final existing = _instance;
    _instance = null;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
  }
}
