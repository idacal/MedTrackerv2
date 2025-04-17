import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart'; // Import path package
import 'package:path_provider/path_provider.dart'; // Import path_provider package
import 'dart:async';
import 'dart:convert'; // For jsonDecode
import 'dart:io'; // For File related operations if needed later
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:intl/intl.dart'; // For date parsing

// Import models
import '../models/exam_record.dart';
import '../models/parameter_record.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'medtracker.db');

    // Delete the database file on startup for testing purposes (optional)
    // Remove this line for production to keep data persistent
    // await deleteDatabase(path);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Create tables
  Future<void> _onCreate(Database db, int version) async {
     if (kDebugMode) {
        print("Creating database tables...");
     }
    await db.execute('''
      CREATE TABLE exam_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fileName TEXT NOT NULL,
        importDate TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE parameter_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        examRecordId INTEGER NOT NULL,
        category TEXT NOT NULL,
        parameterName TEXT NOT NULL,
        value REAL,
        refRangeLow REAL,
        refRangeHigh REAL,
        refOriginal TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (examRecordId) REFERENCES exam_records (id) ON DELETE CASCADE
      )
    ''');
     // Add index for faster history lookups
    await db.execute('''
      CREATE INDEX idx_parameter_history
      ON parameter_records (category, parameterName, date)
    ''');
      if (kDebugMode) {
        print("Database tables created.");
     }
  }

  // --- Data Insertion ---

  /// Parses a JSON string containing exam data and inserts it into the database.
  /// Returns the ID of the new ExamRecord if successful, otherwise null.
  Future<int?> insertExamFromJson(String jsonString, String fileName) async {
    final db = await database;
    int? examRecordId;

    try {
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      await db.transaction((txn) async {
        // 1. Create and insert the ExamRecord
        final examRecord = ExamRecord(
          fileName: fileName,
          importDate: DateTime.now(),
        );
        examRecordId = await txn.insert(
          'exam_records',
          examRecord.toMap()..remove('id'), // Remove null id before insert
          conflictAlgorithm: ConflictAlgorithm.replace, // Or fail/ignore
        );

        if (examRecordId == null) {
          throw Exception("Failed to insert ExamRecord");
        }

        // 2. Iterate through categories and parameters
        for (final categoryEntry in jsonData.entries) {
          final String categoryName = categoryEntry.key;
          // Ensure the value is a Map, skip if not (handles potential malformed JSON)
          if (categoryEntry.value is! Map) {
             if (kDebugMode) {
                print("Skipping category entry '${categoryName}' as its value is not a Map: ${categoryEntry.value}");
             }
             continue;
          }
          final Map<String, dynamic> parameters = Map<String, dynamic>.from(categoryEntry.value);

          for (final parameterEntry in parameters.entries) {
            final String parameterName = parameterEntry.key;
            // Ensure the value is a Map, skip if not
             if (parameterEntry.value is! Map) {
               if (kDebugMode) {
                  print("Skipping parameter entry '${parameterName}' in category '${categoryName}' as its value is not a Map: ${parameterEntry.value}");
               }
               continue;
            }
            final Map<String, dynamic> data = Map<String, dynamic>.from(parameterEntry.value);

            // 3. Parse parameter data
            final DateTime? date = _parseDate(data['fecha'] as String?);
            if (date == null) {
              if (kDebugMode) {
                print("Skipping parameter '$parameterName' in category '$categoryName' due to invalid date: ${data['fecha']}");
              }
              continue; // Skip this parameter if date is invalid/missing
            }

            final double? value = (data['valor'] as num?)?.toDouble();
            final String? refOriginal = data['referencia_original'] as String?;
            final List<dynamic>? refList = data['rango_referencia'] as List<dynamic>?;
            final Map<String, double?> parsedRange = _parseRange(refOriginal, refList);


            // 4. Create ParameterRecord
            final parameterRecord = ParameterRecord(
              examRecordId: examRecordId!,
              category: categoryName,
              parameterName: parameterName,
              value: value,
              refRangeLow: parsedRange['low'],
              refRangeHigh: parsedRange['high'],
              refOriginal: refOriginal,
              date: date,
            );

            // 5. Insert ParameterRecord
            await txn.insert(
              'parameter_records',
              parameterRecord.toMap()..remove('id'), // Remove null id
              conflictAlgorithm: ConflictAlgorithm.replace, // Or fail/ignore
            );
          }
        }
      });
      if (kDebugMode) {
        print("Successfully inserted exam from $fileName with ID: $examRecordId");
      }
      return examRecordId;

    } catch (e, stacktrace) {
      if (kDebugMode) {
        print("Error inserting exam from JSON: $e");
        print("Stacktrace: $stacktrace");
        // If in a transaction, it should automatically roll back on error.
      }
      return null; // Indicate failure
    }
  }

  // --- Data Retrieval ---

  /// Fetches all exam records from the database, ordered by import date descending.
  Future<List<ExamRecord>> getAllExamRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'exam_records',
      orderBy: 'importDate DESC',
    );
    return List.generate(maps.length, (i) {
      return ExamRecord.fromMap(maps[i]);
    });
  }

  /// Fetches all parameter records for a specific exam record ID.
  Future<List<ParameterRecord>> getParametersForExam(int examRecordId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'parameter_records',
      where: 'examRecordId = ?',
      whereArgs: [examRecordId],
      orderBy: 'category, parameterName', // Consistent ordering
    );
    if (maps.isEmpty) {
        return []; // Return empty list if no parameters found for the exam
    }
    return List.generate(maps.length, (i) {
      return ParameterRecord.fromMap(maps[i]);
    });
  }

  /// Fetches the history for a specific parameter (category + name), ordered by date descending.
  Future<List<ParameterRecord>> getParameterHistory(String category, String parameterName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'parameter_records',
      where: 'category = ? AND parameterName = ?',
      whereArgs: [category, parameterName],
      orderBy: 'date DESC',
    );
     if (maps.isEmpty) {
        return []; // Return empty list if no history found
    }
    return List.generate(maps.length, (i) {
      return ParameterRecord.fromMap(maps[i]);
    });
  }

  /// Fetches a list of unique category names present in the database.
  Future<List<String>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'parameter_records',
      distinct: true,
      columns: ['category'],
      orderBy: 'category',
    );
     if (maps.isEmpty) {
        return [];
    }
    return List.generate(maps.length, (i) {
      return maps[i]['category'] as String;
    });
  }

 /// Fetches the most recent record for each unique parameter (category + name).
  Future<List<ParameterRecord>> getLatestParameterValues() async {
    final db = await database;
    // This query finds the maximum date for each parameter and then joins back
    // to get the full record associated with that maximum date.
    // It correctly handles cases where multiple imports might have the same parameter.
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p1.*
      FROM parameter_records p1
      INNER JOIN (
          SELECT category, parameterName, MAX(date) as max_date
          FROM parameter_records
          GROUP BY category, parameterName
      ) p2 ON p1.category = p2.category
           AND p1.parameterName = p2.parameterName
           AND p1.date = p2.max_date
      ORDER BY p1.category, p1.parameterName
    ''');
    // Note: If multiple records for the *same* parameter have the exact same *latest* date
    // (e.g., two files imported simultaneously with identical data), this might return multiple rows
    // for that parameter from the latest timestamp. Consider adding MAX(id) or another tie-breaker if needed.
    if (maps.isEmpty) {
        return [];
    }
    return List.generate(maps.length, (i) {
      return ParameterRecord.fromMap(maps[i]);
    });
  }

  // --- Utility / Parsing ---

  // Simple date parser, adjust format as needed
  // Assumes DD/MM/YYYY format from JSON
  DateTime? _parseDate(String? dateString) {
    if (dateString == null) return null;
    try {
      // Explicitly handle potential extra spaces and ensure consistent format
      final cleanedDateString = dateString.replaceAll(' ', '');
      // Use parseStrict to ensure the format matches exactly
      return DateFormat('dd/MM/yyyy').parseStrict(cleanedDateString);
    } catch (e) {
      // Optionally try other formats if needed
      // try { return DateFormat('d/M/yyyy').parseStrict(cleanedDateString); } catch (_) {}
      if (kDebugMode) {
        print("Error parsing date: '$dateString'. Expected format dd/MM/yyyy. Error: $e");
      }
      return null;
    }
  }

  // Simple range parser, handles "X - Y", "< X", "> X", nulls, and prioritizes numeric list
   Map<String, double?> _parseRange(String? rangeString, List<dynamic>? rangeList) {
      double? low;
      double? high;
      bool parsedFromList = false;

      // 1. Try parsing from the numeric list first
      if (rangeList != null && rangeList.isNotEmpty) {
          try {
             if (rangeList.length == 1) {
               // Handle single value list - could be upper or lower bound depending on context
               // Requires knowledge from rangeString, or assume default (e.g., upper bound?)
               // Let's rely on string parsing for single values for now.
             } else if (rangeList.length >= 2) {
                 // Attempt to parse first two elements as numbers
                 low = (rangeList[0] as num?)?.toDouble();
                 high = (rangeList[1] as num?)?.toDouble();

                 // If parsing was successful (at least one value is not null)
                 if (low != null || high != null) {
                    parsedFromList = true;
                    // Validation/Warning for swapped ranges
                    if (low != null && high != null && low > high) {
                        if (kDebugMode) {
                           print("Warning: Parsed range list low ($low) > high ($high) for original '$rangeString'. Keeping original order.");
                        }
                        // Decide how to handle: swap, nullify, keep as is? For now, keep as is.
                    }
                    // Validation/Warning for null low with non-null high
                    else if (low == null && high != null) {
                         if (kDebugMode) {
                           // This is valid for '< X' scenarios represented numerically [null, X]
                           // print("Info: Parsed range list low is null but high ($high) is not for original '$rangeString'. Treating as upper bound.");
                         }
                    }
                    // Validation/Warning for non-null low with null high
                     else if (low != null && high == null) {
                         if (kDebugMode) {
                           // This is valid for '> X' scenarios represented numerically [X, null]
                           // print("Info: Parsed range list high is null but low ($low) is not for original '$rangeString'. Treating as lower bound.");
                         }
                    }
                 }
             }
          } catch (e) {
             if (kDebugMode) {
                print("Error parsing numeric range list $rangeList for original '$rangeString': $e. Falling back to string parsing.");
             }
             low = null; // Reset on error
             high = null;
             parsedFromList = false;
          }
      }

      // 2. If not successfully parsed from list OR list was empty/null, try parsing the original string
      if (!parsedFromList && rangeString != null) {
          final cleaned = rangeString.trim().replaceAll(',', '.'); // Handle surrounding spaces and commas

          if (cleaned.contains(' - ')) { // Look for space-hyphen-space first
              final parts = cleaned.split(' - ');
              if (parts.length == 2) {
                  low = double.tryParse(parts[0].trim());
                  high = double.tryParse(parts[1].trim());
              }
          } else if (cleaned.contains('-')) { // Then look for just hyphen (might be less reliable)
               final parts = cleaned.split('-');
               if (parts.length == 2) {
                  low = double.tryParse(parts[0].trim());
                  high = double.tryParse(parts[1].trim());
               }
          } else if (cleaned.startsWith('<')) {
              high = double.tryParse(cleaned.substring(1).trim());
              low = null;
          } else if (cleaned.startsWith('>')) {
              low = double.tryParse(cleaned.substring(1).trim());
              high = null;
          } else {
             // Handle other potential non-numeric strings if needed (e.g., "Negativo")
             // Currently, these will result in null low/high
             if (kDebugMode) {
                // Check if it's potentially just a number (although value field should handle this)
                if (double.tryParse(cleaned) == null && !cleaned.toLowerCase().contains('neg')) {
                   // print("Info: Range string '$rangeString' did not match known patterns (<, >, -). Treating as non-numeric/unknown range.");
                }
             }
          }

           // Validation/Warning after string parsing
            if (low != null && high != null && low > high) {
                 if (kDebugMode) {
                    print("Warning: Parsed string range low ($low) > high ($high) for '$rangeString'. Keeping original order.");
                 }
             }
             // No warning needed for single bounds derived from string parsing '<' or '>'
      }

      return {'low': low, 'high': high};
  }

} 