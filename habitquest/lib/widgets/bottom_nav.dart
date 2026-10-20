import 'package:flutter/material.dart';
import '../screens/calendar_history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/habits_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/add_habit_screen.dart';
import '../services/auth_service.dart';
import '../services/habit_repository.dart';
import 'premium_ui.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({
    super.key,
    this.habitRepository,
    this.completionRepository,
    this.petRepository,
    this.authRepository,
    this.profileRepository,
    this.reminderRepository,
    this.moodRepository,
  });

  final HabitRepository? habitRepository;
  final HabitHomeRepository? completionRepository;
  final PetRepository? petRepository;
  final AuthRepository? authRepository;
  final ProfileRepository? profileRepository;
  final ReminderRepository? reminderRepository;
  final MoodJournalRepository? moodRepository;

  HabitBrowserRepository? get browserRepository =>
      habitRepository is HabitBrowserRepository
      ? habitRepository as HabitBrowserRepository
      : null;

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int selectedIndex = 0;

  late List<Widget> screens = [
    HomeScreen(repository: widget.completionRepository),
    HabitsScreen(repository: widget.habitRepository),
    CalendarHistoryScreen(repository: widget.browserRepository),
    ProfileScreen(
      authRepository: widget.authRepository,
      repository: widget.profileRepository,
      reminderRepository: widget.reminderRepository,
      moodRepository: widget.moodRepository,
      petRepository: widget.petRepository,
    ),
  ];

  Future<void> _openAddHabit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddHabitScreen(repository: widget.habitRepository),
      ),
    );
    if (!mounted) return;
    setState(() {
      screens[0] = HomeScreen(
        key: UniqueKey(),
        repository: widget.completionRepository,
      );
      screens[1] = HabitsScreen(
        key: UniqueKey(),
        repository: widget.habitRepository,
      );
    });
  }

  void changeScreen(int index) {
    if (index == 2) {
      _openAddHabit();
      return;
    }
    if (index == selectedIndex) return;
    setState(() {
      selectedIndex = index;
      if (index == 0) {
        screens[0] = HomeScreen(
          key: UniqueKey(),
          repository: widget.completionRepository,
        );
      }
      if (index == 1) {
        screens[1] = HabitsScreen(
          key: UniqueKey(),
          repository: widget.habitRepository,
        );
      }
      if (index == 3) {
        screens[2] = CalendarHistoryScreen(
          key: UniqueKey(),
          repository: widget.browserRepository,
        );
      }
      if (index == 4) {
        screens[3] = ProfileScreen(
          key: UniqueKey(),
          authRepository: widget.authRepository,
          repository: widget.profileRepository,
          reminderRepository: widget.reminderRepository,
          moodRepository: widget.moodRepository,
          petRepository: widget.petRepository,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenIndex = selectedIndex < 2 ? selectedIndex : selectedIndex - 1;
    return Scaffold(
      body: IndexedStack(index: screenIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xEE0D1118),
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width > 800
                    ? 680
                    : double.infinity,
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: 70,
                  backgroundColor: Colors.transparent,
                  indicatorColor: AppColors.violet.withValues(alpha: 0.19),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    return TextStyle(
                      color: states.contains(WidgetState.selected)
                          ? AppColors.text
                          : AppColors.faint,
                      fontSize: 10,
                      fontWeight: states.contains(WidgetState.selected)
                          ? FontWeight.w600
                          : FontWeight.w500,
                    );
                  }),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    return IconThemeData(
                      color: states.contains(WidgetState.selected)
                          ? AppColors.blue
                          : AppColors.faint,
                      size: 21,
                    );
                  }),
                ),
                child: NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: changeScreen,
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.checklist_outlined),
                      selectedIcon: Icon(Icons.checklist_rounded),
                      label: 'Habits',
                    ),
                    const NavigationDestination(
                      icon: _AddNavIcon(),
                      selectedIcon: _AddNavIcon(),
                      label: 'Add',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month_rounded),
                      label: 'Calendar',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      selectedIcon: Icon(Icons.person_rounded),
                      label: 'Profile',
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
}

class _AddNavIcon extends StatelessWidget {
  const _AddNavIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: [AppColors.violet, AppColors.blue],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: const Icon(Icons.add_rounded, color: Colors.white, size: 25),
  );
}
