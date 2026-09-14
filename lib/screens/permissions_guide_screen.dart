import 'package:flutter/material.dart';
import 'package:countsend/theme/app_theme.dart';
import 'package:countsend/services/accessibility_bridge.dart';

class PermissionsGuideScreen extends StatefulWidget {
  const PermissionsGuideScreen({super.key});

  @override
  State<PermissionsGuideScreen> createState() => _PermissionsGuideScreenState();
}

class _PermissionsGuideScreenState extends State<PermissionsGuideScreen> {
  final AccessibilityBridge _bridge = AccessibilityBridge();
  PermissionStatusSnapshot? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    setState(() => _isLoading = true);
    final status = await _bridge.checkPermissions();
    if (mounted) {
      setState(() {
        _status = status;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isReady = _status?.isReadyForFullAuto ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            onPressed: _refreshPermissions,
          ),
          const SizedBox(width: AppSpacing.s8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Indicator Row
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isReady
                              ? (isDark
                                    ? AppColors.successDark
                                    : AppColors.success)
                              : (isDark
                                    ? AppColors.warningDark
                                    : AppColors.warning),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        isReady
                            ? 'All required permissions granted'
                            : 'Permissions required for automation',
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Grouped List Card
                  Card(
                    child: Column(
                      children: [
                        _buildPermissionRow(
                          context,
                          title: 'Accessibility Service',
                          description:
                              'Used to detect chat inputs, paste text, and dispatch send clicks.',
                          isGranted: _status?.accessibilityGranted ?? false,
                          onAction: () => _bridge.openAccessibilitySettings(),
                        ),
                        const Divider(),
                        _buildPermissionRow(
                          context,
                          title: 'Draw Over Other Apps',
                          description:
                              'Enables the floating pill and calibration crosshair over other apps.',
                          isGranted: _status?.overlayGranted ?? false,
                          onAction: () => _bridge.openOverlaySettings(),
                        ),
                        const Divider(),
                        _buildPermissionRow(
                          context,
                          title: 'Notifications',
                          description:
                              'Maintains background ticker reliability against battery killers.',
                          isGranted: _status?.notificationGranted ?? false,
                          onAction: () =>
                              _bridge.requestNotificationPermission(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  // Privacy Note (Subtle callout box)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radius8),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              'Privacy & Security',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          'Tickr only acts on the selected message field. It does not record keystrokes, monitor incoming notifications, or transmit any data externally.',
                          style: theme.textTheme.labelSmall?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPermissionRow(
    BuildContext context, {
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: theme.textTheme.labelLarge),
                    const SizedBox(width: AppSpacing.s8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isGranted
                            ? (isDark
                                  ? AppColors.successDark
                                  : AppColors.success)
                            : (isDark
                                  ? AppColors.warningDark
                                  : AppColors.warning),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(description, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          SizedBox(
            height: 32,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                backgroundColor: isGranted
                    ? Colors.transparent
                    : theme.colorScheme.primary,
                foregroundColor: isGranted
                    ? (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary)
                    : Colors.white,
                side: BorderSide(
                  color: isGranted
                      ? theme.colorScheme.outline
                      : theme.colorScheme.primary,
                  width: 1,
                ),
              ),
              onPressed: onAction,
              child: Text(
                isGranted ? 'Check' : 'Enable',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
