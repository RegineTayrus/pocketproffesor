import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/memory_fact.dart';
import '../../../core/services/providers.dart';

/// Lists, adds, and removes stored memory facts.
class MemoryController extends Notifier<List<MemoryFact>> {
  @override
  List<MemoryFact> build() {
    _refresh();
    return const [];
  }

  Future<void> _refresh() async {
    try {
      final facts = await ref.read(memoryDaoProvider).getAll();
      state = facts;
    } catch (_) {
      state = const [];
    }
  }

  Future<void> refresh() => _refresh();

  Future<void> addFact(String fact) async {
    final trimmed = fact.trim();
    if (trimmed.isEmpty) return;
    await ref.read(memoryDaoProvider).insert(trimmed);
    await _refresh();
  }

  Future<void> deleteFact(int id) async {
    await ref.read(memoryDaoProvider).delete(id);
    await _refresh();
  }

  Future<void> deleteAll() async {
    await ref.read(memoryDaoProvider).deleteAll();
    await _refresh();
  }
}
