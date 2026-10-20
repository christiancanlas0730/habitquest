import 'package:flutter/material.dart';
import '../models/habit_form_validation.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import '../services/habit_repository.dart';
import '../widgets/premium_ui.dart';

class EditHabitScreen extends StatefulWidget {
  final Habit habit;
  final HabitRepository? repository;

  const EditHabitScreen({super.key, required this.habit, this.repository});

  @override
  State<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends State<EditHabitScreen> {
  late final HabitRepository habitService =
      widget.repository ?? HabitService();
  late TextEditingController nameController;
  late String selectedCategory;
  late String selectedFrequency;
  bool isLoading = false;
  bool _deletePending = false;

  final List<String> categories = Habit.supportedCategories;
  final List<String> frequencies = [
    'Every day',
    'Weekdays',
    'Weekends',
    'Once a week',
    'Twice a week',
    'Once a month',
  ];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.habit.name);
    selectedCategory = widget.habit.category;
    selectedFrequency = widget.habit.frequency;
    if (!categories.contains(selectedCategory)) selectedCategory = 'Personal';
    if (selectedFrequency == 'Daily') {
      selectedFrequency = 'Every day';
    } else if (selectedFrequency == 'Weekly') {
      selectedFrequency = 'Once a week';
    }
    if (!frequencies.contains(selectedFrequency)) {
      selectedFrequency = 'Every day';
    }
  }

  Future<void> updateHabit() async {
    if (isLoading) return;
    final name = nameController.text.trim();
    final validationError = HabitFormValidation.error(
      name: name,
      category: selectedCategory,
      frequency: selectedFrequency,
    );
    if (validationError != null) {
      showMessage(validationError);
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      final updatedHabit = await habitService.updateHabit(
        id: widget.habit.id,
        name: name,
        category: selectedCategory,
        frequency: selectedFrequency,
      );
      if (!mounted) return;
      Navigator.pop(context, updatedHabit);
    } catch (_) {
      if (!mounted) return;
      showMessage('Failed to update habit. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> deleteHabit() async {
    if (isLoading || _deletePending) return;
    _deletePending = true;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Delete habit?',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${widget.habit.name}"?',
            style: const TextStyle(color: AppColors.muted, height: 1.45),
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
                'Delete',
                style: TextStyle(color: AppColors.red),
              ),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true || !mounted) {
      _deletePending = false;
      return;
    }
    try {
      setState(() {
        isLoading = true;
      });
      await habitService.deleteHabit(widget.habit.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      _deletePending = false;
      showMessage('Failed to delete habit. Please try again.');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.text,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Edit habit',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 12),
                GlassCard(
                  glow: true,
                  padding: const EdgeInsets.all(19),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppColors.violet.withValues(alpha: 0.16),
                        ),
                        child: Icon(
                          habitCategoryIcon(widget.habit.category),
                          color: AppColors.blue,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.habit.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Update the routine to fit your rhythm.',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                const _FieldLabel(
                  title: 'Habit name',
                  caption: 'Keep the name short and specific.',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: premiumInputDecoration(
                    hintText: 'e.g. Read for 20 minutes',
                    prefixIcon: Icons.edit_note_rounded,
                  ),
                ),
                const SizedBox(height: 24),
                const _FieldLabel(
                  title: 'Category',
                  caption: 'Pick the icon that fits this habit.',
                ),
                const SizedBox(height: 11),
                CategorySelector(
                  categories: categories,
                  selectedCategory: selectedCategory,
                  onChanged: (category) =>
                      setState(() => selectedCategory = category),
                ),
                const SizedBox(height: 24),
                const _FieldLabel(
                  title: 'Frequency',
                  caption: 'Choose how often you want to do it.',
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedFrequency,
                  decoration: premiumInputDecoration(
                    hintText: 'Choose a frequency',
                    prefixIcon: Icons.repeat_rounded,
                  ),
                  dropdownColor: AppColors.surfaceRaised,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.muted,
                  ),
                  items: frequencies
                      .map(
                        (frequency) => DropdownMenuItem<String>(
                          value: frequency,
                          child: Text(frequency),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedFrequency = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 28),
                GradientActionButton(
                  label: 'Save changes',
                  icon: Icons.check_rounded,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : updateHabit,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : deleteHabit,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.red,
                      size: 19,
                    ),
                    label: const Text(
                      'Delete habit',
                      style: TextStyle(
                        color: AppColors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.red.withValues(alpha: 0.28),
                      ),
                      backgroundColor: AppColors.red.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
