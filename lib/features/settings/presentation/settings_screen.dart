import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/providers.dart';
import '../../../core/theme/widgets/glass_app_bar.dart';
import '../../../core/theme/widgets/glass_container.dart';

/// Tuning controls for the local model's generation behavior.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final profile = ref.watch(userProfileControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      // Transparent so the aurora backdrop from HomeScreen shows through.
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'Settings',
        actions: [
          TextButton(
            onPressed: controller.resetToDefaults,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          GlassAppBar.contentTopInset(context) + 8,
          16,
          GlassAppBar.bottomNavReserve(context) + 16,
        ),
        children: [
          _SliderSetting(
            title: 'Max tokens',
            subtitle: 'How long an answer can be.',
            value: settings.maxTokens.toDouble(),
            min: 64,
            max: 1024,
            divisions: 15,
            display: '${settings.maxTokens}',
            onChanged: (value) => controller.setMaxTokens(value.round()),
          ),
          _SliderSetting(
            title: 'Temperature',
            subtitle: 'Higher = more creative, lower = more focused.',
            value: settings.temperature,
            min: 0.0,
            max: 1.5,
            divisions: 30,
            display: settings.temperature.toStringAsFixed(2),
            onChanged: (value) => controller.setTemperature(value),
          ),
          _SliderSetting(
            title: 'Context size',
            subtitle: 'Chat memory window (needs more RAM when higher).',
            value: settings.contextSize.toDouble(),
            min: 512,
            max: 8192,
            divisions: 15,
            display: '${settings.contextSize}',
            onChanged: (value) => controller.setContextSize(value.round()),
          ),
          const SizedBox(height: 16),
          GlassContainer(
            blurred: false,
            fillOpacity: 0.07,
            borderRadius: BorderRadius.circular(20),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              leading: Icon(
                Icons.person_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Display name'),
              subtitle: Text(profile.name ?? 'Not set'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _showEditNameDialog(context, ref),
            ),
          ),
          const SizedBox(height: 16),
          GlassContainer(
            blurred: false,
            fillOpacity: 0.07,
            borderRadius: BorderRadius.circular(20),
            child: SwitchListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Reduce transparency'),
              subtitle: const Text(
                'Solid panels instead of frosted glass. Easier to read and '
                'saves battery.',
              ),
              value: settings.reduceTransparency,
              onChanged: controller.setReduceTransparency,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Slider changes apply to the next message. The model runs '
            'entirely on your device - nothing is uploaded.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog(
      BuildContext context, WidgetRef ref) async {
    final current = ref.read(userProfileControllerProvider).name;
    final textController = TextEditingController(text: current);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: textController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 30,
          decoration: const InputDecoration(
            hintText: 'e.g. Alex',
            counterText: '',
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
    if (saved == true && context.mounted) {
      await ref
          .read(userProfileControllerProvider.notifier)
          .setName(textController.text);
    }
    textController.dispose();
  }
}

class _SliderSetting extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        blurred: false,
        fillOpacity: 0.07,
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(display, style: theme.textTheme.titleMedium),
              ],
            ),
            Text(subtitle, style: theme.textTheme.bodySmall),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
