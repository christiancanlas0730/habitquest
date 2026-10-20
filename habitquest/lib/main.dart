import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/app_config.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/premium_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.isConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl!,
      publishableKey: config.supabasePublishableKey!,
    );
    runApp(const HabitQuest());
  } else {
    runApp(const HabitQuestConfigurationRequired());
  }
}

/// Shows local setup instructions without contacting a Supabase project.
class HabitQuestConfigurationRequired extends StatelessWidget {
  const HabitQuestConfigurationRequired({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'HabitQuest',
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HabitQuest', style: TextStyle(fontSize: 30)),
                  SizedBox(height: 16),
                  Text('Supabase is not configured for this local build.'),
                  SizedBox(height: 12),
                  SelectableText(
                    'Run with --dart-define=SUPABASE_URL=https://<project>.supabase.co '
                    '--dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>. '
                    'Keep these values in your local launch configuration and out of source control.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class HabitQuest extends StatelessWidget {
  const HabitQuest({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.hasError
            ? auth.currentSession
            : snapshot.data?.session;
        final initialSignedOut =
            !snapshot.hasError &&
            snapshot.data?.event == AuthChangeEvent.initialSession &&
            session == null;

        return MaterialApp(
          key: ValueKey(session?.user.id),
          debugShowCheckedModeBanner: false,
          title: 'HabitQuest',
          theme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.violet,
              brightness: Brightness.dark,
              surface: AppColors.surface,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: AppColors.background,
            fontFamily: 'Roboto',
            textTheme: const TextTheme(
              headlineMedium: TextStyle(
                color: AppColors.text,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
              titleLarge: TextStyle(
                color: AppColors.text,
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
              bodyLarge: TextStyle(color: AppColors.text, fontSize: 15),
              bodyMedium: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.text,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: true,
            ),
            inputDecorationTheme: InputDecorationTheme(
              hintStyle: const TextStyle(color: AppColors.faint),
              labelStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor: const Color(0xAA171C25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.blue, width: 1.4),
              ),
            ),
            snackBarTheme: const SnackBarThemeData(
              backgroundColor: AppColors.surfaceRaised,
              contentTextStyle: TextStyle(color: AppColors.text),
              behavior: SnackBarBehavior.floating,
            ),
          ),
          home: session != null
              ? const BottomNav()
              : initialSignedOut
              ? SplashScreen(
                  onGetStarted: (context) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                )
              : const LoginScreen(),
        );
      },
    );
  }
}
