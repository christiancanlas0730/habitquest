import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/premium_ui.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService authService = AuthService();
  bool notificationsEnabled = true;

  Future<void> logout(BuildContext context) async {
    try {
      await authService.logout();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to logout.')),
      );
    }
  }

  Future<void> confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Log out?',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w700)),
          content: const Text('Are you sure you want to log out?',
              style: TextStyle(color: AppColors.muted)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.muted))),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Log out',
                    style: TextStyle(color: AppColors.red))),
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
    final savedName = metadata?['full_name'] ??
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
                const Text('ACCOUNT',
                    style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('Profile',
                    style: Theme.of(context).textTheme.headlineMedium),
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
                              colors: [AppColors.blue, AppColors.violet]),
                        ),
                        child: Center(
                            child: Text(initial,
                                style: const TextStyle(
                                    fontSize: 27,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white))),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            Text(email,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const SectionHeading(title: 'Preferences'),
                const SizedBox(height: 13),
                _buildMenuItem(
                  icon: Icons.track_changes_rounded,
                  title: 'My Goals',
                  onTap: () => _showComingSoon('My Goals screen coming soon.'),
                ),
                const SizedBox(height: 10),
                _buildNotificationItem(),
                const SizedBox(height: 10),
                _buildMenuItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () => _showComingSoon('Settings screen coming soon.'),
                ),
                const SizedBox(height: 10),
                _buildMenuItem(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  onTap: () => _showComingSoon('Help & Support coming soon.'),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => confirmLogout(context),
                    icon: const Icon(Icons.logout_rounded,
                        color: AppColors.red, size: 19),
                    label: const Text('Log out',
                        style: TextStyle(
                            color: AppColors.red,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.red.withValues(alpha: 0.05),
                      side: BorderSide(
                          color: AppColors.red.withValues(alpha: 0.27)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                const Center(
                    child: Text('HabitQuest',
                        style: TextStyle(
                            color: AppColors.faint,
                            fontSize: 12,
                            letterSpacing: 1.1))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildMenuItem(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
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
                    child: Text(title,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.faint, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      borderRadius: 17,
      child: Row(
        children: [
          _menuIcon(Icons.notifications_none_rounded),
          const SizedBox(width: 13),
          const Expanded(
              child: Text('Notifications',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600))),
          Switch.adaptive(
            value: notificationsEnabled,
            onChanged: (value) => setState(() => notificationsEnabled = value),
            activeTrackColor: AppColors.violet,
            activeThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFF363D48),
            inactiveThumbColor: AppColors.muted,
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
          borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: AppColors.blue, size: 20),
    );
  }
}
