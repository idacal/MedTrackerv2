/// Represents a single medical parameter record from an exam.
class ParameterRecord {
  final int? id; // Nullable for records not yet saved to DB
  final int examRecordId; // Foreign key to link to ExamRecord
  final String category;
  final String parameterName;
  final double? value;
  final double? refRangeLow;
  final double? refRangeHigh;
  final String? refOriginal;
  final DateTime date; // Date specific to the parameter
  final ParameterStatus status; // Added status field

  ParameterRecord({
    this.id,
    required this.examRecordId,
    required this.category,
    required this.parameterName,
    this.value,
    this.refRangeLow,
    this.refRangeHigh,
    this.refOriginal,
    required this.date,
    required this.status, // Require status in constructor
  });

  // Method to convert ParameterRecord to a Map for DB insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examRecordId': examRecordId,
      'category': category,
      'parameterName': parameterName,
      'value': value,
      'refRangeLow': refRangeLow,
      'refRangeHigh': refRangeHigh,
      'refOriginal': refOriginal,
      'date': date.toIso8601String(),
      'status': status.name, // Store enum name as string
    };
  }

  // Method to create ParameterRecord from a Map
  factory ParameterRecord.fromMap(Map<String, dynamic> map) {
    // Helper to safely get enum by name, defaulting to unknown
    ParameterStatus getStatusByName(String? name) {
      if (name == null) return ParameterStatus.unknown;
      try {
        return ParameterStatus.values.byName(name);
      } catch (_) {
        return ParameterStatus.unknown; // Handle if name doesn't match enum
      }
    }

    return ParameterRecord(
      id: map['id'],
      examRecordId: map['examRecordId'],
      category: map['category'],
      parameterName: map['parameterName'],
      value: map['value'],
      refRangeLow: map['refRangeLow'],
      refRangeHigh: map['refRangeHigh'],
      refOriginal: map['refOriginal'],
      date: DateTime.parse(map['date']),
      status: getStatusByName(map['status']), // Parse status from string
    );
  }
}

/// Enum to represent the status of a parameter based on reference ranges.
enum ParameterStatus {
  normal, // Within range or meets single bound (Green)
  watch, // Borderline or slightly out (Amber) - Not implemented yet
  attention, // Out of range or fails single bound (Red)
  unknown // Value or range not available/comparable
} 