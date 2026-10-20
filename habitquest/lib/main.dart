import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/bottom_nav.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/premium_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zgmeqaxlucacmxdsdyrl.supabase.co',
    publishableKey: 'sb_publishable_lZxyFS7XwHARUrMB1s6cfg_zHk10Zeg',
  );

  runApp(const HabitQuest());
}

class HabitQuest extends StatelessWidget {
  const HabitQuest({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: SplashScreen(
        onGetStarted: (context) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthGate()),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      return const BottomNav();
    }

    return const LoginScreen();
  }
}
