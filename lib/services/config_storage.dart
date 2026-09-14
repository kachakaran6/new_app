import 'package:shared_preferences/shared_preferences.dart';
import 'package:countsend/models/countdown_config.dart';

class ConfigStorage {
  static const String _key = 'countsend_active_config';

  static Future<CountdownConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      if (jsonString != null && jsonString.isNotEmpty) {
        return CountdownConfig.fromJson(jsonString);
      }
    } catch (_) {}

    // Default configuration if none saved: Target 3 days from now
    return CountdownConfig(
      targetDateTime: DateTime.now().add(const Duration(days: 3, hours: 8)),
      friendName: "Riya",
      eventName: "Birthday",
      template:
          "Hey {friend_name}! ⏳ {days}d {hours}h {minutes}m {seconds}s left for your {event_name}! 🎂",
      intervalSeconds: 5,
      autoSend: true,
      safeMode: false,
      completeMessage: "🎉 HAPPY BIRTHDAY {friend_name}! 🥳 Let's celebrate!",
    );
  }

  static Future<void> saveConfig(CountdownConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, config.toJson());
    } catch (_) {}
  }
}
