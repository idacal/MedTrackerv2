import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/parameter_record.dart';
import '../main.dart'; // Import main to access StatusColors
import 'parameter_detail_screen.dart'; // Import the detail screen
import '../services/database_service.dart'; // Import DatabaseService

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
  final dbService = DatabaseService(); // Add DatabaseService instance
  Map<String, bool> _trackedStatusMap = {}; // Map to store tracking status
  bool _isLoadingTrackingStatus = true; // Loading state for tracking status
  
  @override
  void initState() {
    super.initState();
    _loadTrackingStatus(); // Load tracking status on init
  }

  // Load tracking status for all parameters in this category
  Future<void> _loadTrackingStatus() async {
    if (!mounted) return; // Prevent state update if widget is disposed
    setState(() {
      _isLoadingTrackingStatus = true; // Start loading
      _trackedStatusMap = {}; // Clear previous status
    });
    Map<String, bool> statusMap = {};
    try {
      for (var param in widget.parameters) {
        final isTracked = await dbService.isParameterTracked(param.category, param.parameterName);
        statusMap[param.parameterName] = isTracked;
      }
    } catch (e) {
      if (mounted) {
        print("Error loading tracking status: $e");
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al cargar estado de seguimiento: $e')),
         );
      }
    } finally {
      if (mounted) {
        setState(() {
          _trackedStatusMap = statusMap;
          _isLoadingTrackingStatus = false; // Finish loading
        });
      }
    }
  }

  // Helper function to assign a score based on status for sorting
  int _getStatusScore(ParameterStatus status) {
    switch (status) {
      case ParameterStatus.attention:
        return 0; // Highest priority
      case ParameterStatus.watch:
      case ParameterStatus.unknown: // Group watch and unknown together
        return 1;
      case ParameterStatus.normal:
        return 2; // Lowest priority
      default:
        return 3;
    }
  }

  // Comparison function for sorting ParameterRecords
  int _compareParameters(ParameterRecord a, ParameterRecord b) {
    final scoreA = _getStatusScore(a.status);
    final scoreB = _getStatusScore(b.status);
    if (scoreA != scoreB) {
      return scoreA.compareTo(scoreB); // Sort by status score first
    }
    // If statuses are the same, sort alphabetically by name
    return a.parameterName.compareTo(b.parameterName);
  }

  // Filtered and sorted list based on search and status
  List<ParameterRecord> get _filteredParameters {
    List<ParameterRecord> filtered;
    if (_searchQuery.isEmpty) {
      filtered = List.from(widget.parameters); // Create a mutable copy
    } else {
      filtered = widget.parameters
          .where((p) => p.parameterName.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    // Apply sorting
    filtered.sort(_compareParameters);
    return filtered;
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

  // --- Handle Long Press for Tracking ---
  Future<void> _showTrackingDialog(ParameterRecord parameter) async {
    // Ensure we have the latest status before showing the dialog
    // This guards against potential race conditions if status changes quickly
    // although less likely in this specific scenario.
    final bool currentlyTracked = _trackedStatusMap[parameter.parameterName] ?? false;
    
    final String actionText = currentlyTracked ? 'Dejar de Seguir' : 'Agregar a Seguimiento';
    final String titleText = currentlyTracked ? 'Quitar de Indicadores Seguidos' : 'Seguir Indicador';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(titleText),
          content: Text('¿Quieres ${actionText.toLowerCase()} el parámetro "${parameter.parameterName}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text(actionText),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) { // Check mounted again before async gap
      try {
        if (currentlyTracked) {
          await dbService.removeTrackedParameter(parameter.category, parameter.parameterName);
        } else {
          await dbService.addTrackedParameter(parameter.category, parameter.parameterName);
        }
        // Update local state and refresh UI AFTER successful DB operation
        setState(() {
          _trackedStatusMap[parameter.parameterName] = !currentlyTracked;
        });
        if (mounted) { // Check mounted before showing SnackBar
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('"${parameter.parameterName}" ${currentlyTracked ? 'quitado de' : 'agregado a'} seguimiento.')),
           );
        }
      } catch (e) {
         if (mounted) { // Check mounted before showing SnackBar
            ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error al actualizar seguimiento: $e')),
           );
         }
      }
    }
  }
  // ------------------------------------

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
                      _isLoadingTrackingStatus
                         ? const Expanded(child: Center(child: CircularProgressIndicator()))
                         : Expanded(
                             child: ListView.builder(
                                padding: EdgeInsets.zero, // Padding is handled by the outer Column
                                itemCount: _filteredParameters.length,
                                itemBuilder: (context, index) {
                                  final param = _filteredParameters[index];
                                  // Get tracking status from the map
                                  final bool isTracked = _trackedStatusMap[param.parameterName] ?? false;
                                  // Pass tracking status and handler
                                  return _buildSimpleParameterCard(
                                     context,
                                     param, 
                                     valueFormatter, 
                                     isTracked, // Pass status
                                     () => _showTrackingDialog(param) // Pass handler
                                  );
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
  Widget _buildSimpleParameterCard(
      BuildContext context, 
      ParameterRecord param, 
      NumberFormat formatter,
      bool isTracked, // Added
      VoidCallback onLongPress // Added
      ) {
      final statusColor = _getStatusColor(context, param.status);
      final statusIcon = _getStatusIcon(param.status);
      final primaryDisplay = param.displayValue; 
      final numericValue = param.value; // Needed to check if unit should be shown
      final String displayUnit = param.unit ?? ''; // Get unit
      
      // --- Improved Range String Logic ---
      String rangeString;
      if (param.refOriginal != null && param.refOriginal!.isNotEmpty) {
         rangeString = param.refOriginal!;
      } else if (param.refRangeLow != null || param.refRangeHigh != null) {
         // Format numeric range if original is missing
         final low = param.refRangeLow != null ? formatter.format(param.refRangeLow) : null;
         final high = param.refRangeHigh != null ? formatter.format(param.refRangeHigh) : null;
         if (low != null && high != null) {
           rangeString = '$low - $high';
         } else if (low != null) {
           rangeString = '> $low'; // Assumes lower bound only means greater than
         } else if (high != null) {
           rangeString = '< $high'; // Assumes upper bound only means less than
         } else {
           rangeString = 'No Ref.'; // Should not happen if one was not null
         }
      } else {
         rangeString = 'No Ref.'; // Fallback if no reference info at all
      }
      // ----------------------------------
      
      Color? cardBackgroundColor;
      if (param.status == ParameterStatus.attention) {
          cardBackgroundColor = Colors.amber.shade50;
      }
      
      final bool showPercentage = param.value != null && 
                                  param.resultString != null && 
                                  param.resultString!.isNotEmpty; 

      return Card(
         margin: const EdgeInsets.symmetric(vertical: 5.0),
         color: cardBackgroundColor, 
         // Wrap ListTile in InkWell or GestureDetector for onLongPress
         child: InkWell(
            onTap: () => _navigateToParameterDetail(param),
            onLongPress: onLongPress, // Assign the handler
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              child: Row(
                  children: [
                    // Status Icon on the left
                    Icon(statusIcon, color: statusColor, size: 28),
                    // Show star conditionally AFTER status icon
                    if (isTracked)
                      Padding(
                         padding: const EdgeInsets.only(left: 8.0), // Space after status icon
                         child: Icon(Icons.star, color: Colors.amber.shade600, size: 18),
                       ), 
                    const SizedBox(width: 12),
                    // Main content (Name, Range, Value)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row for Name and Star
                          Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                                Flexible( // Allow name to wrap/flex
                                  child: Text(
                                      param.parameterName, 
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                                      maxLines: 2, // Allow wrapping
                                      overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                             ],
                          ),
                           // Show percentage below name if applicable
                           if (showPercentage) ...[
                              const SizedBox(height: 2),
                              Text(
                                 '(${param.resultString}%)', 
                                 style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700])
                              ),
                           ],
                          const SizedBox(height: 4),
                          Text(rangeString, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Trailing section (Value, Unit, Chevron)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline, // Align value and unit
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                            primaryDisplay, 
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold, 
                              color: numericValue != null ? statusColor : null, // Use numericValue here
                            )
                        ),
                        // --- Show unit only if value is numeric and unit exists ---
                        if (displayUnit.isNotEmpty && numericValue != null) ...[
                          const SizedBox(width: 4), // Space between value and unit
                          Text(
                            displayUnit,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                          ),
                        ],
                        // ---------------------------------------------------------
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
                      ],
                    ),
                  ],
              ),
            ),
         ),
      );
   }

} 