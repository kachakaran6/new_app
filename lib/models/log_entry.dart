import 'dart:convert';

class LogEntry {
  final DateTime timestamp;
  final String text;
  final bool success;
  final String status;

  const LogEntry({
    required this.timestamp,
    required this.text,
    required this.success,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'text': text,
      'success': success,
      'status': status,
    };
  }

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      text: map['text'] as String? ?? '',
      success: map['success'] as bool? ?? false,
      status: map['status'] as String? ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory LogEntry.fromJson(String source) =>
      LogEntry.fromMap(json.decode(source) as Map<String, dynamic>);
}
