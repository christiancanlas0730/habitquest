import 'package:flutter/material.dart';
import '../widgets/premium_ui.dart';
import '../widgets/quest_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.onGetStarted});

  final ValueChanged<BuildContext> onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/habitquest-mountain-splash.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF17263A), AppColors.background],
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66101625),
                  Color(0x24101625),
                  Color(0xB8080A0F),
                ],
                stops: [0, 0.38, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Padding(
                padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    const QuestLogoMark(size: 122),
                    const SizedBox(height: 13),
                    const HabitQuestWordmark(fontSize: 39),
                    const SizedBox(height: 10),
                    const Text(
                      'Build Better Days',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFE4EBF5),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(flex: 4),
                    GradientActionButton(
                      label: 'Get Started',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () => onGetStarted(context),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'SMALL STEPS  ·  BETTER DAYS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB8C6D8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
