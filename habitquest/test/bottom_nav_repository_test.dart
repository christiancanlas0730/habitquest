import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/gamification.dart';
import 'package:habit__quest/models/account_date.dart';
import 'package:habit__quest/models/habit.dart';
import 'package:habit__quest/models/habit_completion.dart';
import 'package:habit__quest/models/virtual_pet.dart';
import 'package:habit__quest/services/auth_service.dart';
import 'package:habit__quest/services/habit_repository.dart';
import 'package:habit__quest/widgets/bottom_nav.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class _PetRepository implements PetRepository {
  int loadCalls = 0;

  @override
  Future<VirtualPetSnapshot> getVirtualPetSnapshot() async {
    loadCalls++;
    return const VirtualPetSnapshot(
      growth: PetGrowth(completionCount: 0),
      preferences: PetPreferences(),
      cloudPersistenceAvailable: true,
    );
  }

  @override
  Future<bool> savePetPreferences(PetPreferences preferences) async => true;
}

class _NavigationHabitRepository
    implements HabitHomeRepository, HabitBrowserRepository {
  @override
  String? get currentUserEmail => null;

  @override
  Future<List<Habit>> getHabits() async => const [];

  @override
  Future<List<Habit>> reconcileCompletionHistory(List<Habit> habits) async =>
      habits;

  @override
  Future<bool> hasCompletionTimeZone() async => true;

  @override
  Future<String?> getCompletionTimeZone() async => 'UTC';

  @override
  Future<CompletionTimeZoneSettings?> getCompletionTimeZoneSettings() async =>
      CompletionTimeZoneSettings(
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 1, 1),
        nextChangeAt: DateTime.utc(2026, 1, 31),
      );

  @override
  Future<GamificationProgress> getGamificationProgress({
    required Iterable<String> habitIds,
    DateTime? localDate,
  }) async => GamificationProgress(
    totalXp: 0,
    unlockedKeys: {},
    completedToday: localDate == null ? null : 0,
  );

  @override
  Future<CompletionHistorySnapshot> loadCompletionHistory() async =>
      const CompletionHistorySnapshot(habits: [], completions: []);

  @override
  Future<List<HabitCompletion>> getCompletionHistory(
    Iterable<String> habitIds,
  ) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthRepository implements AuthRepository {
  @override
  User? getCurrentUser() => null;

  @override
  bool isLoggedIn() => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileRepository implements ProfileRepository {
  @override
  Future<String?> getCompletionTimeZone() async => 'UTC';

  @override
  Future<CompletionTimeZoneSettings?> getCompletionTimeZoneSettings() async =>
      CompletionTimeZoneSettings(
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 1, 1),
        nextChangeAt: DateTime.utc(2026, 1, 31),
      );

  @override
  Future<CompletionTimeZoneSettings> setCompletionTimeZone(
    String timeZone,
  ) async =>
      (await getCompletionTimeZoneSettings())!;
}

void main() {
  testWidgets('bottom destinations map to screens and Profile opens Pet Garden', (
    tester,
  ) async {
    final petRepository = _PetRepository();
    final habitRepository = _NavigationHabitRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: BottomNav(
          habitRepository: habitRepository,
          completionRepository: habitRepository,
          petRepository: petRepository,
          authRepository: _AuthRepository(),
          profileRepository: _ProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    NavigationBar navigationBar() => tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(
      navigationBar().destinations.map((destination) => destination.label),
      ['Home', 'Habits', 'Add', 'Calendar', 'Profile'],
    );
    expect(navigationBar().destinations[2].label, 'Add');
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    expect(petRepository.loadCalls, 0);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Habits'),
      ),
    );
    await tester.pumpAndSettle();
    expect(navigationBar().selectedIndex, 1);
    expect(find.text('My Habits'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Add'),
      ),
    );
    await tester.pumpAndSettle();
    expect(navigationBar().selectedIndex, 1);
    expect(find.text('Create habit'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Calendar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(navigationBar().selectedIndex, 3);
    expect(find.text('YOUR HISTORY'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(navigationBar().selectedIndex, 0);
    await tester.ensureVisible(find.text('Stats'));
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(
      find.text('A clear view of the progress your habits currently record.'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    expect(navigationBar().selectedIndex, 4);
    expect(find.text('Pet Garden'), findsOneWidget);
    await tester.tap(find.text('Pet Garden'));
    await tester.pumpAndSettle();
    expect(petRepository.loadCalls, 1);
    expect(find.text('Pet Garden'), findsOneWidget);
    expect(find.text('Pet accessories'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('My Goals'), findsOneWidget);
    expect(petRepository.loadCalls, 1);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Add'),
      ),
    );
    await tester.pumpAndSettle();
    expect(navigationBar().selectedIndex, 4);
    expect(find.text('Create habit'), findsOneWidget);
  });
}
