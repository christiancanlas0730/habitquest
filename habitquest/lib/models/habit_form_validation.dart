import 'habit.dart';

/// Client-side guardrails that match the clean-install habits table checks.
class HabitFormValidation {
  const HabitFormValidation._();

  static String? error({
    required String name,
    required String category,
    required String frequency,
  }) {
    if (name.trim().isEmpty) return 'Please enter a habit name.';
    if (!Habit.supportedCategories.contains(category)) {
      return 'Choose a valid category.';
    }
    if (!Habit.supportedFrequencies.contains(frequency)) {
      return 'Choose a valid frequency.';
    }
    return null;
  }
}
