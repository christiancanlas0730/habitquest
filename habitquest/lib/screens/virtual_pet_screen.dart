import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/virtual_pet.dart';
import '../services/habit_service.dart';
import '../services/habit_repository.dart';
import '../widgets/premium_ui.dart';

class VirtualPetScreen extends StatefulWidget {
  const VirtualPetScreen({super.key, this.repository});

  final PetRepository? repository;

  @override
  State<VirtualPetScreen> createState() => _VirtualPetScreenState();
}

class _VirtualPetScreenState extends State<VirtualPetScreen> {
  late final PetRepository _habitService = widget.repository ?? HabitService();
  VirtualPetSnapshot? _snapshot;
  PetPreferences _preferences = const PetPreferences();
  bool _loading = true;
  bool _reacting = false;
  bool _savingPreferences = false;
  int _loadGeneration = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPet();
  }

  Future<void> _loadPet() async {
    if (_savingPreferences) return;
    final generation = ++_loadGeneration;
    try {
      final snapshot = await _habitService.getVirtualPetSnapshot();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _snapshot = snapshot;
        _preferences = snapshot.preferences;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = _backendError(error, 'Your pet could not be loaded');
      });
    }
  }

  Future<void> _save(PetPreferences updated) async {
    final snapshot = _snapshot;
    if (snapshot == null || _savingPreferences) return;
    if (!snapshot.cloudPersistenceAvailable) {
      setState(() => _preferences = updated);
      _showMessage('Pet cloud sync is available after the pet migration.');
      return;
    }
    _loadGeneration++;
    setState(() => _savingPreferences = true);
    try {
      final saved = await _habitService.savePetPreferences(updated);
      if (!mounted) return;
      setState(() {
        _preferences = updated;
        _savingPreferences = false;
        if (!saved) {
          _snapshot = VirtualPetSnapshot(
            growth: snapshot.growth,
            preferences: updated,
            cloudPersistenceAvailable: false,
          );
        }
      });
      if (!saved) {
        _showMessage(
          'Saved for this visit. Cloud sync needs the pet migration.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _savingPreferences = false);
      _showMessage(_backendError(error, 'Could not save pet changes'));
    }
  }

  Future<void> _renamePet() async {
    final controller = TextEditingController(text: _preferences.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: const Text('Name your companion'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(hintText: 'Pet name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    await _save(_preferences.copyWith(name: name.trim()));
  }

  Future<void> _toggleCosmetic(PetCosmetic cosmetic) async {
    final equipped = _preferences.equippedItemKey == cosmetic.key;
    await _save(
      _preferences.copyWith(
        equippedItemKey: equipped ? null : cosmetic.key,
        unequip: equipped,
      ),
    );
  }

  void _react() {
    setState(() => _reacting = true);
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _reacting = false);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _backendError(Object error, String action) =>
      error is PostgrestException
      ? '$action (database error ${error.code ?? 'unknown'}). Retry after checking the backend.'
      : '$action (${error.runtimeType}). Retry after checking the connection.';

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pet Garden')),
      body: PremiumBackground(
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                )
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.pets_rounded,
                          color: AppColors.blue,
                          size: 42,
                        ),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _loadPet,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.blue,
                  backgroundColor: AppColors.surfaceRaised,
                  onRefresh: _loadPet,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      wide ? 32 : 20,
                      20,
                      wide ? 32 : 20,
                      40,
                    ),
                    children: [
                      const Text(
                        'YOUR COMPANION',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildPetCard()),
                            const SizedBox(width: 14),
                            Expanded(child: _buildGrowthCard()),
                          ],
                        )
                      else ...[
                        _buildPetCard(),
                        const SizedBox(height: 13),
                        _buildGrowthCard(),
                      ],
                      const SizedBox(height: 24),
                      const SectionHeading(title: 'Pet accessories'),
                      const SizedBox(height: 5),
                      const Text(
                        'Earn cosmetics by keeping your habits growing.',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 13),
                      for (final cosmetic in PetCosmetic.all) ...[
                        _CosmeticCard(
                          cosmetic: cosmetic,
                          growthAvailable: _snapshot!.growth.isAvailable,
                          unlocked: _snapshot!.growth.isAvailable &&
                              cosmetic.isUnlockedFor(_snapshot!.growth),
                          equipped:
                              _preferences.equippedItemKey == cosmetic.key,
                          onTap:
                              _snapshot!.growth.isAvailable &&
                                  cosmetic.isUnlockedFor(_snapshot!.growth) &&
                                  !_savingPreferences
                              ? () => _toggleCosmetic(cosmetic)
                              : null,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (!_snapshot!.cloudPersistenceAvailable) ...[
                        const SizedBox(height: 8),
                        GlassCard(
                          padding: const EdgeInsets.all(13),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                color: AppColors.orange,
                                size: 18,
                              ),
                              SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'Pet preferences are temporary until the pet migration is applied.',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPetCard() {
    final item = PetCosmetic.all.where(
      (cosmetic) => cosmetic.key == _preferences.equippedItemKey,
    );
    final accessory = item.isEmpty ? null : item.first;
    final petEmoji = !_snapshot!.growth.isAvailable
        ? '🐾'
        : switch (_snapshot!.growth.stage) {
      'Seedling' => '🐣',
      'Sprout' => '🐤',
      'Explorer' => '🦊',
      _ => '🦉',
    };
    return GlassCard(
      glow: true,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Rename pet',
              onPressed: _savingPreferences ? null : _renamePet,
              icon: _savingPreferences
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_rounded, color: AppColors.muted),
            ),
          ),
          GestureDetector(
            onTap: _react,
            child: AnimatedScale(
              scale: _reacting ? 1.13 : 1,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: Container(
                width: 190,
                height: 178,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.violet.withValues(alpha: 0.3),
                      AppColors.blue.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border.all(color: AppColors.border),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Positioned(
                      top: 27,
                      right: 35,
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.orange,
                        size: 17,
                      ),
                    ),
                    Text(petEmoji, style: const TextStyle(fontSize: 88)),
                    if (accessory != null)
                      Positioned(
                        top: 36,
                        right: 47,
                        child: Text(
                          accessory.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    if (_reacting)
                      const Positioned(
                        top: 18,
                        left: 36,
                        child: Text(
                          '♥',
                          style: TextStyle(color: AppColors.red, fontSize: 23),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            _reacting ? 'Yay, ${_preferences.name}!' : _preferences.name,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _snapshot!.growth.isAvailable
                ? _snapshot!.growth.stage
                : 'Growth unavailable',
            style: const TextStyle(
              color: AppColors.blue,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Tap your companion to say hello',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildGrowthCard() {
    final growth = _snapshot!.growth;
    if (!growth.isAvailable) {
      return GlassCard(
        padding: const EdgeInsets.all(18),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Growth unavailable', style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w700)),
            SizedBox(height: 9),
            Text('Verified completion totals could not be loaded, so level and cosmetic progress are hidden.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      );
    }
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.pets_rounded, color: AppColors.violet),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${growth.level}',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${growth.completionCount} habit completions',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: growth.levelProgress,
              minHeight: 9,
              backgroundColor: const Color(0xFF2A303B),
              valueColor: const AlwaysStoppedAnimation(AppColors.violet),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${growth.completionsIntoLevel} / 5 toward level ${growth.level + 1}',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              const Icon(Icons.eco_rounded, color: AppColors.green, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Each saved habit completion helps ${_preferences.name} grow.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  const _CosmeticCard({
    required this.cosmetic,
    required this.growthAvailable,
    required this.unlocked,
    required this.equipped,
    required this.onTap,
  });

  final PetCosmetic cosmetic;
  final bool growthAvailable;
  final bool unlocked;
  final bool equipped;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (unlocked ? AppColors.blue : AppColors.faint).withValues(
                alpha: 0.13,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              unlocked ? cosmetic.emoji : '🔒',
              style: const TextStyle(fontSize: 21),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cosmetic.name,
                  style: TextStyle(
                    color: unlocked ? AppColors.text : AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  !growthAvailable
                      ? 'Growth data unavailable'
                      : unlocked
                      ? cosmetic.description
                      : 'Unlock at ${cosmetic.completionRequirement} completions',
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          if (unlocked)
            TextButton(
              onPressed: onTap,
              child: Text(equipped ? 'Unequip' : 'Equip'),
            )
          else
            const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.faint,
              size: 18,
            ),
        ],
      ),
    );
  }
}
