class PetGrowth {
  const PetGrowth({required this.completionCount, this.isAvailable = true});

  /// Uses only a server-provided verified count. Missing or invalid values do
  /// not fall back to client-visible history, which may include legacy rows.
  factory PetGrowth.fromVerifiedCount(Object? value) => value is num &&
          value.isFinite &&
          value >= 0
      ? PetGrowth(completionCount: value.toInt())
      : const PetGrowth(completionCount: 0, isAvailable: false);

  final int completionCount;
  final bool isAvailable;

  int get level => completionCount ~/ 5 + 1;
  int get completionsIntoLevel => completionCount % 5;
  double get levelProgress => completionsIntoLevel / 5;
  int get completionsToNextLevel => 5 - completionsIntoLevel;

  String get stage {
    if (completionCount >= 30) return 'Guardian';
    if (completionCount >= 15) return 'Explorer';
    if (completionCount >= 5) return 'Sprout';
    return 'Seedling';
  }
}

class PetCosmetic {
  const PetCosmetic({
    required this.key,
    required this.name,
    required this.description,
    required this.emoji,
    required this.completionRequirement,
  });

  final String key;
  final String name;
  final String description;
  final String emoji;
  final int completionRequirement;

  bool isUnlockedFor(PetGrowth growth) =>
      growth.completionCount >= completionRequirement;

  static const all = [
    PetCosmetic(
      key: 'leaf_crown',
      name: 'Leaf crown',
      description: 'A tiny crown for a growing sprout.',
      emoji: '🍃',
      completionRequirement: 3,
    ),
    PetCosmetic(
      key: 'star_glasses',
      name: 'Star glasses',
      description: 'Shine through every new quest.',
      emoji: '⭐',
      completionRequirement: 10,
    ),
    PetCosmetic(
      key: 'aurora_charm',
      name: 'Aurora charm',
      description: 'A glow earned through steady progress.',
      emoji: '🌙',
      completionRequirement: 25,
    ),
  ];
}

class PetPreferences {
  const PetPreferences({this.name = 'Mochi', this.equippedItemKey});

  final String name;
  final String? equippedItemKey;

  factory PetPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PetPreferences();
    return PetPreferences(
      name: map['pet_name']?.toString() ?? 'Mochi',
      equippedItemKey: map['equipped_item_key']?.toString(),
    );
  }

  PetPreferences copyWith({
    String? name,
    String? equippedItemKey,
    bool unequip = false,
  }) => PetPreferences(
    name: name ?? this.name,
    equippedItemKey: unequip ? null : equippedItemKey ?? this.equippedItemKey,
  );
}

class VirtualPetSnapshot {
  const VirtualPetSnapshot({
    required this.growth,
    required this.preferences,
    required this.cloudPersistenceAvailable,
  });

  final PetGrowth growth;
  bool get growthAvailable => growth.isAvailable;
  final PetPreferences preferences;
  final bool cloudPersistenceAvailable;
}
