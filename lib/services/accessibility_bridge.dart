import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:countsend/models/countdown_config.dart';
import 'package:countsend/models/log_entry.dart';

class PermissionStatusSnapshot {
  final bool accessibilityGranted;
  final bool overlayGranted;
  final bool notificationGranted;

  const PermissionStatusSnapshot({
    required this.accessibilityGranted,
    required this.overlayGranted,
    required this.notificationGranted,
  });

  bool get isReadyForFullAuto => accessibilityGranted && overlayGranted;
  bool get isReadyForSafeMode => overlayGranted;
}

class AccessibilityBridge {
  static const MethodChannel _channel = MethodChannel('com.countsend/bridge');

  static final AccessibilityBridge _instance = AccessibilityBridge._internal();
  factory AccessibilityBridge() => _instance;

  final StreamController<LogEntry> _logStreamController =
      StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get logStream => _logStreamController.stream;

  final List<LogEntry> _historyLogs = [];
  List<LogEntry> get historyLogs => List.unmodifiable(_historyLogs);

  AccessibilityBridge._internal() {
    _initNativeCallbacks();
    _loadPersistedLogs();
  }

  void _initNativeCallbacks() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLogEvent') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final timestampMillis =
            (args['timestamp'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch;
        final text = args['text'] as String? ?? '';
        final success = args['success'] as bool? ?? false;
        final status = args['status'] as String? ?? '';

        final entry = LogEntry(
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMillis),
          text: text,
          success: success,
          status: status,
        );

        _historyLogs.insert(0, entry);
        if (_historyLogs.length > 200) {
          _historyLogs.removeLast();
        }
        _logStreamController.add(entry);
        _persistLogs();
      }
    });
  }

  Future<void> _loadPersistedLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getStringList('countsend_history_logs') ?? [];
      _historyLogs.clear();
      for (final item in logsJson) {
        try {
          _historyLogs.add(LogEntry.fromJson(item));
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _persistLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logsJson = _historyLogs.take(100).map((e) => e.toJson()).toList();
      await prefs.setStringList('countsend_history_logs', logsJson);
    } catch (_) {}
  }

  Future<void> clearLogs() async {
    _historyLogs.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('countsend_history_logs');
  }

  Future<bool> isAccessibilityGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'isAccessibilityGranted',
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  Future<bool> isOverlayGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isOverlayGranted');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openOverlaySettings() async {
    try {
      await _channel.invokeMethod('openOverlaySettings');
    } catch (_) {}
  }

  Future<bool> isNotificationGranted() async {
    try {
      final result = await _channel.invokeMethod<bool>('isNotificationGranted');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  Future<PermissionStatusSnapshot> checkPermissions() async {
    final acc = await isAccessibilityGranted();
    final ovl = await isOverlayGranted();
    final notif = await isNotificationGranted();
    return PermissionStatusSnapshot(
      accessibilityGranted: acc,
      overlayGranted: ovl,
      notificationGranted: notif,
    );
  }

  Future<bool> isOverlayRunning() async {
    try {
      final result = await _channel.invokeMethod<bool>('isOverlayRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startOverlay(CountdownConfig config) async {
    try {
      final result = await _channel.invokeMethod<bool>('startOverlay', {
        'targetTime': config.targetDateTime.millisecondsSinceEpoch,
        'template': config.template,
        'friendName': config.friendName,
        'eventName': config.eventName,
        'intervalSec': config.intervalSeconds,
        'autoSend': config.autoSend,
        'safeMode': config.safeMode,
        'completeMsg': config.completeMessage,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopOverlay() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopOverlay');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> sendTestMessage(
    String text,
    bool autoSend,
  ) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'sendTestMessage',
        {'text': text, 'autoSend': autoSend},
      );
      return result ?? {'success': false, 'message': 'Unknown error'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, double>> getSavedSendTarget() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'getSavedSendTarget',
      );
      if (result != null) {
        return {
          'x': (result['x'] as num?)?.toDouble() ?? -1.0,
          'y': (result['y'] as num?)?.toDouble() ?? -1.0,
        };
      }
    } catch (_) {}
    return {'x': -1.0, 'y': -1.0};
  }

  Future<void> setSavedSendTarget(double x, double y) async {
    try {
      await _channel.invokeMethod('setSavedSendTarget', {'x': x, 'y': y});
    } catch (_) {}
  }

  Future<void> clearSavedSendTarget() async {
    try {
      await _channel.invokeMethod('setSavedSendTarget', {'x': -1.0, 'y': -1.0});
    } catch (_) {}
  }
}
