import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/parameter_record.dart';
import '../main.dart'; // Import main to access StatusColors
import 'parameter_detail_screen.dart'; // Import the detail screen

// Convert to StatefulWidget
class CategoryParametersScreen extends StatefulWidget {
  final String examName;
  final String categoryName;
  final List<ParameterRecord> parameters;
  
  const CategoryParametersScreen({
    super.key, 
    required this.examName,
    required this.categoryName, 
    required this.parameters
  });

  @override
  State<CategoryParametersScreen> createState() => _CategoryParametersScreenState();
}

class _CategoryParametersScreenState extends State<CategoryParametersScreen> {
  // State for search and sort (initially empty/default)
  String _searchQuery = '';
  // TODO: Define sort order enum/state
  
  // Filtered list based on search
  List<ParameterRecord> get _filteredParameters {
    if (_searchQuery.isEmpty) {
      return widget.parameters;
    }
    return widget.parameters
        .where((p) => p.parameterName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // Calculate overall status for the summary card
  ParameterStatus get _overallCategoryStatus {
      if (widget.parameters.any((p) => p.status == ParameterStatus.attention)) {
         return ParameterStatus.attention;
      }
      if (widget.parameters.any((p) => p.status == ParameterStatus.watch)) {
         return ParameterStatus.watch;
      }
       if (widget.parameters.any((p) => p.status == ParameterStatus.unknown)) {
         // Decide how unknown affects overall status (e.g., treat as watch?)
         return ParameterStatus.watch; // Example: Treat unknown as needing review
      }
      return ParameterStatus.normal;
  }

  // Helper to get status color (moved from StatelessWidget)
  Color _getStatusColor(BuildContext context, ParameterStatus status) {
    return StatusColors.of(context).getColor(status);
  }
  
  // Helper to get status icon (use filled icons)
  IconData _getStatusIcon(ParameterStatus status) {
     switch (status) {
      case ParameterStatus.normal:
        return Icons.check_circle;
      case ParameterStatus.watch:
        return Icons.watch_later; // Or Icons.info?
      case ParameterStatus.attention:
        return Icons.warning; // Filled warning
      case ParameterStatus.unknown:
      default:
        return Icons.help;
    }
  }

  void _navigateToParameterDetail(ParameterRecord parameter) {
     Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => ParameterDetailScreen(
          categoryName: parameter.category, // Use category from parameter
          parameterName: parameter.parameterName,
       )),
     );
  }

  @override
  Widget build(BuildContext context) {
     final NumberFormat valueFormatter = NumberFormat("#,##0.##"); 

    return Scaffold(
      // Remove previous AppBar
      body: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            // --- Custom Header ---
            _buildHeader(context, widget.categoryName),
            const SizedBox(height: 10), // Space below header
            
            // --- Main Content Area with Padding ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Optional Title (might be redundant with header)
                     // Padding(
                     //   padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
                     //   child: Text('Categoría Detallada', style: Theme.of(context).textTheme.headlineSmall)
                     // ),
                     
                     // --- Summary Card ---
                      _buildCategorySummaryCard(context),
                      const SizedBox(height: 16),
                      
                     // --- Search/Filter Bar ---
                      _buildSearchFilterBar(context),
                      const SizedBox(height: 10),
                     
                     // --- Parameter List ---
                     Expanded(
                       child: ListView.builder(
                          padding: EdgeInsets.zero, // Padding is handled by the outer Column
                          itemCount: _filteredParameters.length,
                          itemBuilder: (context, index) {
                             final param = _filteredParameters[index];
                             // Use the new simpler card builder
                             return _buildSimpleParameterCard(context, param, valueFormatter);
                          }
                       ),
                     ),
                   ],
                ),
              ),
            )
         ]
      ),
    );
  }

  // --- Header Builder ---
  Widget _buildHeader(BuildContext context, String title) {
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
                 padding: EdgeInsets.zero, // Remove default padding
                 constraints: const BoxConstraints(), // Remove default constraints
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: Text(
                   title.toUpperCase(), // Match mockup (uppercase)
                   style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
             ],
           ),
        ),
     );
   }

  // --- Summary Card Builder ---
  Widget _buildCategorySummaryCard(BuildContext context) {
     final overallStatus = _overallCategoryStatus;
     final statusColor = _getStatusColor(context, overallStatus);
     final statusIcon = _getStatusIcon(overallStatus);
     final int paramCount = widget.parameters.length;
     String summaryText;

     switch (overallStatus) {
        case ParameterStatus.normal:
           summaryText = "Todos los valores están en rango";
           break;
        case ParameterStatus.watch:
        case ParameterStatus.attention:
           // Count non-normal parameters
           final nonNormalCount = widget.parameters.where((p) => p.status != ParameterStatus.normal).length;
           summaryText = "$nonNormalCount parámetro(s) fuera de rango";
           break;
        case ParameterStatus.unknown:
           summaryText = "Algunos parámetros tienen estado desconocido";
           break;
     }

     return Card(
       elevation: 1.0,
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Row(
            children: [
               Icon(statusIcon, color: statusColor, size: 36), // Status icon
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text("Resumen de la categoría", style: Theme.of(context).textTheme.labelLarge), // Smaller title
                       const SizedBox(height: 4),
                       Text("$paramCount parámetros medidos", style: Theme.of(context).textTheme.bodySmall),
                       const SizedBox(height: 4),
                       Text(summaryText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: statusColor, fontWeight: FontWeight.w500)),
                    ]
                 ),
               )
            ]
         ),
       ),
     );
  }
  
  // --- Search/Filter Bar Builder ---
  Widget _buildSearchFilterBar(BuildContext context) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 8.0),
       child: Row(
         children: [
           // Search Field
           Expanded(
             child: TextField(
                onChanged: (value) {
                   setState(() {
                      _searchQuery = value;
                   });
                },
                decoration: InputDecoration(
                   hintText: "Buscar parámetro...",
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
           ),
           const SizedBox(width: 10),
           // Sort Button (Placeholder)
           TextButton.icon(
              onPressed: () { /* TODO: Implement Sort */ },
              icon: Icon(Icons.sort, size: 16, color: Theme.of(context).primaryColor),
              label: Text("Ordenar", style: TextStyle(color: Theme.of(context).primaryColor)),
              style: TextButton.styleFrom(
                 padding: const EdgeInsets.symmetric(horizontal: 8),
                 visualDensity: VisualDensity.compact,
              ),
           ),
           // Settings Button (Placeholder)
           IconButton(
              onPressed: () { /* TODO: Implement Settings */ },
              icon: Icon(Icons.settings_outlined, size: 20, color: Colors.grey[600]),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              tooltip: 'Configuración',
           )
         ],
       ),
     );
  }
  
  // --- Simple Parameter Card Builder ---
  Widget _buildSimpleParameterCard(BuildContext context, ParameterRecord param, NumberFormat formatter) {
      final statusColor = _getStatusColor(context, param.status);
      final statusIcon = _getStatusIcon(param.status);
      final valueString = param.value != null ? formatter.format(param.value) : '--';
      final rangeString = param.refOriginal?.isNotEmpty == true ? param.refOriginal! : 'No Ref.';
      
      // Determine background color ONLY for attention status
      Color? cardBackgroundColor;
      if (param.status == ParameterStatus.attention) {
          cardBackgroundColor = Colors.amber.shade50; // Very light yellow/amber
      }

      return Card(
         margin: const EdgeInsets.symmetric(vertical: 5.0),
         // Apply the conditional background color
         color: cardBackgroundColor, 
         child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
            leading: Icon(statusIcon, color: statusColor, size: 28), 
            title: Text(param.parameterName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
            subtitle: Text(rangeString, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    valueString, 
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: statusColor)
                 ),
                 const SizedBox(width: 8),
                 Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
            onTap: () => _navigateToParameterDetail(param),
         ),
      );
   }

} 