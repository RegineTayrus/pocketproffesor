import 'package:sqflite/sqflite.dart';

import '../core/models/conversation.dart';

class ConversationDao {
  final Database _db;

  ConversationDao(this._db);

  Future<Conversation> insert({required String title, DateTime? createdAt}) async {
    final time = createdAt ?? DateTime.now();
    final map = Conversation(title: title, createdAt: time).toMap();
    final id = await _db.insert('conversations', map);
    return Conversation(id: id, title: title, createdAt: time);
  }

  Future<List<Conversation>> getAll() async {
    final rows = await _db.query(
      'conversations',
      orderBy: 'created_at DESC',
    );
    return rows.map(Conversation.fromMap).toList();
  }

  Future<Conversation?> getById(int id) async {
    final rows = await _db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Conversation.fromMap(rows.first);
  }

  Future<Conversation?> getByMessageId(int messageId) async {
    final rows = await _db.rawQuery('''
      SELECT c.* FROM conversations c
      JOIN messages m ON m.conversation_id = c.id
      WHERE m.id = ?
      LIMIT 1
    ''', [messageId]);
    if (rows.isEmpty) return null;
    return Conversation.fromMap(rows.first);
  }

  Future<void> updateTitle(int id, String title) async {
    await _db.update(
      'conversations',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    await _db.delete(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAll() async {
    await _db.delete('conversations');
  }
}
