import 'package:sqflite/sqflite.dart';

import '../core/models/memory_fact.dart';

class MemoryDao {
  final Database _db;

  MemoryDao(this._db);

  Future<int> insert(String fact, {DateTime? createdAt}) async {
    final map = MemoryFact(
      fact: fact,
      createdAt: createdAt ?? DateTime.now(),
    ).toMap();
    return _db.insert(
      'memory',
      map,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<MemoryFact>> getAll() async {
    final rows = await _db.query(
      'memory',
      orderBy: 'created_at DESC',
    );
    return rows.map(MemoryFact.fromMap).toList();
  }

  Future<bool> exists(String fact) async {
    final rows = await _db.query(
      'memory',
      where: 'fact = ?',
      whereArgs: [fact],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> delete(int id) async {
    await _db.delete(
      'memory',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteAll() async {
    await _db.delete('memory');
  }
}
