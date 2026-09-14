import 'package:countsend/models/countdown_config.dart';

class CountdownTimeSnapshot {
  final int days;
  final int hours;
  final int minutes;
  final int seconds;
  final int totalSeconds;
  final bool isCompleted;

  const CountdownTimeSnapshot({
    required this.days,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.totalSeconds,
    required this.isCompleted,
  });

  String get daysPadded => days.toString();
  String get hoursPadded => hours.toString().padLeft(2, '0');
  String get minutesPadded => minutes.toString().padLeft(2, '0');
  String get secondsPadded => seconds.toString().padLeft(2, '0');

  String get formattedSummary =>
      '${days}d ${hoursPadded}h ${minutesPadded}m ${secondsPadded}s';
}

class CountdownEngine {
  static CountdownTimeSnapshot calculateSnapshot(
    DateTime targetDateTime, [
    DateTime? now,
  ]) {
    final current = now ?? DateTime.now();
    final difference = targetDateTime.difference(current);

    if (difference.isNegative || difference.inSeconds <= 0) {
      return const CountdownTimeSnapshot(
        days: 0,
        hours: 0,
        minutes: 0,
        seconds: 0,
        totalSeconds: 0,
        isCompleted: true,
      );
    }

    final totalSec = difference.inSeconds;
    final days = totalSec ~/ 86400;
    final hours = (totalSec % 86400) ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    final seconds = totalSec % 60;

    return CountdownTimeSnapshot(
      days: days,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      totalSeconds: totalSec,
      isCompleted: false,
    );
  }

  static String renderMessage(CountdownConfig config, [DateTime? now]) {
    final snapshot = calculateSnapshot(config.targetDateTime, now);

    if (snapshot.isCompleted) {
      return config.completeMessage
          .replaceAll('{friend_name}', config.friendName)
          .replaceAll('{event_name}', config.eventName);
    }

    return config.template
        .replaceAll('{days}', snapshot.daysPadded)
        .replaceAll('{hours}', snapshot.hoursPadded)
        .replaceAll('{minutes}', snapshot.minutesPadded)
        .replaceAll('{seconds}', snapshot.secondsPadded)
        .replaceAll('{friend_name}', config.friendName)
        .replaceAll('{event_name}', config.eventName);
  }
}
