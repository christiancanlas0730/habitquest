import 'package:flutter/material.dart';

import '../widgets/premium_ui.dart';

class HelpFaq {
  const HelpFaq({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}

const helpFaqs = <HelpFaq>[
  HelpFaq(
    category: 'Habits',
    question: 'How do I create or change a habit?',
    answer:
        'Use the habit add flow to enter a name, category, and schedule. Existing habits can be edited or deleted from their habit details. A saved habit is needed before you can configure its reminder preference.',
  ),
  HelpFaq(
    category: 'Habits',
    question: 'How do I record a habit completion?',
    answer:
        'Use the completion action on a habit in the app. Completion is recorded through the app service and the returned completion date is used for history. If the account completion timezone is unavailable, completion may be blocked until it can be resolved.',
  ),
  HelpFaq(
    category: 'Tracking',
    question: 'How are streaks calculated?',
    answer:
        'Streaks depend on the habit schedule, recorded completion information, and account date availability. Some date-based streak displays are unavailable when the account date or required habit dates cannot be resolved.',
  ),
  HelpFaq(
    category: 'Tracking',
    question: 'Why is today or a date-based statistic unavailable?',
    answer:
        'Date-based summaries need a valid account completion timezone and saved habit creation dates. Check the completion timezone in Profile and refresh the screen. The app does not use your device date as a substitute for an unavailable account date.',
  ),
  HelpFaq(
    category: 'Tracking',
    question: 'What does the calendar show?',
    answer:
        'Calendar markers come from recorded completion dates. Select a marked day to see the habits recorded for that date. The selected history date is separate from the account-local today indicator.',
  ),
  HelpFaq(
    category: 'Tracking',
    question: 'What do Statistics include?',
    answer:
        'Statistics show recorded completion history and habit totals. Weekly and monthly scheduled summaries require a resolved account date and saved habit creation timestamps; otherwise those date-based summaries are shown as unavailable.',
  ),
  HelpFaq(
    category: 'Reminders',
    question: 'Why did a habit reminder not notify me?',
    answer:
        'This build saves reminder preferences but does not schedule operating-system or browser notifications. A saved reminder time is a preference, not a notification delivery guarantee.',
  ),
  HelpFaq(
    category: 'Reminders',
    question: 'Why does a reminder preference say it is temporary?',
    answer:
        'Cloud persistence for reminder preferences depends on the reminders migration being available. When it is unavailable, the app labels the changed preference as temporary; do not assume it was saved to your account.',
  ),
  HelpFaq(
    category: 'Focus',
    question: 'How do I use the focus timer?',
    answer:
        'Choose one of the preset durations or enter a custom duration from 1 to 180 minutes, then start the timer. You can pause and reset it. The timer state is kept in the current screen and is not saved as a session history.',
  ),
  HelpFaq(
    category: 'Account',
    question: 'Where can I change my completion timezone?',
    answer:
        'Open Profile and use the completion timezone preference. Enter a valid IANA timezone such as Asia/Singapore or UTC. The app reports an error if the setting cannot be loaded or saved.',
  ),
  HelpFaq(
    category: 'Account',
    question: 'How do I sign out?',
    answer:
        'Open Profile, choose Log out, and confirm. If sign-out fails, the app displays an error so you can try again.',
  ),
  HelpFaq(
    category: 'Troubleshooting',
    question: 'A screen failed to load. What should I try?',
    answer:
        'Use the screen refresh or retry action when available. Check that your connection is working and retry. If the problem continues, this build does not provide a configured support email, phone number, or external support link.',
  ),
  HelpFaq(
    category: 'Troubleshooting',
    question: 'Why did a save fail or show an error?',
    answer:
        'A failed save is not treated as successful. Check your connection and try the action again. If an error remains, the app may not be able to reach or update the required service.',
  ),
];

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';

  List<String> get _categories => [
    'All',
    ...helpFaqs.map((faq) => faq.category).toSet(),
  ];

  List<HelpFaq> get _visibleFaqs {
    final query = _query.trim().toLowerCase();
    return helpFaqs.where((faq) {
      final matchesCategory =
          _selectedCategory == 'All' || faq.category == _selectedCategory;
      final matchesQuery =
          query.isEmpty ||
          faq.question.toLowerCase().contains(query) ||
          faq.answer.toLowerCase().contains(query) ||
          faq.category.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faqs = _visibleFaqs;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Help & Support')),
      body: PremiumBackground(
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  'Find answers about the features available in this build.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search help topics',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 3,
                  children: [
                    for (final category in _categories)
                      ChoiceChip(
                        label: Text(category),
                        selected: _selectedCategory == category,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = category),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: faqs.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No help topics match your search.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        itemCount: faqs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) => _FaqCard(
                          key: ValueKey(faqs[index].question),
                          faq: faqs[index],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  const _FaqCard({super.key, required this.faq});

  final HelpFaq faq;

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: EdgeInsets.zero,
    borderRadius: 17,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        collapsedIconColor: AppColors.muted,
        iconColor: AppColors.blue,
        title: Text(
          faq.question,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          faq.category,
          style: const TextStyle(color: AppColors.blue, fontSize: 11),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              faq.answer,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
