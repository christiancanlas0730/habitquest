/// Pure timer state driven by wall-clock time rather than ticker count.
class FocusTimerState {
  const FocusTimerState({
    required this.durationSeconds,
    required this.remainingSeconds,
    required this.endsAt,
    required this.completedSessions,
    required this.completed,
  });

  factory FocusTimerState.initial({int durationMinutes = 25}) =>
      FocusTimerState(
        durationSeconds: durationMinutes * 60,
        remainingSeconds: durationMinutes * 60,
        endsAt: null,
        completedSessions: 0,
        completed: false,
      );

  final int durationSeconds;
  final int remainingSeconds;
  final DateTime? endsAt;
  final int completedSessions;
  final bool completed;

  bool get running => endsAt != null;

  int remainingAt(DateTime now) {
    final end = endsAt;
    if (end == null) return remainingSeconds;
    return end.difference(now).inSeconds.clamp(0, durationSeconds).toInt();
  }

  FocusTimerState start(DateTime now) {
    if (completed) {
      return reset().copyWith(
        endsAt: now.add(Duration(seconds: durationSeconds)),
        completed: false,
      );
    }
    if (running) return this;
    return copyWith(
      endsAt: now.add(Duration(seconds: remainingSeconds)),
      completed: false,
    );
  }

  FocusTimerState pause(DateTime now) {
    if (!running) return this;
    return copyWith(
      remainingSeconds: remainingAt(now),
      endsAt: null,
      clearEnd: true,
    );
  }

  FocusTimerState sync(DateTime now) {
    if (!running) return this;
    final remaining = remainingAt(now);
    if (remaining > 0) return copyWith(remainingSeconds: remaining);
    return copyWith(
      remainingSeconds: 0,
      endsAt: null,
      clearEnd: true,
      completed: true,
      completedSessions: completedSessions + 1,
    );
  }

  FocusTimerState reset() => copyWith(
    remainingSeconds: durationSeconds,
    endsAt: null,
    clearEnd: true,
    completed: false,
  );

  FocusTimerState chooseDuration(int minutes) {
    if (minutes < 1 || minutes > 180) {
      throw ArgumentError.value(minutes, 'minutes', 'Must be 1 to 180.');
    }
    final seconds = minutes * 60;
    return copyWith(
      durationSeconds: seconds,
      remainingSeconds: seconds,
      endsAt: null,
      clearEnd: true,
      completed: false,
    );
  }

  FocusTimerState copyWith({
    int? durationSeconds,
    int? remainingSeconds,
    DateTime? endsAt,
    bool clearEnd = false,
    int? completedSessions,
    bool? completed,
  }) => FocusTimerState(
    durationSeconds: durationSeconds ?? this.durationSeconds,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    endsAt: clearEnd ? null : endsAt ?? this.endsAt,
    completedSessions: completedSessions ?? this.completedSessions,
    completed: completed ?? this.completed,
  );
}
