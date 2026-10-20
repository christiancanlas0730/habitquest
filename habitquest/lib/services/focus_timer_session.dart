import '../models/focus_timer_state.dart';

/// In-memory focus session shared by Focus Timer screens during this app run.
///
/// The deadline remains the source of elapsed time; this object does not
/// schedule background work or persist across a force-close/restart.
class FocusTimerSession {
  FocusTimerSession({
    DateTime Function()? clock,
    FocusTimerState? initialState,
  }) : _clock = clock ?? DateTime.now,
       _state = initialState ?? FocusTimerState.initial();

  static final FocusTimerSession shared = FocusTimerSession();

  final DateTime Function() _clock;
  FocusTimerState _state;

  FocusTimerState get state => _state;

  int remainingSecondsAtNow() => _state.remainingAt(_clock());

  void start() => _state = _state.start(_clock());

  void pause() => _state = _state.pause(_clock());

  void reset() => _state = _state.reset();

  void chooseDuration(int minutes) =>
      _state = _state.chooseDuration(minutes);

  void sync() => _state = _state.sync(_clock());
}
