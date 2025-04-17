import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:flutter/foundation.dart';

import '../services/database_service.dart';
import '../models/parameter_record.dart';
import '../main.dart'; // Import main to access StatusColors
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

  Color _getBadgeColor(Map<String, int> counts) {
     final statusColors = StatusColors.of(context); // Use theme colors
     if (counts['attention']! > 0) return statusColors.attention;
     if (counts['watch']! > 0) return statusColors.watch;
     return statusColors.normal; // Return normal color if no issues
  }

  IconData _getBadgeIcon(Map<String, int> counts) {
     if (counts['attention']! > 0) return Icons.error_outline;
     if (counts['watch']! > 0) return Icons.warning_amber_rounded; 
     return Icons.check_circle; 
  }
  
  String? _getBadgeText(Map<String, int> counts) {
     // Only show text for counts > 0
     if (counts['attention']! > 0) return counts['attention'].toString();
     if (counts['watch']! > 0) return counts['watch'].toString();
     return null; // No text for green check
  }

  @override
  Widget build(BuildContext context) {
    final statusColors = StatusColors.of(context);
    return Scaffold(
      appBar: AppBar(
        // Use theme style, ensure title fits
        title: Text('Categorías: ${widget.examName}', overflow: TextOverflow.ellipsis),
      ),
      body: FutureBuilder<List<ParameterRecord>>(
        future: _parametersFuture, 
        builder: (context, snapshot) {
           // ... (Handle loading, error, empty states as before) ...
           if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
           }
           if (snapshot.hasError) {
             return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error al cargar categorías: ${snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error))));
           }
           if (!snapshot.hasData || snapshot.data!.isEmpty) {
             return const Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('No se encontraron parámetros para este examen.')));
           }
           if (_groupedParameters.isEmpty) {
               _groupParameters(snapshot.data!); 
               if (_groupedParameters.isEmpty) { 
                    return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Error al agrupar parámetros.')));
               }
           }

          final categories = _groupedParameters.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0), // Consistent padding
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final parametersInCategory = _groupedParameters[category]!;
              final statusCounts = _getCategoryStatusCounts(parametersInCategory);
              final badgeColor = _getBadgeColor(statusCounts);
              final badgeIcon = _getBadgeIcon(statusCounts);
              final badgeText = _getBadgeText(statusCounts);
              
              return Card(
                // Use theme defaults
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  title: Text(category, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500)),
                  trailing: CircleAvatar( // Always show CircleAvatar for consistency
                      backgroundColor: badgeColor.withOpacity(0.15), // Lighter background
                      radius: 15,
                      child: badgeText != null 
                        ? Text( // Show number if available
                            badgeText,
                            style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold)
                          )
                        : Icon(badgeIcon, color: badgeColor, size: 18), // Show icon otherwise
                    ),
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