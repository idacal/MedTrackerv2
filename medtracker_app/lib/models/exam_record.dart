/// Represents metadata for a loaded exam file.
class ExamRecord {
  final int? id; // Nullable for records not yet saved to DB
  final String fileName;
  final DateTime importDate;

  ExamRecord({
    this.id,
    required this.fileName,
    required this.importDate,
  });

  // Method to convert ExamRecord to a Map for DB insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'importDate': importDate.toIso8601String(), // Store dates as ISO8601 strings
    };
  }

  // Method to create ExamRecord from a Map (e.g., when reading from DB)
  factory ExamRecord.fromMap(Map<String, dynamic> map) {
    return ExamRecord(
      id: map['id'],
      fileName: map['fileName'],
      importDate: DateTime.parse(map['importDate']),
    );
  }
} 