import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:flutter/foundation.dart';

import '../services/database_service.dart';
import '../models/parameter_record.dart';
import '../main.dart'; // Import main to access StatusColors
// import '../models/exam_record.dart'; // Might not be needed directly

// Import screen for category parameters (will create next)
import 'category_parameters_screen.dart';

// Convert to StatefulWidget to handle search
class ExamCategoriesScreen extends StatefulWidget {
  final String examName;
  // Accept grouped parameters instead of examId
  final Map<String, List<ParameterRecord>> groupedParameters;

  const ExamCategoriesScreen({
    super.key,
    required this.examName,
    required this.groupedParameters,
  });

  @override
  State<ExamCategoriesScreen> createState() => _ExamCategoriesScreenState();
}

class _ExamCategoriesScreenState extends State<ExamCategoriesScreen> {
  String _searchQuery = '';

  // Filter category names based on search query
  List<String> get _filteredCategoryNames {
    final allNames = widget.groupedParameters.keys.toList()..sort(); // Sort alphabetically
    if (_searchQuery.isEmpty) {
      return allNames;
    }
    return allNames
        .where((name) => name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // Determine overall status for a category based on its parameters
  ParameterStatus _getOverallCategoryStatus(List<ParameterRecord> params) {
    if (params.any((p) => p.status == ParameterStatus.attention)) {
      return ParameterStatus.attention;
    }
    if (params.any((p) => p.status == ParameterStatus.watch)) {
      return ParameterStatus.watch;
    }
     if (params.any((p) => p.status == ParameterStatus.unknown)) {
      // If any parameter is unknown, maybe mark category for review (watch)
      return ParameterStatus.watch; 
    }
    return ParameterStatus.normal;
  }
  
   // Helper to get status icon (use filled icons)
  IconData _getStatusIcon(ParameterStatus status) {
     switch (status) {
      case ParameterStatus.normal:
        return Icons.check_circle;
      case ParameterStatus.watch:
         // Use info or watch icon for watch/unknown combined status
        return Icons.info_outline; 
      case ParameterStatus.attention:
        return Icons.warning; // Filled warning
      case ParameterStatus.unknown:
      default:
        return Icons.help; // Should ideally not be reached if unknown maps to watch
    }
  }
  
  // Helper to get status color
  Color _getStatusColor(BuildContext context, ParameterStatus status) {
     return StatusColors.of(context).getColor(status);
  }

  // Navigate to the detailed parameter list for the selected category
  void _navigateToCategoryParameters(String categoryName, List<ParameterRecord> parameters) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryParametersScreen(
          examName: widget.examName,
          categoryName: categoryName,
          parameters: parameters, // Pass the already available list
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar, using custom header
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Custom Header ---
          _buildHeader(context, widget.examName),
          const SizedBox(height: 10),

          // --- Main Content with Padding ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Optional Title
                  // Padding(
                  //   padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                  //   child: Text('Categorías Mejoradas', style: Theme.of(context).textTheme.headlineSmall)
                  // ),
                  
                  // --- Search Bar ---
                  _buildSearchBar(context),
                  const SizedBox(height: 10),

                  // --- Category List ---
                  Expanded(
                    child: _filteredCategoryNames.isEmpty
                      ? Center(child: Text(_searchQuery.isEmpty ? 'No hay categorías en este examen.' : 'No se encontraron categorías.'))
                      : ListView.builder(
                          padding: EdgeInsets.zero, // Padding handled by outer column
                          itemCount: _filteredCategoryNames.length,
                          itemBuilder: (context, index) {
                            final categoryName = _filteredCategoryNames[index];
                            final parametersForCategory = widget.groupedParameters[categoryName] ?? [];
                            return _buildCategoryCard(context, categoryName, parametersForCategory);
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Header Builder ---
  Widget _buildHeader(BuildContext context, String examName) {
     // Shorten exam name if too long for the title
     String displayExamName = examName;
     const maxLength = 25; // Adjust as needed
     if (examName.length > maxLength) {
        displayExamName = '${examName.substring(0, maxLength)}...';
     }
     
     return Material(
        elevation: 2.0,
        child: Container(
           color: Theme.of(context).primaryColor, 
           padding: EdgeInsets.only(
             top: MediaQuery.of(context).padding.top + 10, 
             bottom: 15,
             left: 15,
             right: 15,
           ),
           child: Row(
             children: [
               IconButton(
                 icon: const Icon(Icons.arrow_back, color: Colors.white),
                 onPressed: () => Navigator.of(context).pop(),
                 tooltip: 'Volver',
                 padding: EdgeInsets.zero, 
                 constraints: const BoxConstraints(), 
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Text(
                   'Categorías: $displayExamName', // Dynamic title
                   style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
             ],
           ),
        ),
     );
   }
   
  // --- Search Bar Builder ---
  Widget _buildSearchBar(BuildContext context) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8.0),
       child: TextField(
          onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
          },
          decoration: InputDecoration(
              hintText: "Buscar categoría...",
              prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[600]),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.0),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.0),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20.0),
                borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
          ),
       ),
     );
  }

  // --- Category Card Builder ---
  Widget _buildCategoryCard(BuildContext context, String categoryName, List<ParameterRecord> parameters) {
     final overallStatus = _getOverallCategoryStatus(parameters);
     final statusIcon = _getStatusIcon(overallStatus);
     final statusColor = _getStatusColor(context, overallStatus);

     return Card(
       margin: const EdgeInsets.symmetric(vertical: 5.0),
       child: ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          title: Text(
             categoryName.toUpperCase(), // Match mockup
             style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)
          ),
          // Trailing shows the status icon
          trailing: Icon(statusIcon, color: statusColor, size: 28),
          onTap: () => _navigateToCategoryParameters(categoryName, parameters),
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