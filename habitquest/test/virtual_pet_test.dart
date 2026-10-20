import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/virtual_pet.dart';

void main() {
  group('pet growth', () {
    test('missing or invalid verified counts do not unlock pet growth', () {
      expect(PetGrowth.fromVerifiedCount(null).completionCount, 0);
      expect(PetGrowth.fromVerifiedCount(-1).completionCount, 0);
      expect(PetGrowth.fromVerifiedCount(double.nan).completionCount, 0);
      expect(PetGrowth.fromVerifiedCount(15).stage, 'Explorer');
    });

    test('levels and growth stages advance at explicit boundaries', () {
      expect(const PetGrowth(completionCount: 4).levelProgress, 0.8);
      expect(const PetGrowth(completionCount: 5).level, 2);
      expect(const PetGrowth(completionCount: 5).stage, 'Sprout');
      expect(const PetGrowth(completionCount: 15).stage, 'Explorer');
      expect(const PetGrowth(completionCount: 30).stage, 'Guardian');
    });
  });

  group('pet cosmetics and preferences', () {
    test('cosmetic unlocks follow their completion thresholds', () {
      final leafCrown = PetCosmetic.all[0];
      final starGlasses = PetCosmetic.all[1];
      final auroraCharm = PetCosmetic.all[2];

      expect(
        leafCrown.isUnlockedFor(const PetGrowth(completionCount: 2)),
        isFalse,
      );
      expect(
        leafCrown.isUnlockedFor(const PetGrowth(completionCount: 3)),
        isTrue,
      );
      expect(
        starGlasses.isUnlockedFor(const PetGrowth(completionCount: 9)),
        isFalse,
      );
      expect(
        starGlasses.isUnlockedFor(const PetGrowth(completionCount: 10)),
        isTrue,
      );
      expect(
        auroraCharm.isUnlockedFor(const PetGrowth(completionCount: 25)),
        isTrue,
      );
    });

    test('preferences parse defaults and can unequip an accessory', () {
      expect(PetPreferences.fromMap(null).name, 'Mochi');
      final equipped = PetPreferences.fromMap({
        'pet_name': 'Mochi',
        'equipped_item_key': 'leaf_crown',
      });

      expect(equipped.copyWith(unequip: true).equippedItemKey, isNull);
      expect(equipped.copyWith(name: 'Pip').name, 'Pip');
      expect(equipped.copyWith(name: 'Pip').equippedItemKey, 'leaf_crown');
    });
  });
}
