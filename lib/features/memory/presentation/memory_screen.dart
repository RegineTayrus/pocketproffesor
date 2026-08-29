import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../../core/theme/widgets/glass_app_bar.dart';
import '../../../core/theme/widgets/glass_container.dart';

/// Shows facts the professor remembers about the user, with add/delete.
class MemoryScreen extends ConsumerWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(memoryControllerProvider);
    final controller = ref.read(memoryControllerProvider.notifier);

    return Scaffold(
      // Transparent so the aurora backdrop from HomeScreen shows through.
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'Memory',
        actions: [
          if (facts.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear memory'),
                    content: const Text(
                        'All remembered facts will be permanently deleted.'),
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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add fact',
        onPressed: () => _showAddDialog(context, controller.addFact),
        child: const Icon(Icons.add_rounded),
      ),
      body: facts.isEmpty
          ? Center(
              child: GlassContainer(
                fillOpacity: 0.08,
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.all(24),
                child: const Text(
                  'Facts you share (e.g. "I am a medical student") are '
                  'remembered here and used to personalize answers.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(
                16,
                GlassAppBar.contentTopInset(context) + 8,
                16,
                GlassAppBar.bottomNavReserve(context) + 88,
              ),
              itemCount: facts.length,
              itemBuilder: (context, index) {
                final fact = facts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassContainer(
                    blurred: false,
                    fillOpacity: 0.07,
                    borderRadius: BorderRadius.circular(18),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      leading: Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(fact.fact),
                      subtitle: Text(_formatDate(fact.createdAt)),
                      trailing: IconButton(
                        tooltip: 'Forget',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => controller.deleteFact(fact.id!),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showAddDialog(
      BuildContext context, Future<void> Function(String) onAdd) async {
    final textController = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a fact'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. I am a medical student',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (added == true) {
      await onAdd(textController.text);
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Today, ${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}
