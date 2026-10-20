import 'package:flutter/material.dart';
import '../services/habit_service.dart';
import '../widgets/premium_ui.dart';

class AddHabitScreen extends StatefulWidget {
  const AddHabitScreen({super.key});

  @override
  State<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends State<AddHabitScreen> {
  final HabitService habitService = HabitService();
  final TextEditingController nameController = TextEditingController();
  String selectedCategory = 'Personal';
  String selectedFrequency = 'Every day';
  bool isLoading = false;

  final List<String> categories = ['Study', 'Health', 'Fitness', 'Personal'];
  final List<String> frequencies = [
    'Every day',
    'Weekdays',
    'Weekends',
    'Once a week',
    'Twice a week',
    'Once a month',
  ];

  Future<void> addHabit() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      showMessage('Please enter a habit name.');
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      await habitService.addHabit(
        name: name,
        category: selectedCategory,
        frequency: selectedFrequency,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      showMessage('Failed to add habit:\n$e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.text),
                    ),
                    const Expanded(
                      child: Text('Create a habit',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
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
                          gradient: const LinearGradient(
                              colors: [AppColors.blue, AppColors.violet]),
                        ),
                        child: const Icon(Icons.add_task_rounded,
                            color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('A little, every day.',
                                style: TextStyle(
                                    color: AppColors.text,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 5),
                            Text('Choose a routine that moves you forward.',
                                style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                    height: 1.35)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                const _FieldLabel(
                    title: 'Habit name',
                    caption: 'Give your routine a clear name.'),
                const SizedBox(height: 10),
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: premiumInputDecoration(
                      hintText: 'e.g. Read for 20 minutes',
                      prefixIcon: Icons.edit_note_rounded),
                ),
                const SizedBox(height: 24),
                const _FieldLabel(
                    title: 'Category',
                    caption: 'Pick the icon that fits your habit.'),
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
                    caption: 'Choose how often you want to do it.'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedFrequency,
                  decoration: premiumInputDecoration(
                      hintText: 'Choose a frequency',
                      prefixIcon: Icons.repeat_rounded),
                  dropdownColor: AppColors.surfaceRaised,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.muted),
                  items: frequencies.map((frequency) {
                    return DropdownMenuItem<String>(
                        value: frequency, child: Text(frequency));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedFrequency = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 31),
                GradientActionButton(
                  label: 'Create habit',
                  icon: Icons.arrow_forward_rounded,
                  isLoading: isLoading,
                  onPressed: isLoading ? null : addHabit,
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
        Text(title,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(caption,
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}
