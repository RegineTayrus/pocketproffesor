import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/runtime/model_setup_state.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/providers.dart';
import '../../../core/theme/widgets/glass_app_bar.dart';
import '../../../core/theme/widgets/glass_container.dart';
import '../controller/chat_state.dart';

/// The main chat conversation screen.
class ChatScreen extends ConsumerStatefulWidget {
  final int? initialConversationId;
  final VoidCallback onStartNewChat;

  const ChatScreen({
    super.key,
    this.initialConversationId,
    required this.onStartNewChat,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadedOnce = widget.initialConversationId == null;
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _input.clear();
    unawaited(ref.read(chatControllerProvider.notifier).sendMessage(trimmed));
  }

  Future<void> _confirmDeleteConversation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation'),
        content: const Text('This conversation will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(chatControllerProvider.notifier).deleteCurrentConversation();
      widget.onStartNewChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(chatControllerProvider.notifier);
    final state = ref.watch(chatControllerProvider);
    final profile = ref.watch(userProfileControllerProvider);

    if (!_loadedOnce && widget.initialConversationId != null) {
      _loadedOnce = true;
      unawaited(controller.loadConversation(widget.initialConversationId!));
    }

    return Scaffold(
      // Transparent so the aurora backdrop from HomeScreen shows through.
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: profile.hasName ? 'Hi, ${profile.name}' : AppConstants.appName,
        actions: [
          IconButton(
            tooltip: 'New conversation',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () {
              controller.startNewConversation();
              widget.onStartNewChat();
            },
          ),
          if (state.conversationId != null)
            IconButton(
              tooltip: 'Delete conversation',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _confirmDeleteConversation,
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(top: GlassAppBar.contentTopInset(context)),
        child: Column(
          children: [
            if (state.error != null)
              MaterialBanner(
                content: Text(state.error!),
                actions: [
                  TextButton(
                    onPressed: controller.dismissError,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            const _ModelStatusBar(),
            Expanded(
              child: _MessageList(
                state: state,
                scrollController: _scroll,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                bottom: GlassAppBar.bottomNavReserve(context),
              ),
              child: _InputBar(
                controller: _input,
                scrollController: _scroll,
                isGenerating: state.isGenerating,
                onSend: _send,
                onStop: () => unawaited(controller.stopGeneration()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  final ChatState state;
  final ScrollController scrollController;

  const _MessageList({required this.state, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    if (state.messages.isEmpty && state.streamingText.isEmpty) {
      return _Welcome(onSend: (text) => _sendFromWelcome(context, text));
    }
    final itemCount = state.messages.length + (state.isGenerating ? 1 : 0);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      reverse: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final reversedIndex = itemCount - 1 - index;
        if (reversedIndex >= state.messages.length) {
          return _AssistantBubble(
            text: state.streamingText,
            isThinking: state.streamingText.isEmpty,
          );
        }
        final message = state.messages[reversedIndex];
        if (message.role == 'user') {
          return _UserBubble(text: message.content);
        }
        return _AssistantBubble(text: message.content);
      },
    );
  }

  void _sendFromWelcome(BuildContext context, String text) {
    final chatScreen = context.findAncestorStateOfType<_ChatScreenState>();
    chatScreen?._send(text);
  }
}

class _Welcome extends StatelessWidget {
  final void Function(String) onSend;

  const _Welcome({required this.onSend});

  static const _suggestions = [
    'Explain what a black hole is',
    'Help me solve a math problem',
    'Teach me about photosynthesis',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + GlassAppBar.bottomNavReserve(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_rounded, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Ask anything', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Your offline study buddy. Answers are generated on your device.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            for (final suggestion in _suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ActionChip(
                  label: Text(suggestion),
                  onPressed: () => onSend(suggestion),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Slim status line for the background AI preparation: download progress,
/// engine warm-up, or a retry card after a failure. Hidden once ready.
class _ModelStatusBar extends ConsumerWidget {
  const _ModelStatusBar();

  static String _formatMb(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(modelSetupProvider);
    final theme = Theme.of(context);

    switch (setup.phase) {
      case ModelSetupPhase.downloading:
        final total =
            setup.totalBytes > 0 ? setup.totalBytes : AppConstants.modelSizeBytes;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GlassContainer(
            blurred: false,
            fillOpacity: 0.07,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Downloading your tutor\u2026',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:
                              (setup.receivedBytes / total).clamp(0.0, 1.0),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_formatMb(setup.receivedBytes)} / ${_formatMb(total)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      case ModelSetupPhase.preparing:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GlassContainer(
            blurred: false,
            fillOpacity: 0.07,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text('Preparing model\u2026', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );
      case ModelSetupPhase.failed:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GlassContainer(
            blurred: false,
            fillOpacity: 0.07,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Couldn\u2019t finish setting up your tutor.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(modelSetupProvider.notifier)
                      .retry(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      case ModelSetupPhase.idle:
      case ModelSetupPhase.ready:
        return const SizedBox.shrink();
    }
  }
}

class _UserBubble extends StatelessWidget {
  final String text;

  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 48),
        child: GlassContainer(
          blurred: false,
          tint: theme.colorScheme.primary,
          fillOpacity: 0.28,
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SelectableText(text),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final String text;
  final bool isThinking;

  const _AssistantBubble({required this.text, this.isThinking = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8, right: 48),
        child: GlassContainer(
          blurred: false,
          fillOpacity: 0.09,
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: isThinking
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text('Thinking...', style: theme.textTheme.bodyMedium),
                  ],
                )
              : SelectableText(text),
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final ScrollController scrollController;
  final bool isGenerating;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;

  const _InputBar({
    required this.controller,
    required this.scrollController,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: GlassContainer(
        blur: 16,
        fillOpacity: 0.10,
        borderRadius: BorderRadius.circular(28),
        padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (text) {
                  if (!widget.isGenerating) widget.onSend(text);
                },
                decoration: InputDecoration(
                  hintText: 'Ask something...',
                  filled: false,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: widget.isGenerating ? 'Stop' : 'Send',
              icon: Icon(
                widget.isGenerating ? Icons.stop_rounded : Icons.send_rounded,
              ),
              onPressed: widget.isGenerating
                  ? widget.onStop
                  : () => widget.onSend(widget.controller.text),
            ),
          ],
        ),
      ),
    );
  }
}
