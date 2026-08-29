import 'package:sqflite/sqflite.dart';

import '../core/models/message.dart';

class MessageDao {
  final Database _db;

  MessageDao(this._db);

  Future<Message> insert({
    required int conversationId,
    required String role,
    required String content,
    DateTime? time,
  }) async {
    final messageTime = time ?? DateTime.now();
    final map = Message(
      conversationId: conversationId,
      role: role,
      content: content,
      time: messageTime,
    ).toMap();
    final id = await _db.insert('messages', map);
    return Message(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content,
      time: messageTime,
    );
  }

  Future<List<Message>> getByConversation(int conversationId) async {
    final rows = await _db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'time ASC, id ASC',
    );
    return rows.map(Message.fromMap).toList();
  }

  Future<Message?> getLastByConversation(int conversationId) async {
    final rows = await _db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'time DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Message.fromMap(rows.first);
  }

  Future<List<Message>> getLastNByConversation(int conversationId, int limit) async {
    final rows = await _db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'time DESC, id DESC',
      limit: limit,
    );
    return rows.reversed.map(Message.fromMap).toList();
  }

  Future<void> deleteByConversation(int conversationId) async {
    await _db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> deleteAll() async {
    await _db.delete('messages');
  }
}
