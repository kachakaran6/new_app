import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:countsend/main.dart';
import 'package:countsend/theme/app_theme.dart';
import 'package:countsend/models/countdown_config.dart';
import 'package:countsend/services/countdown_engine.dart';
import 'package:countsend/services/config_storage.dart';
import 'package:countsend/services/accessibility_bridge.dart';
import 'package:countsend/screens/template_editor_screen.dart';
import 'package:countsend/screens/history_screen.dart';
import 'package:countsend/screens/permissions_guide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AccessibilityBridge _bridge = AccessibilityBridge();
  CountdownConfig _config = CountdownConfig(
    targetDateTime: DateTime.now().add(const Duration(days: 3, hours: 8)),
  );
  bool _isConfigLoaded = false;
  bool _isOverlayActive = false;
  PermissionStatusSnapshot? _permissionStatus;
  Map<String, double> _savedTarget = {'x': -1.0, 'y': -1.0};

  Timer? _tickerTimer;
  final DateFormat _displayDateFormat = DateFormat(
    'EEE, MMM d, yyyy • hh:mm a',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();

    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndOverlay();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickerTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    final loaded = await ConfigStorage.loadConfig();
    setState(() {
      _config = loaded;
      _isConfigLoaded = true;
    });
    await _checkPermissionsAndOverlay();
  }

  Future<void> _checkPermissionsAndOverlay() async {
    final perms = await _bridge.checkPermissions();
    final running = await _bridge.isOverlayRunning();
    final target = await _bridge.getSavedSendTarget();
    if (mounted) {
      setState(() {
        _permissionStatus = perms;
        _isOverlayActive = running;
        _savedTarget = target;
      });
    }
  }

  Future<void> _pickTargetDateTime() async {
    final now = DateTime.now();
    final initialDate = _config.targetDateTime.isAfter(now)
        ? _config.targetDateTime
        : now.add(const Duration(days: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_config.targetDateTime),
    );

    if (pickedTime == null) return;

    final newTarget = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    final updated = _config.copyWith(targetDateTime: newTarget);
    setState(() => _config = updated);
    await ConfigStorage.saveConfig(updated);
  }

  Future<void> _toggleOverlay() async {
    if (_isOverlayActive) {
      await _bridge.stopOverlay();
      setState(() => _isOverlayActive = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Floating bubble stopped'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      final perms = await _bridge.checkPermissions();
      if (!_config.safeMode && !perms.accessibilityGranted) {
        _showPermissionDialog(
          title: 'Accessibility Required',
          message:
              'Enable the Tickr Accessibility Service to inspect fields, auto-type, and send.',
        );
        return;
      }

      if (!perms.overlayGranted) {
        _showPermissionDialog(
          title: 'Overlay Permission Required',
          message:
              'Allow "Draw over other apps" so the floating controller can appear over chat windows.',
        );
        return;
      }

      final started = await _bridge.startOverlay(_config);
      if (started) {
        setState(() => _isOverlayActive = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tickr floating bubble active (${_config.intervalSeconds}s interval)',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showPermissionDialog({required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PermissionsGuideScreen(),
                ),
              ).then((_) => _checkPermissionsAndOverlay());
            },
            child: const Text('Configure'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!_isConfigLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final snapshot = CountdownEngine.calculateSnapshot(_config.targetDateTime);
    final renderedPreview = CountdownEngine.renderMessage(_config);
    final isFullReady = _permissionStatus?.isReadyForFullAuto ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickr'),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
            ),
            tooltip: 'Toggle Theme',
            onPressed: () {
              themeModeNotifier.value = isDark
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_outlined, size: 20),
            tooltip: 'History Log',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_outlined, size: 20),
            tooltip: 'Permissions',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PermissionsGuideScreen(),
                ),
              ).then((_) => _checkPermissionsAndOverlay());
            },
          ),
          const SizedBox(width: AppSpacing.s8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Line: Small text label + dot indicator
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFullReady
                        ? (isDark ? AppColors.successDark : AppColors.success)
                        : (isDark ? AppColors.warningDark : AppColors.warning),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  isFullReady ? 'System ready' : 'Setup required',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (!isFullReady) ...[
                  const SizedBox(width: AppSpacing.s8),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PermissionsGuideScreen(),
                        ),
                      ).then((_) => _checkPermissionsAndOverlay());
                    },
                    child: Text(
                      'Resolve →',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.s24),

            // Hero Section: Left-aligned label above countdown
            Text(
              'Time until ${_config.friendName}\'s ${_config.eventName}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Hero Countdown Display (Front and center, restrained accent color)
            Center(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s24,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radius8),
                  border: Border.all(
                    color: theme.colorScheme.outline,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildNumeralUnit(theme, snapshot.daysPadded, 'd'),
                        _buildSeparator(theme),
                        _buildNumeralUnit(theme, snapshot.hoursPadded, 'h'),
                        _buildSeparator(theme),
                        _buildNumeralUnit(theme, snapshot.minutesPadded, 'm'),
                        _buildSeparator(theme),
                        _buildNumeralUnit(theme, snapshot.secondsPadded, 's'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    InkWell(
                      onTap: _pickTargetDateTime,
                      borderRadius: BorderRadius.circular(AppSpacing.radius8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s8,
                          vertical: AppSpacing.s4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              _displayDateFormat.format(_config.targetDateTime),
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(width: AppSpacing.s4),
                            Icon(
                              Icons.chevron_right,
                              size: 14,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Primary Action Button (Restrained single color, flat)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _toggleOverlay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOverlayActive
                      ? AppColors.error
                      : theme.colorScheme.primary,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isOverlayActive
                          ? Icons.stop_outlined
                          : Icons.play_arrow_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      _isOverlayActive ? 'Stop Auto-Typer' : 'Start Auto-Typer',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Template Preview Card (Flat border, distinct grouped unit)
            Card(
              child: InkWell(
                onTap: () async {
                  final updated = await Navigator.push<CountdownConfig>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TemplateEditorScreen(initialConfig: _config),
                    ),
                  );
                  if (updated != null) {
                    setState(() => _config = updated);
                  }
                },
                borderRadius: BorderRadius.circular(AppSpacing.radius8),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Message Template',
                            style: theme.textTheme.labelLarge,
                          ),
                          Text(
                            'Edit',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        renderedPreview,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
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
            ),
            const SizedBox(height: AppSpacing.s16),

            // Automation Parameters Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Interval Rate', style: theme.textTheme.labelLarge),
                    const SizedBox(height: AppSpacing.s12),
                    Row(
                      children: [1, 5, 10, 30, 60].map((sec) {
                        final isSelected = _config.intervalSeconds == sec;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                backgroundColor: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                foregroundColor: isSelected
                                    ? Colors.white
                                    : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                                side: BorderSide(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                  width: 1,
                                ),
                              ),
                              onPressed: () {
                                final updated = _config.copyWith(
                                  intervalSeconds: sec,
                                );
                                setState(() => _config = updated);
                                ConfigStorage.saveConfig(updated);
                              },
                              child: Text(
                                '${sec}s',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Safe mode',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Copies text to clipboard without typing into fields.',
                        style: theme.textTheme.labelSmall,
                      ),
                      value: _config.safeMode,
                      activeThumbColor: theme.colorScheme.primary,
                      onChanged: (val) {
                        final updated = _config.copyWith(safeMode: val);
                        setState(() => _config = updated);
                        ConfigStorage.saveConfig(updated);
                      },
                    ),
                    const Divider(),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Auto-tap Send button',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Dispatches a tap gesture on the Send button after typing.',
                        style: theme.textTheme.labelSmall,
                      ),
                      value: _config.autoSend && !_config.safeMode,
                      activeThumbColor: theme.colorScheme.primary,
                      onChanged: _config.safeMode
                          ? null
                          : (val) {
                              final updated = _config.copyWith(autoSend: val);
                              setState(() => _config = updated);
                              ConfigStorage.saveConfig(updated);
                            },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Send Button Target Pin Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Send button calibration',
                          style: theme.textTheme.labelLarge,
                        ),
                        if (_savedTarget['x']! > 0)
                          InkWell(
                            onTap: () async {
                              await _bridge.clearSavedSendTarget();
                              await _checkPermissionsAndOverlay();
                            },
                            child: Text(
                              'Reset',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      _savedTarget['x']! > 0
                          ? 'Pinned location: (${_savedTarget['x']!.toInt()}, ${_savedTarget['y']!.toInt()})'
                          : 'Auto-detection (relative to text box)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _savedTarget['x']! > 0
                            ? (isDark
                                  ? AppColors.successDark
                                  : AppColors.success)
                            : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      'Use the floating bubble\'s "Pin Send" action to align the crosshair directly over your chat\'s send button.',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Test Single Send Button (Outlined, minimal)
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final text = CountdownEngine.renderMessage(_config);
                  final res = await _bridge.sendTestMessage(
                    text,
                    _config.autoSend,
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Done'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Test send active field'),
              ),
            ),
            const SizedBox(height: AppSpacing.s32),
          ],
        ),
      ),
    );
  }

  Widget _buildNumeralUnit(ThemeData theme, String value, String unit) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 32,
            fontFamily: 'monospace',
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          unit,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.brightness == Brightness.dark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSeparator(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w300,
          color: theme.brightness == Brightness.dark
              ? AppColors.darkTextTertiary
              : AppColors.lightTextTertiary,
        ),
      ),
    );
  }
}
