import 'package:intl/intl.dart'; // Add import for NumberFormat
import 'dart:convert'; // REMOVE 'package:'

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
  final List<String>? relatedParameters; // Added V7 from glossary
  final List<num>? relatedParametersPercentage; // Added V8 from glossary
  final List<String>? relatedParametersDescription; // Added V8 from glossary

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
    this.relatedParameters, // Add to constructor
    this.relatedParametersPercentage, // Add to constructor
    this.relatedParametersDescription, // Add to constructor
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
    final String? descriptionFromGlossary = map['glossary_description'] as String?;
    final String? recommendationFromGlossary = map['glossary_recommendation'] as String?;
    // ---------------------------------------------

    // --- Debug Print after prioritization ---
     if (map.containsKey('glossary_description') || map.containsKey('glossary_recommendation')) {
         print("  - FINAL description: $descriptionFromGlossary");
         print("  - FINAL recommendation: $recommendationFromGlossary");
     }
    // ---------------------------------------

    // --- NEW: Parse related parameters JSON --- 
    List<String>? parsedRelatedParameters;
    final String? relatedJson = map['glossary_related'] as String?;
    if (relatedJson != null && relatedJson.isNotEmpty) {
      try {
         final List<dynamic> decodedList = jsonDecode(relatedJson);
         // Ensure the decoded list contains only strings
         parsedRelatedParameters = decodedList.map((item) => item.toString()).toList();
      } catch (e) {
        print("Error decoding relatedParameters JSON: $e for data: $relatedJson");
        // Keep parsedRelatedParameters as null on error
      }
    }
    // ---------------------------------------

    // --- NEW: Parse related percentage/description JSON --- 
    List<num>? parsedRelatedPercentage;
    List<String>? parsedRelatedDescription;
    final String? relatedPercJson = map['glossary_related_percentage'] as String?;
    final String? relatedDescJson = map['glossary_related_description'] as String?;
    if (relatedPercJson != null && relatedPercJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = jsonDecode(relatedPercJson);
        parsedRelatedPercentage = decodedList.whereType<num>().toList();
      } catch (e) { print("Error decoding relatedPercentage JSON: $e"); }
    }
    if (relatedDescJson != null && relatedDescJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = jsonDecode(relatedDescJson);
        parsedRelatedDescription = decodedList.map((item) => item.toString()).toList();
      } catch (e) { print("Error decoding relatedDescription JSON: $e"); }
    }
    // --------------------------------------------------

    // --- DEBUG PRINT for related data retrieval ---
    if (map['parameterName'] == 'A.S.A.T. (GOT)' || map['parameterName'] == 'A.L.A.T. (GPT)') {
      print("DEBUG fromMap [${map['parameterName']}]:");
      print("  -> glossary_related: ${map['glossary_related']}");
      print("  -> glossary_related_percentage: ${map['glossary_related_percentage']}");
      print("  -> glossary_related_description: ${map['glossary_related_description']}");
      print("  -> Parsed Related Names: ${parsedRelatedParameters?.join(', ')}");
      print("  -> Parsed Related Perc: ${parsedRelatedPercentage?.join(', ')}");
      print("  -> Parsed Related Desc Count: ${parsedRelatedDescription?.length}");
    }
    // ------------------------------------------

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
      description: map['description'] as String? ?? descriptionFromGlossary,
      recommendation: map['recommendation'] as String? ?? recommendationFromGlossary,
      relatedParameters: parsedRelatedParameters,
      relatedParametersPercentage: parsedRelatedPercentage,
      relatedParametersDescription: parsedRelatedDescription,
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