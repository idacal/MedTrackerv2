import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart'; // Import path package
import 'package:path_provider/path_provider.dart'; // Import path_provider package
import 'dart:async';
import 'dart:convert'; // For jsonDecode
import 'dart:io'; // For File related operations if needed later
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:intl/intl.dart'; // For date parsing
import 'package:flutter/services.dart' show rootBundle; // Added for rootBundle

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

    // --- TEMPORARY FOR DEVELOPMENT: Force delete DB on init ---
    /* // Comment out this block
    if (kDebugMode) { 
        print("DEVELOPMENT: Deleting existing database at $path to ensure schema update...");
        await deleteDatabase(path);
        print("DEVELOPMENT: Database deleted.");
    }
    */
    // -----------------------------------------------------------

    return await openDatabase(
      path,
      version: 6, // Increment DB version to 6
      // --- Add onConfigure callback --- 
      onConfigure: (db) async {
         await db.execute('PRAGMA foreign_keys = ON'); // Use single quotes for PRAGMA command
         if (kDebugMode) {
            print("Database onConfigure: Foreign keys ENABLED.");
         }
      },
      // -----------------------------
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, 
    );
  }

  // Create tables (Includes resultString column from start)
  Future<void> _onCreate(Database db, int version) async {
     if (kDebugMode) {
        print("Database onCreate: Creating tables for version $version...");
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
        value REAL,              -- For numeric values
        resultString TEXT,       -- For text values (NEW)
        refRangeLow REAL,
        refRangeHigh REAL,
        refOriginal TEXT,
        date TEXT NOT NULL,
        status TEXT NOT NULL, 
        unit TEXT,              -- Added V4
        description TEXT,       -- Added V4
        recommendation TEXT,    -- Added V4
        FOREIGN KEY (examRecordId) REFERENCES exam_records (id) ON DELETE CASCADE
      )
    ''');
     
    await db.execute('''
      CREATE INDEX idx_parameter_history
      ON parameter_records (category, parameterName, date, status)
    ''');

    // --- NEW: Tracked Parameters Table (V5) ---
    await db.execute('''
      CREATE TABLE tracked_parameters (
        categoryName TEXT NOT NULL,
        parameterName TEXT NOT NULL,
        PRIMARY KEY (categoryName, parameterName)
      )
    ''');
    // -----------------------------------------

    // --- NEW: Parameter Glossary Table (V6) ---
    await db.execute('''
      CREATE TABLE parameter_glossary (
        categoryName TEXT NOT NULL,
        parameterName TEXT NOT NULL,
        description TEXT,
        recommendation TEXT,
        PRIMARY KEY (categoryName, parameterName)
      )
    ''');
    // -----------------------------------------

      // --- Load Default Glossary on Create ---
      try {
        if (kDebugMode) {
          print("Database onCreate: Attempting to load default glossary from assets...");
        }
        final String jsonString = await rootBundle.loadString('assets/glossary_medtracker.json');
        // Use the internal method directly with the db instance provided to onCreate
        await _internalUpdateGlossary(db, jsonString); 
        if (kDebugMode) {
          print("Database onCreate: Default glossary loaded successfully.");
        }
      } catch (e) {
         if (kDebugMode) {
           print("Database onCreate: ERROR loading default glossary from assets: $e");
           // Don't rethrow here, onCreate should ideally still succeed
         }
      }
      // ------------------------------------

      if (kDebugMode) {
        print("Database onCreate: Tables created for V6.");
     }
  }

  // --- Database Upgrade Logic ---
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
     if (kDebugMode) {
       print("Database onUpgrade: Upgrading from version $oldVersion to $newVersion...");
     }
     
     // Upgrade from V1 to V2 (Add status column)
     if (oldVersion < 2) {
        if (kDebugMode) { print("Applying upgrade V1 -> V2..."); }
        try {
          await db.execute("ALTER TABLE parameter_records ADD COLUMN status TEXT NOT NULL DEFAULT 'unknown'");
          await db.execute("DROP INDEX IF EXISTS idx_parameter_history"); 
          await db.execute("CREATE INDEX idx_parameter_history ON parameter_records (category, parameterName, date, status)");
          if (kDebugMode) { print("Upgrade V1 -> V2 successful."); }
        } catch (e) {
             if (kDebugMode) { print("Error applying upgrade V1 -> V2: $e"); }
             rethrow; 
        }
     }

     // Upgrade from V2 to V3 (Add resultString column)
     if (oldVersion < 3) {
         if (kDebugMode) { print("Applying upgrade V2 -> V3: Adding resultString column..."); }
         try {
           await db.execute("ALTER TABLE parameter_records ADD COLUMN resultString TEXT");
           // No index change needed for this column typically
           if (kDebugMode) { print("Upgrade V2 -> V3 successful."); }
         } catch (e) {
            if (kDebugMode) { print("Error applying upgrade V2 -> V3: $e"); } 
            rethrow;
         }
     }
     
     // --- Upgrade from V3 to V4 (Add unit, description, recommendation) --- 
     if (oldVersion < 4) {
         if (kDebugMode) { print("Applying upgrade V3 -> V4: Adding unit, description, recommendation columns..."); }
         try {
           // Use separate executes for robustness
           await db.execute("ALTER TABLE parameter_records ADD COLUMN unit TEXT");
           await db.execute("ALTER TABLE parameter_records ADD COLUMN description TEXT");
           await db.execute("ALTER TABLE parameter_records ADD COLUMN recommendation TEXT");
           if (kDebugMode) { print("Upgrade V3 -> V4 successful."); }
         } catch (e) {
            if (kDebugMode) { print("Error applying upgrade V3 -> V4: $e"); } 
            rethrow;
         }
     }
     
     // --- Upgrade from V4 to V5 (Add tracked_parameters table) --- 
     if (oldVersion < 5) {
         if (kDebugMode) { print("Applying upgrade V4 -> V5: Adding tracked_parameters table..."); }
         try {
           await db.execute('''
             CREATE TABLE tracked_parameters (
               categoryName TEXT NOT NULL,
               parameterName TEXT NOT NULL,
               PRIMARY KEY (categoryName, parameterName)
             )
           ''');
           if (kDebugMode) { print("Upgrade V4 -> V5 successful."); }
         } catch (e) {
            if (kDebugMode) { print("Error applying upgrade V4 -> V5: $e"); } 
            rethrow;
         }
     }
     
     // --- Upgrade from V5 to V6 (Add parameter_glossary table) --- 
     if (oldVersion < 6) {
         if (kDebugMode) { print("Applying upgrade V5 -> V6: Adding parameter_glossary table..."); }
         try {
           await db.execute('''
             CREATE TABLE parameter_glossary (
               categoryName TEXT NOT NULL,
               parameterName TEXT NOT NULL,
               description TEXT,
               recommendation TEXT,
               PRIMARY KEY (categoryName, parameterName)
             )
           ''');
           if (kDebugMode) { print("Upgrade V5 -> V6 successful."); }
         } catch (e) {
            if (kDebugMode) { print("Error applying upgrade V5 -> V6: $e"); } 
            rethrow;
         }
     }
     // ----------------------------------------------------------------------
     
      if (kDebugMode) {
       print("Database onUpgrade: Finished.");
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

            // --- Value parsing considering valor_absoluto ---
            double? parsedValue; // This will hold the value used for status check (absolute if available)
            String? parsedResultString; // This holds secondary info (percentage or text result)
            final dynamic rawAbsoluteValue = data['valor_absoluto'];
            final dynamic rawValue = data['valor'];

            if (rawAbsoluteValue is num) { // Prioritize valor_absoluto if numeric
                parsedValue = rawAbsoluteValue.toDouble();
                // Store original valor (percentage) in resultString if available
                if (rawValue != null) { 
                    parsedResultString = rawValue.toString(); 
                }
            } else { // No numeric valor_absoluto, fallback to parsing original valor
                if (rawValue is num) { 
                    parsedValue = rawValue.toDouble();
                    // No secondary string needed here unless you want to duplicate
                } else if (rawValue is String) {
                    // Try parsing as double first
                    parsedValue = double.tryParse(rawValue.replaceAll(',', '.'));
                    if (parsedValue == null && rawValue.trim().isNotEmpty) {
                        // If parsing failed, store as string result
                        parsedResultString = rawValue.trim();
                    }
                } 
                 // else: rawValue is null or other type, both remain null
            }
            // -----------------------------------------------

            final String? refOriginal = data['referencia_original'] as String?;
            final List<dynamic>? refList = data['rango_referencia'] as List<dynamic>?;
            final Map<String, double?> parsedRange = _parseRange(refOriginal, refList);
            final double? refLow = parsedRange['low'];
            final double? refHigh = parsedRange['high'];

            // --- Calculate status (using parsedValue, which is the absolute value if exists) ---
            ParameterStatus calculatedStatus = ParameterStatus.unknown; 
            // 1. Check for exact string match (only if parsedValue is null and resultString exists)
            if (parsedValue == null && 
                parsedResultString != null &&
                refOriginal != null &&
                parsedResultString.trim().toLowerCase() == refOriginal.trim().toLowerCase()) 
            {
              calculatedStatus = ParameterStatus.normal;
            } 
            // 2. If no string match OR if we have a numeric value, check numeric comparison
            else if (parsedValue != null) { 
                if (refLow != null && refHigh == null) { 
                  calculatedStatus = parsedValue >= refLow ? ParameterStatus.normal : ParameterStatus.attention;
                } else if (refLow == null && refHigh != null) { 
                  calculatedStatus = parsedValue <= refHigh ? ParameterStatus.normal : ParameterStatus.attention;
                } else if (refLow != null && refHigh != null) { 
                  if (parsedValue < refLow || parsedValue > refHigh) { 
                    calculatedStatus = ParameterStatus.attention;
                  } else {
                    calculatedStatus = ParameterStatus.normal;
                  }
                } else {
                  calculatedStatus = ParameterStatus.normal; 
                }
            } 
            // 3. Otherwise, status remains unknown.
            // ----------------------------------------------------
            
            // --- Read description, recommendation, and unit from JSON data ---
            final String? description = data['descripcion'] as String?;
            final String? recommendation = data['recomendacion'] as String?;
            final String? unit = data['unidad'] as String?; // <-- Read unit
            // --------------------------------------------------------

            // 4. Create ParameterRecord (Ensure all fields are passed)
            final parameterRecord = ParameterRecord(
              examRecordId: examRecordId!,
              category: categoryName,
              parameterName: parameterName,
              value: parsedValue, 
              resultString: parsedResultString,
              refRangeLow: refLow,
              refRangeHigh: refHigh,
              refOriginal: refOriginal,
              date: date,
              status: calculatedStatus,
              description: description, 
              recommendation: recommendation, 
              unit: unit, // <-- Pass unit
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
    final List<Map<String, dynamic>> maps = await db.query('exam_records', orderBy: 'importDate DESC');

    // Convert the List<Map<String, dynamic>> into a List<ExamRecord>.
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

  // --- NEW: Get parameters grouped by category for an exam ---
  Future<Map<String, List<ParameterRecord>>> getGroupedParametersForExam(int examRecordId) async {
    final List<ParameterRecord> allParams = await getParametersForExam(examRecordId);
    final Map<String, List<ParameterRecord>> grouped = {};
    for (var param in allParams) {
      (grouped[param.category] ??= []).add(param);
    }
    return grouped;
  }

  /// Fetches the history for a specific parameter (category + name), ordered by date descending.
  /// Now includes description/recommendation from glossary.
  Future<List<ParameterRecord>> getParameterHistory(String category, String parameterName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        p.*, 
        pg.description as glossary_description, 
        pg.recommendation as glossary_recommendation
      FROM parameter_records p
      LEFT JOIN parameter_glossary pg ON UPPER(TRIM(p.category)) = UPPER(TRIM(pg.categoryName)) AND UPPER(TRIM(p.parameterName)) = UPPER(TRIM(pg.parameterName))
      WHERE p.category = ? AND p.parameterName = ?
      ORDER BY p.date DESC
    ''', [category, parameterName]);
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

 /// Fetches the most recent record for each unique parameter, now includes glossary info.
  Future<List<ParameterRecord>> getLatestParameterValues() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        p.*,
        pg.description as glossary_description, 
        pg.recommendation as glossary_recommendation
      FROM parameter_records p
      INNER JOIN (
          SELECT category, parameterName, MAX(date) as max_date
          FROM parameter_records
          GROUP BY category, parameterName
      ) AS latest ON p.category = latest.category AND p.parameterName = latest.parameterName AND p.date = latest.max_date
      LEFT JOIN parameter_glossary pg ON UPPER(TRIM(p.category)) = UPPER(TRIM(pg.categoryName)) AND UPPER(TRIM(p.parameterName)) = UPPER(TRIM(pg.parameterName))
      ORDER BY p.category, p.parameterName
    ''');
    if (maps.isEmpty) return [];
    return List.generate(maps.length, (i) {
      return ParameterRecord.fromMap(maps[i]);
    });
  }

  // --- NEW FUNCTION --- 
  /// Fetches recent exams along with the count of parameters in 'attention' state.
  Future<List<Map<String, dynamic>>> getRecentExamsWithAttentionCount({int limit = 3}) async {
    final db = await database;
    final String attentionStatusName = ParameterStatus.attention.name; // 'attention'

    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT
          e.id,
          e.fileName,
          e.importDate,
          COALESCE(att_count.count, 0) as attentionCount
      FROM
          exam_records e
      LEFT JOIN (
          SELECT
              examRecordId,
              COUNT(*) as count
          FROM
              parameter_records
          WHERE
              status = ? 
          GROUP BY
              examRecordId
      ) att_count ON e.id = att_count.examRecordId
      ORDER BY
          e.importDate DESC
      LIMIT ?;
    ''', [attentionStatusName, limit]);

    // The result is already List<Map<String, dynamic>> with the required fields
    return results;
  }

  // Fetches all exams with their attention count
  Future<List<Map<String, dynamic>>> getAllExamRecordsWithAttentionCount() async {
    final db = await database;
    final String statusAttention = ParameterStatus.attention.name;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        e.id, 
        e.fileName, 
        e.importDate, 
        COUNT(CASE WHEN p.status = ? THEN 1 ELSE NULL END) as attentionCount
      FROM exam_records e
      LEFT JOIN parameter_records p ON e.id = p.examRecordId
      GROUP BY e.id, e.fileName, e.importDate
      ORDER BY e.importDate DESC
    ''', [statusAttention]);

    return result;
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

  // --- Data Deletion ---

  /// Deletes an ExamRecord and its associated ParameterRecords (due to ON DELETE CASCADE).
  Future<void> deleteExamRecord(int examId) async {
    final db = await database;
    try {
      await db.delete(
        'exam_records',
        where: 'id = ?',
        whereArgs: [examId],
      );
      if (kDebugMode) {
        print("Deleted ExamRecord with ID: $examId and its parameters (via CASCADE).");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting ExamRecord with ID $examId: $e");
      }
      // Consider re-throwing or handling the error appropriately
      rethrow;
    }
  }

  // --- NEW: Tracked Parameter Methods ---

  /// Adds a parameter to the tracking list.
  Future<void> addTrackedParameter(String categoryName, String parameterName) async {
    final db = await database;
    try {
      await db.insert(
        'tracked_parameters',
        {'categoryName': categoryName, 'parameterName': parameterName},
        conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore if already tracked
      );
       if (kDebugMode) {
        print("Tracking added for: $categoryName - $parameterName");
      }
    } catch (e) {
       if (kDebugMode) {
        print("Error adding tracking for $categoryName - $parameterName: $e");
      }
      rethrow;
    }
  }

  /// Removes a parameter from the tracking list.
  Future<void> removeTrackedParameter(String categoryName, String parameterName) async {
    final db = await database;
     try {
        final count = await db.delete(
          'tracked_parameters',
          where: 'categoryName = ? AND parameterName = ?',
          whereArgs: [categoryName, parameterName],
        );
         if (kDebugMode) {
           if (count > 0) {
             print("Tracking removed for: $categoryName - $parameterName");
           } else {
              print("Attempted to remove tracking, but not found: $categoryName - $parameterName");
           }
        }
     } catch (e) {
        if (kDebugMode) {
          print("Error removing tracking for $categoryName - $parameterName: $e");
        }
        rethrow;
     }
  }

  /// Checks if a specific parameter is being tracked.
  Future<bool> isParameterTracked(String categoryName, String parameterName) async {
    final db = await database;
     try {
        final List<Map<String, dynamic>> maps = await db.query(
          'tracked_parameters',
          where: 'categoryName = ? AND parameterName = ?',
          whereArgs: [categoryName, parameterName],
          limit: 1,
        );
        return maps.isNotEmpty;
     } catch (e) {
         if (kDebugMode) {
          print("Error checking tracking status for $categoryName - $parameterName: $e");
        }
        return false; // Assume not tracked on error
     }
  }

  /// Gets a list of all tracked parameters (category and name).
  Future<List<Map<String, String>>> getTrackedParameterNames() async {
     final db = await database;
      try {
        final List<Map<String, dynamic>> maps = await db.query('tracked_parameters');
        return maps.map((map) => {
          'categoryName': map['categoryName'] as String,
          'parameterName': map['parameterName'] as String,
        }).toList();
      } catch (e) {
         if (kDebugMode) {
          print("Error getting tracked parameter names: $e");
        }
        return []; // Return empty list on error
      }
  }

  /// Fetches the latest record for each tracked parameter along with its change % string.
  /// Now implicitly includes glossary info via getParameterHistory.
  Future<List<Map<String, dynamic>>> getLatestTrackedParameterValues() async {
    final db = await database;
    final NumberFormat percentFormatter = NumberFormat("+0.0%;-0.0%;0.0%");
    
    // 1. Get the category/name of all tracked parameters
    final List<Map<String, String>> trackedNames = await getTrackedParameterNames();
    if (trackedNames.isEmpty) return [];

    final List<Map<String, dynamic>> results = [];

    // 2. For each tracked parameter, get its full history and calculate change
    for (var trackedItem in trackedNames) {
      final String category = trackedItem['categoryName']!;
      final String name = trackedItem['parameterName']!;

      // Fetch history (already ordered DESC)
      final history = await getParameterHistory(category, name);
      
      if (history.isNotEmpty) {
        final latestRecord = history.first;
        String changeString = '--'; // Default change string

        // Find the previous record with a numeric value
        ParameterRecord? previousRecord;
        for (var record in history.skip(1)) {
           if (record.value != null) {
              previousRecord = record;
              break; 
           }
        }

        // Calculate change%
        if (latestRecord.value != null && previousRecord?.value != null) {
           final currentValue = latestRecord.value!;
           final previousValue = previousRecord!.value!;
           if (previousValue != 0) { 
              final double changePercent = (currentValue - previousValue) / previousValue;
              changeString = percentFormatter.format(changePercent);
           } else if (currentValue == 0) {
              changeString = percentFormatter.format(0);
           }
           // else: previous was 0, current non-zero -> infinite change, keep '--'
        } else if (latestRecord.value == 0 && previousRecord?.value == 0) {
             changeString = percentFormatter.format(0);
        }

        results.add({
          'record': latestRecord,
          'changeString': changeString,
        });
      }
    }
    
    // Optionally re-sort results if needed (e.g., alphabetically)
    results.sort((a, b) {
       final recordA = a['record'] as ParameterRecord;
       final recordB = b['record'] as ParameterRecord;
       int catCompare = recordA.category.compareTo(recordB.category);
       if (catCompare != 0) return catCompare;
       return recordA.parameterName.compareTo(recordB.parameterName);
    });

    return results;
    
    /* // --- Old Query (Less efficient for getting previous value) ---
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.*
      FROM parameter_records p
      INNER JOIN tracked_parameters tp ON p.category = tp.categoryName AND p.parameterName = tp.parameterName
      INNER JOIN (
          SELECT category, parameterName, MAX(date) as max_date
          FROM parameter_records
          GROUP BY category, parameterName
      ) AS latest ON p.category = latest.category AND p.parameterName = latest.parameterName AND p.date = latest.max_date
      ORDER BY p.category, p.parameterName
    ''');
    if (maps.isEmpty) return [];
    return List.generate(maps.length, (i) {
      // PROBLEM: This only returns latest, need history to calculate change
      return ParameterRecord.fromMap(maps[i]); 
    });
    */
  }

  /// Adds default parameters to tracking if the tracking list is currently empty.
  Future<void> setDefaultTrackedParametersIfEmpty() async {
     final db = await database;
     try {
        final List<Map<String, dynamic>> tracked = await db.query('tracked_parameters', limit: 1);
        if (tracked.isEmpty) {
          if (kDebugMode) {
            print("Tracking list is empty. Adding default parameters...");
          }
          // Add default parameters (Ensure category/parameter names match your JSON exactly)
          await addTrackedParameter('PERFIL BIOQUIMICO', 'Glucosa');
          await addTrackedParameter('PERFIL BIOQUIMICO', 'Colesterol'); 
          await addTrackedParameter('VITAMINAS', 'Vitamina B12');
           if (kDebugMode) {
            print("Default parameters added.");
          }
        } else {
           if (kDebugMode) {
            print("Tracking list is not empty. Skipping default parameters.");
          }
        }
     } catch (e) {
        if (kDebugMode) {
          print("Error setting default tracked parameters: $e");
        }
        // Don't rethrow here, not critical if defaults fail
     }
  }

  // --- NEW: Glossary Update Method ---
  /// Parses a JSON string containing glossary data and updates the glossary table.
  Future<void> updateGlossaryFromJson(String jsonString) async {
    final db = await database;
    try {
       await _internalUpdateGlossary(db, jsonString); // Call internal method
        if (kDebugMode) {
         print("Glossary update via public method successful.");
       }
    } catch (e) {
       if (kDebugMode) {
         print("Error updating glossary from public method: $e");
       }
       rethrow; 
    }
  }

  // --- Internal Glossary Update Logic ---
  Future<void> _internalUpdateGlossary(DatabaseExecutor dbOrTxn, String jsonString) async {
     try {
      // Expecting format: {"CategoryName": {"ParameterName": {"description": "...", "recommendation": "..."}}}
      final Map<String, dynamic> glossaryData = jsonDecode(jsonString);
      
      // Use batch for potentially better performance, especially on first load
      final batch = dbOrTxn.batch();

      // await dbOrTxn.transaction((txn) async { // Transaction might be redundant if using batch
        for (final categoryEntry in glossaryData.entries) {
          final String categoryName = categoryEntry.key;
          if (categoryEntry.value is! Map) continue; 
          final Map<String, dynamic> parameters = Map<String, dynamic>.from(categoryEntry.value);

          for (final parameterEntry in parameters.entries) {
            final String parameterName = parameterEntry.key;
            if (parameterEntry.value is! Map) continue; 
            final Map<String, dynamic> data = Map<String, dynamic>.from(parameterEntry.value);

            final String? description = data['descripcion'] as String?;
            final String? recommendation = data['recomendacion'] as String?;

            // Add insert/replace operation to batch
            batch.insert(
              'parameter_glossary',
              {
                'categoryName': categoryName,
                'parameterName': parameterName,
                'description': description,
                'recommendation': recommendation,
              },
              conflictAlgorithm: ConflictAlgorithm.replace, 
            );
          }
        }
        // Commit the batch
        await batch.commit(noResult: true); 
      // }); // End transaction
       if (kDebugMode) {
        print("Internal Glossary update logic successful.");
      }
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print("Error during internal glossary update: $e");
        print("Stacktrace: $stacktrace");
      }
      rethrow; // Rethrow to signal failure
    }
  }

  // --- Debugging Helper ---
  Future<void> debugPrintGlossary() async {
    if (!kDebugMode) return; // Only run in debug mode
    final db = await database;
    try {
      print("DEBUG: Querying parameter_glossary table content...");
      final List<Map<String, dynamic>> maps = await db.query('parameter_glossary');
      if (maps.isEmpty) {
        print("DEBUG: parameter_glossary table is EMPTY.");
      } else {
        print("DEBUG: parameter_glossary content (${maps.length} rows):");
        for (var map in maps) {
          print("  - ${map}");
        }
      }
    } catch (e) {
      print("DEBUG: Error querying parameter_glossary table: $e");
    }
  }
  // ----------------------

} 