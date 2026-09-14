import 'dart:convert';

class CountdownConfig {
  final DateTime targetDateTime;
  final String template;
  final String friendName;
  final String eventName;
  final int intervalSeconds;
  final bool autoSend;
  final bool safeMode;
  final String completeMessage;

  const CountdownConfig({
    required this.targetDateTime,
    this.template =
        "Hey {friend_name}! ⏳ {days}d {hours}h {minutes}m {seconds}s left for your {event_name}! 🎂",
    this.friendName = "Riya",
    this.eventName = "Birthday",
    this.intervalSeconds = 5,
    this.autoSend = true,
    this.safeMode = false,
    this.completeMessage =
        "🎉 HAPPY BIRTHDAY {friend_name}! 🥳 Let's celebrate!",
  });

  CountdownConfig copyWith({
    DateTime? targetDateTime,
    String? template,
    String? friendName,
    String? eventName,
    int? intervalSeconds,
    bool? autoSend,
    bool? safeMode,
    String? completeMessage,
  }) {
    return CountdownConfig(
      targetDateTime: targetDateTime ?? this.targetDateTime,
      template: template ?? this.template,
      friendName: friendName ?? this.friendName,
      eventName: eventName ?? this.eventName,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      autoSend: autoSend ?? this.autoSend,
      safeMode: safeMode ?? this.safeMode,
      completeMessage: completeMessage ?? this.completeMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'targetDateTime': targetDateTime.millisecondsSinceEpoch,
      'template': template,
      'friendName': friendName,
      'eventName': eventName,
      'intervalSeconds': intervalSeconds,
      'autoSend': autoSend,
      'safeMode': safeMode,
      'completeMessage': completeMessage,
    };
  }

  factory CountdownConfig.fromMap(Map<String, dynamic> map) {
    return CountdownConfig(
      targetDateTime: map['targetDateTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['targetDateTime'] as int)
          : DateTime.now().add(const Duration(days: 3, hours: 4)),
      template:
          map['template'] as String? ??
          "Hey {friend_name}! ⏳ {days}d {hours}h {minutes}m {seconds}s left for your {event_name}! 🎂",
      friendName: map['friendName'] as String? ?? "Riya",
      eventName: map['eventName'] as String? ?? "Birthday",
      intervalSeconds: map['intervalSeconds'] as int? ?? 5,
      autoSend: map['autoSend'] as bool? ?? true,
      safeMode: map['safeMode'] as bool? ?? false,
      completeMessage:
          map['completeMessage'] as String? ??
          "🎉 HAPPY BIRTHDAY {friend_name}! 🥳 Let's celebrate!",
    );
  }

  String toJson() => json.encode(toMap());

  factory CountdownConfig.fromJson(String source) =>
      CountdownConfig.fromMap(json.decode(source) as Map<String, dynamic>);
}
