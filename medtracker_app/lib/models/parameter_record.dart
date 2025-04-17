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
  });

  // Helper to determine status based on value and range
  ParameterStatus get status {
    // Handle cases where range has only one bound (low or high)
    if (value != null) {
      if (refRangeLow != null && refRangeHigh == null) { // Lower bound only (e.g., > 30)
        return value! >= refRangeLow! ? ParameterStatus.normal : ParameterStatus.attention;
      } else if (refRangeLow == null && refRangeHigh != null) { // Upper bound only (e.g., < 10)
        return value! <= refRangeHigh! ? ParameterStatus.normal : ParameterStatus.attention;
      } else if (refRangeLow != null && refRangeHigh != null) { // Both bounds exist
        if (value! < refRangeLow!) {
          return ParameterStatus.attention;
        }
        if (value! > refRangeHigh!) {
          return ParameterStatus.attention;
        }
        // Consider adding a 'watch' zone here if desired
        return ParameterStatus.normal;
      }
    }
    // If value is null or range is completely undefined, status is unknown
    return ParameterStatus.unknown;
    // TODO: Handle non-numeric values if they represent status (e.g., 'Negativo')
  }

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
    };
  }

  // Method to create ParameterRecord from a Map
  factory ParameterRecord.fromMap(Map<String, dynamic> map) {
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