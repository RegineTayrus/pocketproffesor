import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/conversation.dart';
import '../../../core/services/providers.dart';
import '../../../core/theme/widgets/glass_app_bar.dart';
import '../../../core/theme/widgets/glass_container.dart';

/// Lists past conversations and opens or deletes them.
class HistoryScreen extends ConsumerWidget {
  final void Function(int conversationId) onOpenConversation;

  const HistoryScreen({super.key, required this.onOpenConversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(historyControllerProvider);
    final controller = ref.read(historyControllerProvider.notifier);

    return Scaffold(
      // Transparent so the aurora backdrop from HomeScreen shows through.
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'History',
        actions: [
          if (conversations.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear history'),
                    content: const Text(
                        'All conversations will be permanently deleted.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await controller.deleteAll();
                }
              },
            ),
        ],
      ),
      body: conversations.isEmpty
          ? Center(
              child: GlassContainer(
                fillOpacity: 0.08,
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.all(24),
                child: const Text('No conversations yet.'),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                GlassAppBar.contentTopInset(context) + 8,
                16,
                GlassAppBar.bottomNavReserve(context) + 8,
              ),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ConversationTile(
                    conversation: conversation,
                    onTap: () => _openConversation(context, ref, conversation),
                    onDelete:
                        () => controller.deleteConversation(conversation.id!),
                  ),
                );
              },
            ),
    );
  }

  void _openConversation(
      BuildContext context, WidgetRef ref, Conversation conversation) {
    ref.read(historyControllerProvider.notifier).refresh();
    onOpenConversation(conversation.id!);
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassContainer(
      blurred: false,
      fillOpacity: 0.07,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Icon(
          Icons.chat_bubble_outline_rounded,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(_formatDate(conversation.createdAt)),
        onTap: onTap,
        trailing: IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: onDelete,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final local = date.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Today, ${_two(local.hour)}:${_two(local.minute)}';
    }
    return '${_two(local.day)}/${_two(local.month)}/${local.year}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
