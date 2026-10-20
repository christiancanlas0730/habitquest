class Habit {
  final String id;
  final String userId;
  final String name;
  final String category;
  final String frequency;
  final int streak;
  final String? lastCompletedDate;
  final DateTime? createdAt;

  Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.frequency,
    required this.streak,
    this.lastCompletedDate,
    this.createdAt,
  });

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      name: map['name'] ?? '',
      category: map['category'] ?? 'Other',
      frequency: map['frequency'] ?? 'Daily',
      streak: map['streak'] ?? 0,
      lastCompletedDate: map['last_completed_date'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'category': category,
      'frequency': frequency,
      'streak': streak,
      'last_completed_date': lastCompletedDate,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}