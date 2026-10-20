import 'package:flutter/material.dart';
import '../screens/calendar_history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/habits_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/add_habit_screen.dart';
import 'premium_ui.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int selectedIndex = 0;

  late List<Widget> screens = [
    const HomeScreen(),
    const HabitsScreen(),
    const CalendarHistoryScreen(),
    ProfileScreen(),
  ];

  int get _screenIndex => selectedIndex < 2 ? selectedIndex : selectedIndex - 1;

  Future<void> _openAddHabit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddHabitScreen()),
    );
    if (!mounted) return;
    setState(() {
      screens[0] = HomeScreen(key: UniqueKey());
      screens[1] = HabitsScreen(key: UniqueKey());
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
      if (index == 0) screens[0] = HomeScreen(key: UniqueKey());
      if (index == 1) screens[1] = HabitsScreen(key: UniqueKey());
      if (index == 3) screens[2] = CalendarHistoryScreen(key: UniqueKey());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _screenIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xEE0D1118),
          border: Border(top: BorderSide(color: AppColors.border)),
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
              NavigationDestination(
                icon: _AddNavIcon(selected: false),
                selectedIcon: _AddNavIcon(selected: true),
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
    );
  }
}

class _AddNavIcon extends StatelessWidget {
  const _AddNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 37,
      height: 37,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.blue, AppColors.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.blue.withValues(alpha: selected ? 0.38 : 0.22),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 25),
    );
  }
}
