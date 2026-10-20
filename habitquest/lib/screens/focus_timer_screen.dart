import 'dart:async';

import 'package:flutter/material.dart';

import '../services/focus_timer_session.dart';
import '../widgets/premium_ui.dart';

class FocusTimerScreen extends StatefulWidget {
  const FocusTimerScreen({super.key, this.session});

  final FocusTimerSession? session;

  @override
  State<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends State<FocusTimerScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  late final FocusTimerSession _session =
      widget.session ?? FocusTimerSession.shared;

  int get _durationMinutes => _session.state.durationSeconds ~/ 60;
  int get _remainingSeconds => _session.remainingSecondsAtNow();
  int get _completedSessions => _session.state.completedSessions;
  bool get _running => _session.state.running;
  bool get _completed => _session.state.completed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.sync();
    _startTickerIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelTicker();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTimer();
      _startTickerIfNeeded();
    } else {
      _cancelTicker();
    }
  }

  void _start() {
    _session.start();
    setState(() {});
    _startTickerIfNeeded();
  }

  void _pause() {
    _syncTimer();
    if (!_running) return;
    _session.pause();
    _cancelTicker();
    setState(() {});
  }

  void _syncTimer() {
    if (!mounted) return;
    if (_running) _session.sync();
    if (!_running) _cancelTicker();
    setState(() {});
  }

  void _startTickerIfNeeded() {
    if (!_running || _ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _syncTimer());
  }

  void _cancelTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _reset() {
    _cancelTicker();
    _session.reset();
    setState(() {});
  }

  void _chooseDuration(int minutes) {
    _cancelTicker();
    _session.chooseDuration(minutes);
    setState(() {});
  }

  Future<void> _chooseCustomDuration() async {
    final controller = TextEditingController(text: '30');
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom focus length'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            helperText: 'Choose between 1 and 180 minutes.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              if (parsed == null || parsed < 1 || parsed > 180) return;
              Navigator.pop(context, parsed);
            },
            child: const Text('Set timer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) _chooseDuration(value);
  }

  String get _timeLabel {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = 1 - _remainingSeconds / (_durationMinutes * 60);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Focus timer')),
      body: PremiumBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              GlassCard(
                glow: true,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  children: [
                    const Text(
                      'One thing at a time',
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 12,
                              strokeCap: StrokeCap.round,
                              backgroundColor: const Color(0xFF2A303B),
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.blue,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _timeLabel,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              Text(
                                _running
                                    ? 'FOCUSING'
                                    : _completed
                                    ? 'COMPLETE'
                                    : 'READY',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        for (final minutes in const [15, 25, 45])
                          ChoiceChip(
                            label: Text('$minutes min'),
                            selected: _durationMinutes == minutes,
                            onSelected: _running
                                ? null
                                : (_) => _chooseDuration(minutes),
                          ),
                        ActionChip(
                          label: const Text('Custom'),
                          onPressed: _running ? null : _chooseCustomDuration,
                        ),
                      ],
                    ),
                    const SizedBox(height: 19),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_running)
                          FilledButton.icon(
                            onPressed: _completed
                                ? () {
                                    _reset();
                                    _start();
                                  }
                                : _start,
                            icon: Icon(
                              _remainingSeconds == 0
                                  ? Icons.replay_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(
                              _completed
                                  ? 'Start again'
                                  : _remainingSeconds < _durationMinutes * 60
                                  ? 'Resume'
                                  : 'Start',
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: _pause,
                            icon: const Icon(Icons.pause_rounded),
                            label: const Text('Pause'),
                          ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _reset,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              GlassCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.green,
                      size: 22,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        _completed
                            ? 'Focus session complete: $_durationMinutes minutes. Nice work. Sessions this app session: $_completedSessions.'
                            : 'Completed sessions this app session: $_completedSessions',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Focus sessions are not habit completions and do not award habit XP.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.faint, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
