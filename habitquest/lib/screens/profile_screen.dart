import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_date.dart';
import '../services/auth_service.dart';
import '../services/habit_service.dart';
import '../services/habit_repository.dart';
import '../widgets/premium_ui.dart';
import 'focus_timer_screen.dart';
import 'habit_reminders_screen.dart';
import 'mood_journal_screen.dart';
import 'my_goals_screen.dart';
import 'settings_screen.dart';
import 'help_support_screen.dart';
import 'virtual_pet_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.authRepository,
    this.repository,
    this.reminderRepository,
    this.moodRepository,
    this.petRepository,
  });

  final AuthRepository? authRepository;
  final ProfileRepository? repository;
  final ReminderRepository? reminderRepository;
  final MoodJournalRepository? moodRepository;
  final PetRepository? petRepository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final AuthRepository authService =
      widget.authRepository ?? AuthService();
  late final ProfileRepository habitService =
      widget.repository ?? HabitService();
  final TextEditingController timeZoneController = TextEditingController();
  bool isLoadingTimeZone = true;
  bool isSavingTimeZone = false;
  String? timeZoneMessage;
  DateTime? nextTimeZoneChangeAt;
  AccountDateSource? _accountDateSource;
  int _timeZoneLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadCompletionTimeZone();
  }

  @override
  void dispose() {
    timeZoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCompletionTimeZone() async {
    final generation = ++_timeZoneLoadGeneration;
    try {
      final settings = await habitService.getCompletionTimeZoneSettings();
      if (!mounted || generation != _timeZoneLoadGeneration) return;
      final dateSource = settings == null
          ? null
          : AccountDateSource.fromSettings(settings);
      setState(() {
        timeZoneController.text = settings?.timeZone ?? '';
        nextTimeZoneChangeAt = settings?.nextChangeAt;
        _accountDateSource = dateSource;
        isLoadingTimeZone = false;
      });
    } catch (error) {
      if (!mounted || generation != _timeZoneLoadGeneration) return;
      setState(() {
        isLoadingTimeZone = false;
        timeZoneMessage = completionTimeZoneErrorMessage(
          error,
          fallback: 'Timezone settings could not be loaded.',
        );
      });
    }
  }

  Future<void> _saveCompletionTimeZone() async {
    ++_timeZoneLoadGeneration;
    setState(() {
      isSavingTimeZone = true;
      timeZoneMessage = null;
    });
    try {
      final settings = await habitService.setCompletionTimeZone(
        timeZoneController.text,
      );
      if (!mounted) return;
      setState(() {
        timeZoneController.text = settings.timeZone;
        nextTimeZoneChangeAt = settings.nextChangeAt;
        _accountDateSource = AccountDateSource.fromSettings(settings);
        timeZoneMessage = 'Completion timezone saved.';
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        timeZoneMessage = completionTimeZoneSaveErrorMessage(
          error,
          fallback:
              'Timezone could not be saved. Check your connection and try again.',
        );
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        timeZoneMessage =
            'Enter a valid timezone such as Asia/Singapore or UTC.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        timeZoneMessage = completionTimeZoneErrorMessage(
          error,
          fallback:
              'Timezone could not be saved. Check your connection and try again.',
        );
      });
    } finally {
      if (mounted) setState(() => isSavingTimeZone = false);
    }
  }

  Future<void> logout(BuildContext context) async {
    try {
      await authService.logout();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to logout.')));
    }
  }

  Future<void> confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Log out?',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(color: AppColors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Log out',
                style: TextStyle(color: AppColors.red),
              ),
            ),
          ],
        );
      },
    );
    if (!context.mounted) return;
    if (shouldLogout == true) await logout(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = authService.getCurrentUser();
    final email = user?.email ?? 'No email available';
    final metadata = user?.userMetadata;
    final savedName =
        metadata?['full_name'] ??
        metadata?['name'] ??
        metadata?['display_name'];
    final name = savedName is String && savedName.trim().isNotEmpty
        ? savedName.trim()
        : email.split('@').first;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'J';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 8),
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 19),
                GlassCard(
                  glow: true,
                  padding: const EdgeInsets.all(17),
                  child: Row(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.blue, AppColors.violet],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              email,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const SectionHeading(title: 'Preferences'),
                const SizedBox(height: 13),
                _buildCompletionTimeZoneCard(),
                const SizedBox(height: 10),
                _buildMenuItem(
                  icon: Icons.pets_rounded,
                  title: 'Pet Garden',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VirtualPetScreen(
                        repository: widget.petRepository,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildMenuItem(
                  icon: Icons.track_changes_rounded,
                  title: 'My Goals',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyGoalsScreen()),
                  ),
                ),
                const SizedBox(height: 10),
                _buildMenuItem(
                  icon: Icons.timer_outlined,
                  title: 'Focus timer',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FocusTimerScreen()),
                  ),
                ),
                const SizedBox(height: 10),
                _buildMenuItem(
                  icon: Icons.mood_rounded,
                  title: 'Mood journal',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          MoodJournalScreen(
                            repository: widget.moodRepository,
                            profileRepository: habitService,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildMenuItem(
                  icon: Icons.notifications_active_outlined,
                  title: 'Habit reminders',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => HabitRemindersScreen(
                        repository: widget.reminderRepository,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildNotificationItem(),
                const SizedBox(height: 10),
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(repository: habitService),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _buildMenuItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => confirmLogout(context),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.red,
                      size: 19,
                    ),
                    label: const Text(
                      'Log out',
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.red.withValues(alpha: 0.05),
                      side: BorderSide(
                        color: AppColors.red.withValues(alpha: 0.27),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                const Center(
                  child: Text(
                    'HabitQuest',
                    style: TextStyle(
                      color: AppColors.faint,
                      fontSize: 12,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionTimeZoneCard() {
    final nextChangeDate = nextTimeZoneChangeAt == null
        ? null
        : _accountDateSource?.dateAt(nextTimeZoneChangeAt!).key;
    return GlassCard(
      padding: const EdgeInsets.all(15),
      borderRadius: 17,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completion timezone',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (nextTimeZoneChangeAt != null) ...[
            const SizedBox(height: 5),
            Text(
              'Next change available after ${nextChangeDate ?? 'account-local date unavailable'}.',
              style: const TextStyle(color: AppColors.faint, fontSize: 11),
            ),
          ],
          const SizedBox(height: 5),
          const Text(
            'Enter an IANA name such as Asia/Singapore. This is your date preference, not proof of location. Changes are limited to once every 30 days.',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 11),
          TextField(
            controller: timeZoneController,
            enabled: !isLoadingTimeZone && !isSavingTimeZone,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            decoration: premiumInputDecoration(
              hintText: 'Area/City',
              prefixIcon: Icons.public_rounded,
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoadingTimeZone || isSavingTimeZone
                  ? null
                  : _saveCompletionTimeZone,
              child: isSavingTimeZone
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save timezone'),
            ),
          ),
          if (timeZoneMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              timeZoneMessage!,
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 17,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            child: Row(
              children: [
                _menuIcon(icon),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.faint,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      borderRadius: 17,
      child: Row(
        children: [
          _menuIcon(Icons.notifications_none_rounded),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Scheduled delivery is not available in this build.',
                  style: TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.faint,
            size: 19,
          ),
        ],
      ),
    );
  }

  Widget _menuIcon(IconData icon) {
    return Container(
      width: 39,
      height: 39,
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.blue, size: 20),
    );
  }
}
