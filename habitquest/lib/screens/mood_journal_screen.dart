import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/smart_productivity.dart';
import '../models/account_date.dart';
import '../services/habit_service.dart';
import '../services/habit_repository.dart';
import '../widgets/premium_ui.dart';

class MoodJournalScreen extends StatefulWidget {
  const MoodJournalScreen({super.key, this.repository, this.profileRepository});

  final MoodJournalRepository? repository;
  final AccountDateRepository? profileRepository;

  @override
  State<MoodJournalScreen> createState() => _MoodJournalScreenState();
}

class _MoodJournalScreenState extends State<MoodJournalScreen> {
  late final MoodJournalRepository _service =
      widget.repository ?? HabitService();
  late final AccountDateRepository _profileService =
      widget.profileRepository ?? HabitService();
  final TextEditingController _noteController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _cloudAvailable = true;
  String? _selectedMood;
  String? _loadError;
  String? _todayKey;

  static const _moods = [
    ('great', 'Great', '😄', AppColors.green),
    ('good', 'Good', '🙂', AppColors.blue),
    ('okay', 'Okay', '😐', AppColors.violet),
    ('low', 'Low', '😔', AppColors.orange),
    ('rough', 'Rough', '😣', AppColors.red),
  ];

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final settings = await _profileService.getCompletionTimeZoneSettings();
      if (settings == null) {
        throw const FormatException('Account timezone is unavailable.');
      }
      final dateSource = AccountDateSource.fromSettings(settings);
      final today = dateSource.today();
      final todayKey = today.key;
      final snapshot = await _service.getMoodEntry(today.utcDate);
      if (!mounted) return;
      setState(() {
        _cloudAvailable = snapshot.cloudPersistenceAvailable;
        _todayKey = todayKey;
        _selectedMood = snapshot.entry?.mood;
        _noteController.text = snapshot.entry?.note ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error is FormatException
            ? 'Set a valid account timezone in Profile to use the mood journal.'
            : _backendError(error, 'Could not load today’s journal entry');
      });
    }
  }

  Future<void> _saveEntry() async {
    final mood = _selectedMood;
    if (mood == null) {
      _message('Choose a mood before saving.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await _service.saveMoodEntry(
        MoodEntry(
          entryDate: _todayKey ?? (throw StateError('Account date unavailable')),
          mood: mood,
          note: _noteController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _cloudAvailable = saved;
      });
      _message(
        saved
            ? 'Today’s mood entry is saved privately to your account.'
            : 'Mood sync is unavailable until the journal migration is applied. This entry was not saved.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _message(_backendError(error, 'Could not save your journal entry'));
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _backendError(Object error, String action) =>
      error is PostgrestException
      ? '$action (database error ${error.code ?? 'unknown'}). Retry after checking the backend.'
      : '$action (${error.runtimeType}). Retry after checking the connection.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mood journal')),
      body: PremiumBackground(
        child: SafeArea(
          top: false,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                )
              : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: AppColors.orange,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _loadEntry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  children: [
                    const Text(
                      'A PRIVATE CHECK-IN',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How are you feeling?',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _todayKey ?? 'Account date unavailable',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    if (!_cloudAvailable) ...[
                      const SizedBox(height: 14),
                      const _JournalSyncNotice(),
                    ],
                    const SizedBox(height: 18),
                    GlassCard(
                      glow: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Choose the closest fit',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final mood in _moods)
                                ChoiceChip(
                                  avatar: Text(
                                    mood.$3,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                  label: Text(mood.$2),
                                  selected: _selectedMood == mood.$1,
                                  selectedColor: mood.$4.withValues(alpha: 0.2),
                                  onSelected: (_) =>
                                      setState(() => _selectedMood = mood.$1),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'A note for yourself (optional)',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 9),
                          TextField(
                            controller: _noteController,
                            maxLength: 280,
                            minLines: 3,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Anything you would like to remember?',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _saveEntry,
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.lock_outline_rounded),
                              label: Text(
                                _saving ? 'Saving…' : 'Save check-in',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your mood and note are private to your account. The app only asks for one daily mood and a short optional note.',
                      style: TextStyle(
                        color: AppColors.faint,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _JournalSyncNotice extends StatelessWidget {
  const _JournalSyncNotice();

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(13),
    child: const Row(
      children: [
        Icon(Icons.cloud_off_rounded, color: AppColors.orange, size: 18),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Private journal sync is unavailable until the review-only migration is applied.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}
