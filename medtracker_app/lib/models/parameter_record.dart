import 'package:intl/intl.dart'; // Add import for NumberFormat

/// Represents a single medical parameter record from an exam.
class ParameterRecord {
  final int? id; // Nullable for records not yet saved to DB
  final int examRecordId; // Foreign key to link to ExamRecord
  final String category;
  final String parameterName;
  final double? value;
  final String? resultString;
  final double? refRangeLow;
  final double? refRangeHigh;
  final String? refOriginal;
  final DateTime date; // Date specific to the parameter
  final ParameterStatus status; // Added status field
  final String? unit; // Optional unit (e.g., "mg/dL")
  final String? description; // NEW: Parameter description
  final String? recommendation; // NEW: Specific recommendation

  ParameterRecord({
    this.id,
    required this.examRecordId,
    required this.category,
    required this.parameterName,
    this.value,
    this.resultString,
    this.refRangeLow,
    this.refRangeHigh,
    this.refOriginal,
    required this.date,
    required this.status, // Require status in constructor
    this.unit,
    this.description, // Added
    this.recommendation, // Added
  });

  // Method to convert ParameterRecord to a Map for DB insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examRecordId': examRecordId,
      'category': category,
      'parameterName': parameterName,
      'value': value,
      'resultString': resultString,
      'refRangeLow': refRangeLow,
      'refRangeHigh': refRangeHigh,
      'refOriginal': refOriginal,
      'date': date.toIso8601String(),
      'status': status.name, // Store enum name as string
      'unit': unit,
      'description': description,
      'recommendation': recommendation,
    };
  }

  // Method to create ParameterRecord from a Map
  factory ParameterRecord.fromMap(Map<String, dynamic> map) {
    // Handle potential database nulls safely
    final String? statusString = map['status'] as String?;
    // Try to parse the status string, default to unknown if invalid/null
    final ParameterStatus status = ParameterStatus.values.firstWhere(
      (e) => e.name == statusString,
      orElse: () => ParameterStatus.unknown, 
    );

    // --- Debug Print --- 
    if (map.containsKey('glossary_description') || map.containsKey('glossary_recommendation')) {
       print("DEBUG ParameterRecord.fromMap for [${map['parameterName']}]: ");
       print("  - glossary_description: ${map['glossary_description']}");
       print("  - glossary_recommendation: ${map['glossary_recommendation']}");
       print("  - Original description: ${map['description']}");
       print("  - Original recommendation: ${map['recommendation']}");
    }
    // -------------------

    // --- Prioritize glossary data if available --- 
    final String? description = map['glossary_description'] as String? ?? map['description'] as String?;
    final String? recommendation = map['glossary_recommendation'] as String? ?? map['recommendation'] as String?;
    // ---------------------------------------------

    // --- Debug Print after prioritization ---
     if (map.containsKey('glossary_description') || map.containsKey('glossary_recommendation')) {
         print("  - FINAL description: $description");
         print("  - FINAL recommendation: $recommendation");
     }
    // ---------------------------------------

    return ParameterRecord(
      id: map['id'] as int?,
      examRecordId: map['examRecordId'] as int? ?? 0, // Provide default if needed
      category: map['category'] as String? ?? '', // Provide default if needed
      parameterName: map['parameterName'] as String? ?? '', // Provide default
      value: map['value'] as double?,
      resultString: map['resultString'] as String?,
      refRangeLow: map['refRangeLow'] as double?,
      refRangeHigh: map['refRangeHigh'] as double?,
      refOriginal: map['refOriginal'] as String?,
      // Safely parse the date string, handle null or invalid format
      date: map['date'] != null ? (DateTime.tryParse(map['date'] as String) ?? DateTime.now()) : DateTime.now(),
      status: status,
      unit: map['unit'] as String?,
      description: description, // Use the prioritized value
      recommendation: recommendation, // Use the prioritized value
    );
  }

  // Helper to get the display value (prioritizes numeric)
  String get displayValue {
    if (value != null) {
      // Consider using a NumberFormat instance here if needed
      final formatter = NumberFormat("#,##0.##");
      return formatter.format(value);
    }
    if (resultString != null && resultString!.isNotEmpty) {
      return resultString!;
    }
    return 'N/A'; // Fallback if both are null/empty
  }
}

/// Enum to represent the status of a parameter based on reference ranges.
enum ParameterStatus {
  normal, // Within range or meets single bound (Green)
  watch, // Borderline or slightly out (Amber) - Not implemented yet
  attention, // Out of range or fails single bound (Red)
  unknown // Value or range not available/comparable
} 