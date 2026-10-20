/// A completion date returned by the server after it applies the account's
/// stored timezone. The client never supplies the date used for a new write.
class CompletionDatePolicy {
  const CompletionDatePolicy._();

  static ServerCompletion parseServerCompletion(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid completion response.');
    }

    final rawDate = value['completed_on'];
    final isVerified = value['is_verified'];
    final inserted = value['inserted'];
    if (rawDate is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate) ||
        isVerified is! bool ||
        inserted is! bool) {
      throw const FormatException('Invalid completion response.');
    }

    final parts = rawDate.split('-').map(int.parse).toList();
    final date = DateTime.utc(parts[0], parts[1], parts[2]);
    if (_dateString(date) != rawDate) {
      throw const FormatException('Invalid completion response.');
    }
    return ServerCompletion(
      completedOn: date,
      isVerified: isVerified,
      inserted: inserted,
    );
  }

  static String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class ServerCompletion {
  const ServerCompletion({
    required this.completedOn,
    required this.isVerified,
    required this.inserted,
  });

  final DateTime completedOn;
  final bool isVerified;
  final bool inserted;

  String get completedOnString =>
      '${completedOn.year.toString().padLeft(4, '0')}-'
      '${completedOn.month.toString().padLeft(2, '0')}-'
      '${completedOn.day.toString().padLeft(2, '0')}';
}
