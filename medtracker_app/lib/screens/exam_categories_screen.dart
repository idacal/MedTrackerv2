import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:flutter/foundation.dart';

import '../services/database_service.dart';
import '../models/parameter_record.dart';
// import '../models/exam_record.dart'; // Might not be needed directly

// Import screen for category parameters (will create next)
import 'category_parameters_screen.dart';

// Renamed from ExamDetailScreen
class ExamCategoriesScreen extends StatefulWidget {
  final int examId;
  final String examName; 

  const ExamCategoriesScreen({super.key, required this.examId, required this.examName});

  @override
  State<ExamCategoriesScreen> createState() => _ExamCategoriesScreenState();
}

// Renamed from _ExamDetailScreenState
class _ExamCategoriesScreenState extends State<ExamCategoriesScreen> {
  late Future<List<ParameterRecord>> _parametersFuture;
  Map<String, List<ParameterRecord>> _groupedParameters = {};
  final dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _loadParameters();
  }

  Future<void> _loadParameters() async {
    // Don't need setState here as FutureBuilder handles the future directly
    _parametersFuture = dbService.getParametersForExam(widget.examId);
    // Pre-process grouping when future completes, for badge calculation
    _parametersFuture.then((parameters) {
       _groupParameters(parameters);
    }).catchError((error) {
       if (kDebugMode) {
         print("Error loading parameters for grouping: $error");
       }
    });
  }

  void _groupParameters(List<ParameterRecord> parameters) {
    final grouped = <String, List<ParameterRecord>>{};
    for (var param in parameters) {
      (grouped[param.category] ??= []).add(param);
    }
    if (mounted && !mapEquals(_groupedParameters, grouped)) { 
       setState(() { // Update state only if grouping changed
          _groupedParameters = grouped;
       });
    }
  }

  // Calculate status counts for badges
  Map<String, int> _getCategoryStatusCounts(List<ParameterRecord> parameters) {
    int attentionCount = 0;
    int watchCount = 0;
    for (var param in parameters) {
      if (param.status == ParameterStatus.attention) {
        attentionCount++;
      } else if (param.status == ParameterStatus.watch) {
        watchCount++; // Assuming watch status exists and is distinct
      }
    }
    return {'attention': attentionCount, 'watch': watchCount};
  }

  void _navigateToCategoryParameters(String category, List<ParameterRecord> parameters) {
     Navigator.push(
       context,
       MaterialPageRoute(
         builder: (context) => CategoryParametersScreen(
           examName: widget.examName, 
           categoryName: category, 
           parameters: parameters, 
          )
       ),
     );
  }

  // Get color for the badge based on counts
  Color? _getBadgeColor(Map<String, int> counts) {
     if (counts['attention']! > 0) return Theme.of(context).colorScheme.error; // Red
     if (counts['watch']! > 0) return Colors.orange.shade800; // Amber
     return null; // No badge needed if all normal/unknown
  }

  // Get text for the badge
  String? _getBadgeText(Map<String, int> counts) {
     if (counts['attention']! > 0) return counts['attention'].toString();
     if (counts['watch']! > 0) return counts['watch'].toString();
     return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Categorías: ${widget.examName}', overflow: TextOverflow.ellipsis), 
      ),
      body: FutureBuilder<List<ParameterRecord>>(
        future: _parametersFuture, // FutureBuilder now directly uses the future
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error al cargar categorías: ${snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error))));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No se encontraron parámetros para este examen.')));
          }
          
          // Use the grouped data (available after future completion)
          if (_groupedParameters.isEmpty) {
             // Handle case where future completed but grouping hasn't updated state yet
             // This might happen briefly or if there was an error during grouping
              _groupParameters(snapshot.data!); // Ensure grouping happens
              if (_groupedParameters.isEmpty) { // If still empty after trying again
                   return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Error al agrupar parámetros.')));
              }
          }

          final categories = _groupedParameters.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final parametersInCategory = _groupedParameters[category]!;
              final statusCounts = _getCategoryStatusCounts(parametersInCategory);
              final badgeColor = _getBadgeColor(statusCounts);
              final badgeText = _getBadgeText(statusCounts);
              final bool allNormal = badgeColor == null; // If no badge color, assume all are normal/ok
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                  title: Text(category, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
                  trailing: badgeColor != null
                    ? CircleAvatar(
                        backgroundColor: badgeColor,
                        radius: 14,
                        child: Text(
                          badgeText!, 
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)
                        ),
                      )
                    : Icon(Icons.check_circle, color: Colors.green.shade700, size: 28), // Green check if no issues
                  onTap: () => _navigateToCategoryParameters(category, parametersInCategory),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Utility function (keep as is)
bool mapEquals<T, U>(Map<T, U>? a, Map<T, U>? b) {
   if (a == null) return b == null;
   if (b == null || a.length != b.length) return false;
   if (identical(a, b)) return true;
   for (final T key in a.keys) {
     if (!b.containsKey(key) || a[key] != b[key]) {
       return false;
     }
   }
   return true;
 } 