import 'dart:async';
import 'package:flutter/material.dart';
import 'package:countsend/theme/app_theme.dart';
import 'package:countsend/models/countdown_config.dart';
import 'package:countsend/services/countdown_engine.dart';
import 'package:countsend/services/config_storage.dart';

class TemplateEditorScreen extends StatefulWidget {
  final CountdownConfig initialConfig;

  const TemplateEditorScreen({super.key, required this.initialConfig});

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late TextEditingController _templateController;
  late TextEditingController _friendNameController;
  late TextEditingController _eventNameController;
  late TextEditingController _completeMsgController;

  Timer? _previewTimer;
  late CountdownConfig _workingConfig;

  final List<Map<String, String>> _presets = [
    {
      'title': 'Birthday',
      'friend': 'Riya',
      'event': 'Birthday',
      'template':
          'Hey {friend_name}! ⏳ {days}d {hours}h {minutes}m {seconds}s left for your {event_name}! 🎂',
      'complete': '🎉 HAPPY BIRTHDAY {friend_name}! 🥳 Let\'s celebrate! 🎂🎈',
    },
    {
      'title': 'New Year',
      'friend': 'Everyone',
      'event': 'New Year',
      'template':
          '⏳ Only {days}d {hours}h {minutes}m {seconds}s until {event_name}! 🎆🥂',
      'complete': '✨ HAPPY NEW YEAR! 🥂 May this year bring endless joy! 🎆🎉',
    },
    {
      'title': 'Anniversary',
      'friend': 'Love',
      'event': 'Anniversary',
      'template':
          '{days}d {hours}h {minutes}m {seconds}s until our {event_name}! 💖',
      'complete': '💍 Happy Anniversary my love! ❤️ Forever and always!',
    },
    {
      'title': 'Launch / Exam',
      'friend': 'Team',
      'event': 'Launch Day',
      'template':
          'T-minus {days}d {hours}h {minutes}m {seconds}s until {event_name}! 🚀',
      'complete': '🚀 WE ARE LIVE! Mission accomplished! 🏆✨',
    },
  ];

  @override
  void initState() {
    super.initState();
    _workingConfig = widget.initialConfig;
    _templateController = TextEditingController(text: _workingConfig.template);
    _friendNameController = TextEditingController(
      text: _workingConfig.friendName,
    );
    _eventNameController = TextEditingController(
      text: _workingConfig.eventName,
    );
    _completeMsgController = TextEditingController(
      text: _workingConfig.completeMessage,
    );

    _previewTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _templateController.dispose();
    _friendNameController.dispose();
    _eventNameController.dispose();
    _completeMsgController.dispose();
    super.dispose();
  }

  void _updateConfig() {
    setState(() {
      _workingConfig = _workingConfig.copyWith(
        template: _templateController.text,
        friendName: _friendNameController.text.trim(),
        eventName: _eventNameController.text.trim(),
        completeMessage: _completeMsgController.text,
      );
    });
  }

  void _insertPlaceholder(String placeholder) {
    final text = _templateController.text;
    final selection = _templateController.selection;
    final newText = text.replaceRange(
      selection.start >= 0 ? selection.start : text.length,
      selection.end >= 0 ? selection.end : text.length,
      placeholder,
    );
    _templateController.text = newText;
    _templateController.selection = TextSelection.collapsed(
      offset:
          (selection.start >= 0 ? selection.start : text.length) +
          placeholder.length,
    );
    _updateConfig();
  }

  void _applyPreset(Map<String, String> preset) {
    setState(() {
      _friendNameController.text = preset['friend']!;
      _eventNameController.text = preset['event']!;
      _templateController.text = preset['template']!;
      _completeMsgController.text = preset['complete']!;
      _updateConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final renderedPreview = CountdownEngine.renderMessage(_workingConfig);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Template'),
        actions: [
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              _updateConfig();
              await ConfigStorage.saveConfig(_workingConfig);
              if (mounted) {
                nav.pop(_workingConfig);
              }
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Preview Card (Flat border)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      renderedPreview,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                        height: 1.4,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Presets row
            Text('Presets', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.s8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _presets.map((preset) {
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12,
                          vertical: AppSpacing.s4,
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      onPressed: () => _applyPreset(preset),
                      child: Text(
                        preset['title']!,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Friend Name & Event Name in clean form
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _friendNameController,
                    onChanged: (_) => _updateConfig(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Friend name',
                      labelStyle: theme.textTheme.labelSmall,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radius8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radius8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: TextField(
                    controller: _eventNameController,
                    onChanged: (_) => _updateConfig(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Event name',
                      labelStyle: theme.textTheme.labelSmall,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radius8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radius8),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),

            // Template text field
            Text('Countdown message', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.s8),
            TextField(
              controller: _templateController,
              maxLines: 3,
              onChanged: (_) => _updateConfig(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter template with {tokens}...',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
                contentPadding: const EdgeInsets.all(AppSpacing.s12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Placeholder chips (small outlined pill buttons)
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                _buildPlaceholderChip(context, '{days}'),
                _buildPlaceholderChip(context, '{hours}'),
                _buildPlaceholderChip(context, '{minutes}'),
                _buildPlaceholderChip(context, '{seconds}'),
                _buildPlaceholderChip(context, '{friend_name}'),
                _buildPlaceholderChip(context, '{event_name}'),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),

            // Final message field
            Text('Final message (at zero)', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.s8),
            TextField(
              controller: _completeMsgController,
              maxLines: 2,
              onChanged: (_) => _updateConfig(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Message sent once target time is reached',
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
                contentPadding: const EdgeInsets.all(AppSpacing.s12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s32),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderChip(BuildContext context, String tag) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _insertPlaceholder(tag),
      borderRadius: BorderRadius.circular(AppSpacing.radius8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radius8),
          border: Border.all(color: theme.colorScheme.outline, width: 1),
        ),
        child: Text(
          tag,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
