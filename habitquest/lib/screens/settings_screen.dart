import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_date.dart';
import '../services/habit_repository.dart';
import '../services/habit_service.dart';
import '../widgets/premium_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.repository});

  final ProfileRepository? repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final ProfileRepository _repository =
      widget.repository ?? HabitService();
  final TextEditingController _timeZoneController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _feedback;
  DateTime? _nextChangeAt;
  AccountDateSource? _accountDateSource;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _timeZoneController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _loadError = null;
      _feedback = null;
    });
    try {
      final settings = await _repository.getCompletionTimeZoneSettings();
      if (!mounted || generation != _loadGeneration) return;
      final dateSource = settings == null
          ? null
          : AccountDateSource.fromSettings(settings);
      setState(() {
        _timeZoneController.text = settings?.timeZone ?? '';
        _nextChangeAt = settings?.nextChangeAt;
        _accountDateSource = dateSource;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadError = 'Settings could not be loaded.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTimeZone() async {
    if (_isLoading || _isSaving) return;
    final requestedTimeZone = _timeZoneController.text.trim();
    if (!AccountDateSource.isValidTimeZone(requestedTimeZone)) {
      setState(() => _feedback = 'Enter a valid IANA timezone, such as UTC.');
      return;
    }

    setState(() {
      _isSaving = true;
      _feedback = null;
    });
    try {
      final settings = await _repository.setCompletionTimeZone(
        requestedTimeZone,
      );
      if (!mounted) return;
      setState(() {
        _timeZoneController.text = settings.timeZone;
        _nextChangeAt = settings.nextChangeAt;
        _accountDateSource = AccountDateSource.fromSettings(settings);
        _feedback = 'Completion timezone saved.';
      });
    } on FormatException {
      if (!mounted) return;
      setState(() => _feedback = 'Enter a valid IANA timezone, such as UTC.');
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _feedback = completionTimeZoneSaveErrorMessage(
          error,
          fallback: 'Timezone could not be saved. Check your connection and try again.',
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _feedback = completionTimeZoneErrorMessage(
          error,
          fallback: 'Timezone could not be saved. Check your connection and try again.',
        );
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextChangeDate = _nextChangeAt == null
        ? null
        : _accountDateSource?.dateAt(_nextChangeAt!).key;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: PremiumBackground(
        child: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                )
              : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _loadError!,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      TextButton(onPressed: _loadSettings, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  children: [
                    const Text(
                      'ACCOUNT',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 17,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Completion timezone',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_nextChangeAt != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              'Next change available after ${nextChangeDate ?? 'account-local date unavailable'}.',
                              style: const TextStyle(
                                color: AppColors.faint,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const SizedBox(height: 7),
                          const Text(
                            'Use an IANA name such as Asia/Singapore or UTC. This setting controls account calendar dates. Changes are limited by the account timezone policy.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 13),
                          TextField(
                            controller: _timeZoneController,
                            enabled: !_isSaving,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.none,
                            decoration: premiumInputDecoration(
                              hintText: 'Area/City',
                              prefixIcon: Icons.public_rounded,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _saveTimeZone,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save timezone'),
                            ),
                          ),
                          if (_feedback != null) ...[
                            const SizedBox(height: 9),
                            Text(
                              _feedback!,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'APP',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const GlassCard(
                      padding: EdgeInsets.all(16),
                      borderRadius: 17,
                      child: Text(
                        'This build uses HabitQuest’s fixed dark appearance. It has no local preference storage for a theme selector or other app-only settings.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
