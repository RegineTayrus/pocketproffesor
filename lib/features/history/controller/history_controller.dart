import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/conversation.dart';
import '../../../core/services/providers.dart';

/// Lists, opens, and deletes past conversations.
class HistoryController extends Notifier<List<Conversation>> {
  @override
  List<Conversation> build() {
    _refresh();
    return const [];
  }

  Future<void> _refresh() async {
    try {
      final conversations = await ref
          .read(conversationDaoProvider)
          .getAll();
      state = conversations;
    } catch (_) {
      state = const [];
    }
  }

  Future<void> refresh() => _refresh();

  Future<void> deleteConversation(int id) async {
    await ref.read(conversationDaoProvider).delete(id);
    await _refresh();
  }

  Future<void> deleteAll() async {
    await ref.read(conversationDaoProvider).deleteAll();
    await _refresh();
  }

  Future<void> renameConversation(int id, String title) async {
    await ref.read(conversationDaoProvider).updateTitle(id, title);
    await _refresh();
  }
}
