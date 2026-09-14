import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:countsend/theme/app_theme.dart';
import 'package:countsend/models/log_entry.dart';
import 'package:countsend/services/accessibility_bridge.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AccessibilityBridge _bridge = AccessibilityBridge();
  final DateFormat _dateFormat = DateFormat('HH:mm:ss');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Clear history',
            onPressed: () async {
              await _bridge.clearLogs();
              setState(() {});
            },
          ),
          const SizedBox(width: AppSpacing.s8),
        ],
      ),
      body: StreamBuilder<LogEntry>(
        stream: _bridge.logStream,
        builder: (context, snapshot) {
          final logs = _bridge.historyLogs;

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 36,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    'No activity recorded',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    'Sent and copied countdowns will appear here.',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final log = logs[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status dot
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: log.success
                              ? (isDark
                                    ? AppColors.successDark
                                    : AppColors.success)
                              : AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),

                    // Timestamp
                    Text(
                      _dateFormat.format(log.timestamp),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),

                    // Message & status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                          if (log.status.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              log.status,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                color: log.success
                                    ? (isDark
                                          ? AppColors.successDark
                                          : AppColors.success)
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
