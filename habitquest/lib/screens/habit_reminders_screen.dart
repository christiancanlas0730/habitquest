import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/habit_reminder_save.dart';
import '../models/smart_productivity.dart';
import '../services/habit_repository.dart';
import '../services/habit_service.dart';
import '../widgets/premium_ui.dart';

class HabitRemindersScreen extends StatefulWidget {
  const HabitRemindersScreen({super.key, this.repository});

  final ReminderRepository? repository;

  @override
  State<HabitRemindersScreen> createState() => _HabitRemindersScreenState();
}

class _HabitRemindersScreenState extends State<HabitRemindersScreen> {
  late final ReminderRepository _service = widget.repository ?? HabitService();
  List<Habit> _habits = [];
  Map<String, HabitReminderPreference> _preferences = {};
  bool _loading = true;
  bool _cloudAvailable = true;
  String? _error;
  final Set<String> _savingHabitIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_savingHabitIds.isNotEmpty) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final habits = await _service.getHabits();
      final snapshot = await _service.getHabitReminders();
      if (!mounted) return;
      setState(() {
        _habits = habits;
        _preferences = snapshot.preferences;
        _cloudAvailable = snapshot.cloudPersistenceAvailable;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load reminder preferences.';
      });
    }
  }

  HabitReminderPreference _preferenceFor(Habit habit) =>
      _preferences[habit.id] ??
      HabitReminderPreference(habitId: habit.id, enabled: false, time: '09:00');

  Future<void> _save(HabitReminderPreference preference) async {
    if (_savingHabitIds.contains(preference.habitId)) return;
    if (!_cloudAvailable) {
      final result = HabitReminderSaveResult.apply(
        current: _preferences,
        preference: preference,
        cloudPersistenceAvailable: false,
        persisted: false,
      );
      setState(() => _preferences = result.preferences);
      _message(
        'This preference is temporary until the reminders migration is applied.',
      );
      return;
    }
    setState(() => _savingHabitIds.add(preference.habitId));
    try {
      final saved = await _service.saveHabitReminder(preference);
      if (!mounted) return;
      final result = HabitReminderSaveResult.apply(
        current: _preferences,
        preference: preference,
        cloudPersistenceAvailable: true,
        persisted: saved,
      );
      setState(() {
        _preferences = result.preferences;
        _cloudAvailable = result.cloudPersistenceAvailable;
        _savingHabitIds.remove(preference.habitId);
      });
      _message(
        saved
            ? 'Reminder preference saved. Notifications are not scheduled in this build.'
            : 'Preference is temporary until the reminders migration is applied.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingHabitIds.remove(preference.habitId));
      _message('Could not save this reminder preference.');
    }
  }

  Future<void> _chooseTime(HabitReminderPreference preference) async {
    final parts = preference.time.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Choose reminder time',
    );
    if (time == null || !mounted) return;
    await _save(
      preference.copyWith(
        time:
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      ),
    );
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Habit reminders')),
      body: PremiumBackground(
        child: SafeArea(
          top: false,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                )
              : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  color: AppColors.blue,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                    children: [
                      const Text(
                        'YOUR ROUTINE, YOUR TIME',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reminder preferences',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Choose a time for each habit. This build saves preferences only; it does not schedule operating-system or browser notifications.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      if (!_cloudAvailable) ...[
                        const SizedBox(height: 14),
                        const _SyncNotice(),
                      ],
                      const SizedBox(height: 18),
                      if (_habits.isEmpty)
                        const GlassCard(
                          child: Text(
                            'Create a habit first, then you can configure its reminder preference.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        for (final habit in _habits) ...[
                          _ReminderCard(
                            habit: habit,
                            preference: _preferenceFor(habit),
                            saving: _savingHabitIds.contains(habit.id),
                            onEnabledChanged: (enabled) => _save(
                              _preferenceFor(habit).copyWith(enabled: enabled),
                            ),
                            onTimePressed: () =>
                                _chooseTime(_preferenceFor(habit)),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.habit,
    required this.preference,
    required this.saving,
    required this.onEnabledChanged,
    required this.onTimePressed,
  });

  final Habit habit;
  final HabitReminderPreference preference;
  final bool saving;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onTimePressed;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.fromLTRB(15, 8, 15, 13),
    child: Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: preference.enabled,
          onChanged: saving ? null : onEnabledChanged,
          activeTrackColor: AppColors.violet,
          title: Text(
            habit.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            habit.frequency,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: saving ? null : onTimePressed,
            icon: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.schedule_rounded, size: 17),
            label: Text('Preferred time · ${preference.time}'),
          ),
        ),
      ],
    ),
  );
}

class _SyncNotice extends StatelessWidget {
  const _SyncNotice();

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(13),
    child: const Row(
      children: [
        Icon(Icons.cloud_off_rounded, color: AppColors.orange, size: 18),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Cloud preference storage is unavailable until the review-only migration is applied.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}
