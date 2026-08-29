import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/providers.dart';
import '../../core/theme/widgets/aurora_background.dart';
import '../../core/theme/widgets/glass_container.dart';
import '../chat/presentation/chat_screen.dart';
import '../history/presentation/history_screen.dart';
import '../memory/presentation/memory_screen.dart';
import '../settings/presentation/settings_screen.dart';

/// Main shell: bottom navigation across Chat, History, Memory, and Settings.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  /// Conversation id pending to open in the chat tab (null = new chat).
  int? _pendingChatId;

  /// Incremented to force the chat screen to rebuild with a fresh session.
  int _chatEpoch = 0;

  @override
  void initState() {
    super.initState();
    // Prepare the AI in the background (download when missing, then load)
    // so early questions are answered as soon as it is ready.
    ref.read(modelSetupProvider.notifier).startInBackground();
  }

  void _openConversation(int conversationId) {
    setState(() {
      _pendingChatId = conversationId;
      _chatEpoch++;
      _index = 0;
    });
  }

  void _startNewChat() {
    setState(() {
      _pendingChatId = null;
      _chatEpoch++;
      _index = 0;
    });
  }

  void _onDestinationSelected(int index) {
    if (index == 1) {
      ref.read(historyControllerProvider.notifier).refresh();
    } else if (index == 2) {
      ref.read(memoryControllerProvider.notifier).refresh();
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    // Selected (not per-token) so the shell only rebuilds when streaming
    // starts or ends; the aurora drift yields the GPU while it does.
    final isGenerating = ref.watch(
      chatControllerProvider.select((state) => state.isGenerating),
    );

    return Scaffold(
      extendBody: true,
      body: AuroraBackground(
        paused: isGenerating,
        child: IndexedStack(
          index: _index,
          children: [
            ChatScreen(
              key: ValueKey('chat-$_pendingChatId-$_chatEpoch'),
              initialConversationId: _pendingChatId,
              onStartNewChat: _startNewChat,
            ),
            HistoryScreen(onOpenConversation: _openConversation),
            const MemoryScreen(),
            const SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GlassContainer(
            blur: 18,
            fillOpacity: 0.10,
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _onDestinationSelected,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  selectedIcon: Icon(Icons.chat_bubble_rounded),
                  label: 'Chat',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_rounded),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Icon(Icons.psychology_outlined),
                  selectedIcon: Icon(Icons.psychology_rounded),
                  label: 'Memory',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
