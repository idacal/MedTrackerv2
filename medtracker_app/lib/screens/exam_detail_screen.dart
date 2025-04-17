import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date/number formatting
import 'package:flutter/foundation.dart'; // Import for kDebugMode

// Import services and models
import '../services/database_service.dart';
import '../models/parameter_record.dart';
import '../models/exam_record.dart'; // Potentially needed if showing exam metadata

// Import parameter detail screen (will create later)
// import 'parameter_detail_screen.dart'; 

class ExamDetailScreen extends StatefulWidget {
  final int examId;
  final String examName; // Passed for AppBar title

  const ExamDetailScreen({super.key, required this.examId, required this.examName});

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  late Future<List<ParameterRecord>> _parametersFuture;
  Map<String, List<ParameterRecord>> _groupedParameters = {};
  final dbService = DatabaseService();
  final NumberFormat _valueFormatter = NumberFormat("#,##0.##"); // Format numeric values

  @override
  void initState() {
    super.initState();
    _loadParameters();
  }

  Future<void> _loadParameters() async {
    setState(() {
      // Fetch parameters
      _parametersFuture = dbService.getParametersForExam(widget.examId);
      
      // Process the future to group parameters by category once loaded
      _parametersFuture.then((parameters) {
        _groupParameters(parameters);
      }).catchError((error) {
         // Error is handled by FutureBuilder, but can log here if needed
         if (kDebugMode) {
             print("Error loading parameters for grouping: $error");
         }
      });
    });
  }

  // Helper function to group parameters by category
  void _groupParameters(List<ParameterRecord> parameters) {
    final grouped = <String, List<ParameterRecord>>{};
    for (var param in parameters) {
      (grouped[param.category] ??= []).add(param);
    }
    // Update the state only if the grouping is different (or first time)
    // This check might be redundant if _loadParameters sets state anyway
    if (mounted && !mapEquals(_groupedParameters, grouped)) { 
       setState(() {
          _groupedParameters = grouped;
       });
    }
  }

  void _navigateToParameterDetail(ParameterRecord parameter) {
     // TODO: Implement navigation to ParameterDetailScreen (for graph)
     print("Navigate to history/graph for: ${parameter.category} - ${parameter.parameterName}");
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gráfico para ${parameter.parameterName} (No implementado)')),
     );
     // Example navigation (uncomment when ParameterDetailScreen exists):
     // Navigator.push(
     //   context,
     //   MaterialPageRoute(builder: (context) => ParameterDetailScreen(parameter: parameter)),
     // );
  }

  // Helper to get status color
  Color _getStatusColor(ParameterStatus status) {
    switch (status) {
      case ParameterStatus.normal:
        return Colors.green.shade700; // Darker green for better contrast
      case ParameterStatus.watch:
        return Colors.orange.shade800; // Darker orange
      case ParameterStatus.attention:
        return Theme.of(context).colorScheme.error; // Use theme error color (red)
      case ParameterStatus.unknown:
        return Colors.grey.shade600;
    }
  }
  
  // Helper to get status icon
  IconData _getStatusIcon(ParameterStatus status) {
     switch (status) {
      case ParameterStatus.normal:
        return Icons.check_circle_outline;
      case ParameterStatus.watch:
        return Icons.watch_later_outlined; // Or warning amber?
      case ParameterStatus.attention:
        return Icons.error_outline;
      case ParameterStatus.unknown:
        return Icons.help_outline;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.examName, style: Theme.of(context).textTheme.titleMedium), 
        // Optional: Add actions like Share or Compare if relevant here
        // actions: [...]
      ),
      body: FutureBuilder<List<ParameterRecord>>(
        future: _parametersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error al cargar parámetros: ${snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error))));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No se encontraron parámetros para este examen.')));
          }
          
          // Use the grouped data for the ListView
          final categories = _groupedParameters.keys.toList()..sort(); // Sort categories alphabetically

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final parametersInCategory = _groupedParameters[category]!;
              
              // Use ExpansionTile for collapsible categories
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ExpansionTile(
                  title: Text(category, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  initiallyExpanded: true, // Start expanded
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  children: parametersInCategory.map((param) {
                    final statusColor = _getStatusColor(param.status);
                    final statusIcon = _getStatusIcon(param.status);
                    final valueString = param.value != null ? _valueFormatter.format(param.value) : '--';
                    final rangeString = param.refOriginal ?? 'No disponible'; // Display original range or placeholder
                    
                    return ListTile(
                       leading: Icon(statusIcon, color: statusColor, size: 28),
                       title: Text(param.parameterName),
                       subtitle: Text('Ref: $rangeString'), // Show reference range
                       trailing: Text(
                          valueString, 
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: statusColor)
                       ),
                       onTap: () => _navigateToParameterDetail(param),
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Utility function to compare maps (needed for grouped parameter check)
// Import from foundation or collection package if available for robustness
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