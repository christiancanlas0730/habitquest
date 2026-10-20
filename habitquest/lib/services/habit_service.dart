import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/habit.dart';

class HabitService {
  final SupabaseClient supabase = Supabase.instance.client;

  // Get the currently logged-in user's ID
  String get userId {
    return supabase.auth.currentUser!.id;
  }

  // Get all habits of the current user
  Future<List<Habit>> getHabits() async {
    try {
      final data = await supabase
          .from('habits')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return data
          .map<Habit>((item) => Habit.fromMap(item))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Add a new habit
  Future<void> addHabit({
    required String name,
    required String category,
    required String frequency,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      final session = supabase.auth.currentSession;

      print('CURRENT USER: ${user?.id}');
      print('CURRENT SESSION: ${session != null}');

      if (user == null || session == null) {
        throw Exception('User is not authenticated.');
      }

      await supabase.from('habits').insert({
        'user_id': user.id,
        'name': name,
        'category': category,
        'frequency': frequency,
        'streak': 0,
      });

      print('HABIT ADDED SUCCESSFULLY');
    } catch (e) {
      print('ADD HABIT ERROR: $e');
      rethrow;
    }
  }

  // Update a habit
  Future<void> updateHabit({
    required String id,
    required String name,
    required String category,
    required String frequency,
  }) async {
    try {
      await supabase
          .from('habits')
          .update({
            'name': name,
            'category': category,
            'frequency': frequency,
          })
          .eq('id', id)
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a habit
  Future<void> deleteHabit(String id) async {
    try {
      await supabase
          .from('habits')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  // Complete a habit for today
  Future<void> completeHabit(Habit habit) async {
    try {
      final now = DateTime.now();

      final today = DateTime(
        now.year,
        now.month,
        now.day,
      );

      // If already completed today, do nothing.
      if (habit.lastCompletedDate != null) {
        final lastCompleted = DateTime.tryParse(
          habit.lastCompletedDate!,
        );

        if (lastCompleted != null) {
          final lastDate = DateTime(
            lastCompleted.year,
            lastCompleted.month,
            lastCompleted.day,
          );

          if (lastDate == today) {
            return;
          }
        }
      }

      int newStreak = 1;

      // Check if the previous completion was yesterday.
      if (habit.lastCompletedDate != null) {
        final lastCompleted = DateTime.tryParse(
          habit.lastCompletedDate!,
        );

        if (lastCompleted != null) {
          final lastDate = DateTime(
            lastCompleted.year,
            lastCompleted.month,
            lastCompleted.day,
          );

          final difference = today.difference(lastDate).inDays;

          if (difference == 1) {
            // Consecutive day, so increase the streak.
            newStreak = habit.streak + 1;
          } else {
            // A day was missed, so start a new streak.
            newStreak = 1;
          }
        }
      }

      final todayString =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      await supabase
          .from('habits')
          .update({
            'streak': newStreak,
            'last_completed_date': todayString,
          })
          .eq('id', habit.id)
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }
}