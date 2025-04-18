import 'package:flutter/material.dart';
import 'dart:math'; // For max/min
import 'package:intl/intl.dart'; // For number formatting
import 'package:provider/provider.dart';

import 'package:medtracker_app/main.dart'; // For StatusColors
import 'package:medtracker_app/models/parameter_record.dart';
import 'package:medtracker_app/screens/parameter_detail_screen.dart';
import 'package:medtracker_app/services/database_service.dart';

class ParameterListScreen extends StatefulWidget {
  final ParameterStatus targetStatus;
  final int totalParameterCount; // Added total count
  final VoidCallback? onTrackingChanged; // <-- ADD THIS CALLBACK

  const ParameterListScreen({
    super.key, 
    required this.targetStatus, 
    required this.totalParameterCount,
    this.onTrackingChanged, // <-- INITIALIZE CALLBACK
  });

  @override
  State<ParameterListScreen> createState() => _ParameterListScreenState();
}

class _ParameterListScreenState extends State<ParameterListScreen> {
  final dbService = DatabaseService();
  late Future<List<ParameterRecord>> _filteredParametersFuture;
  final NumberFormat _valueFormatter = NumberFormat("#,##0.##");
  final NumberFormat _diffFormatter = NumberFormat("+#,##0.##;-#,##0.##"); // Format for difference

  // --- State for Tracking --- 
  Set<String> _trackedParameterKeys = {};
  bool _isLoadingTracking = true;
  // ------------------------

  @override
  void initState() {
    super.initState();
    _loadFilteredParameters();
    _loadTrackingStatus(); // Load tracking status initially
  }

  Future<void> _loadFilteredParameters() async {
    setState(() {
      _filteredParametersFuture = dbService.getLatestParameterValues().then((allLatest) {
        return allLatest.where((p) => p.status == widget.targetStatus).toList();
      });
    });
  }

  Future<void> _loadTrackingStatus() async {
    if (!mounted) return;
    setState(() { _isLoadingTracking = true; });
    try {
       final trackedNames = await dbService.getTrackedParameterNames();
       final Set<String> keys = {};
       for (var item in trackedNames) {
          if (item['categoryName'] != null && item['parameterName'] != null) {
             keys.add("${item['categoryName']}_${item['parameterName']}");
          }
       }
       if (mounted) {
         setState(() {
           _trackedParameterKeys = keys;
           _isLoadingTracking = false;
         });
       }
    } catch (e) {
      print("Error loading tracking status in ParameterListScreen: $e");
       if (mounted) {
          setState(() { _isLoadingTracking = false; });
          // Optionally show error snackbar?
       }
    }
  }

  String _getTitleForStatus(ParameterStatus status, {bool short = false}) {
    switch (status) {
      case ParameterStatus.normal:
        return short ? 'Normales' : 'Parámetros Normales';
      case ParameterStatus.watch:
        return short ? 'A Vigilar' : 'Parámetros a Vigilar';
      case ParameterStatus.attention:
        return short ? 'Atención' : 'Parámetros que requieren Atención';
      case ParameterStatus.unknown:
        return short ? 'Desconocidos' : 'Parámetros Desconocidos';
    }
  }

  IconData _getStatusIcon(ParameterStatus status) {
     switch (status) {
      case ParameterStatus.normal:
        return Icons.check_circle;
      case ParameterStatus.watch:
        return Icons.watch_later; // Or a warning/info icon
      case ParameterStatus.attention:
        return Icons.warning; // Filled warning icon
      case ParameterStatus.unknown:
        return Icons.help;
    }
  }

  void _navigateToParameterDetail(ParameterRecord record) {
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParameterDetailScreen(
          categoryName: record.category, 
          parameterName: record.parameterName
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColors = StatusColors.of(context);
    final statusColor = statusColors.getColor(widget.targetStatus);
    final title = _getTitleForStatus(widget.targetStatus);
    final shortTitle = _getTitleForStatus(widget.targetStatus, short: true);

    return Scaffold(
      // No AppBar, using custom header
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Custom Header (similar to HomeScreen but simpler) ---
          _buildHeader(context, title),
          // --- Padding for the rest of the content ---
          Expanded(
             child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: FutureBuilder<List<ParameterRecord>>(
                future: _filteredParametersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error al cargar parámetros: ${snapshot.error}', style: TextStyle(color: statusColors.attention))));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('No se encontraron parámetros con estado "$shortTitle".')));
                  }

                  final parameters = snapshot.data!;
                  
                  // Use a standard ListView instead of ListView.builder for simplicity
                  // if mixing widgets like Summary Card and the list.
                  return ListView(
                     padding: const EdgeInsets.only(top: 10, bottom: 16), // Adjust padding
                     children: [
                       // --- Summary Card ---
                        _buildSummaryCard(context, parameters.length, widget.totalParameterCount, shortTitle, statusColor),
                        const SizedBox(height: 10), // Space before list

                       // --- Parameter List --- Generate detailed cards
                       ...parameters.map((param) => _buildDetailedParameterCard(context, param)).toList(),
                     ]
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // --- Custom Header Widget ---
   Widget _buildHeader(BuildContext context, String title) {
     return Material(
        elevation: 2.0,
        child: Container(
           color: Theme.of(context).primaryColor, // Or statusColor?
           padding: EdgeInsets.only(
             top: MediaQuery.of(context).padding.top + 10, // Adjust for status bar
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
               ),
               const SizedBox(width: 10),
               Expanded(
                 child: Text(
                   title,
                   style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
             ],
           ),
        ),
     );
   }
   
   // --- Summary Card Widget ---
  Widget _buildSummaryCard(BuildContext context, int count, int total, String shortStatusName, Color statusColor) {
     double fraction = total > 0 ? count / total : 0;
     // Use the short status name directly and make it lowercase
     String statusNameForText = shortStatusName.toLowerCase();
     
     return Card(
       elevation: 1.0, // Less elevation for summary card
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text('Resumen', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
             const SizedBox(height: 10),
             Row(
                children: [
                    Expanded(
                       child: ClipRRect(
                         borderRadius: BorderRadius.circular(8),
                         child: LinearProgressIndicator(
                           value: fraction,
                           minHeight: 8,
                           backgroundColor: Colors.grey[300],
                           valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                         ),
                       ),
                    ),
                ],
             ),
             const SizedBox(height: 8),
             // Use the correctly formatted lowercase status name
             Text(
               '$count de $total parámetros en estado $statusNameForText',
               style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])
             ),
           ],
         ),
       ),
     );
   }
   
   // --- Detailed Parameter Card Widget (REPLACED ListTile with Card layout) ---
   Widget _buildDetailedParameterCard(BuildContext context, ParameterRecord record) {
     final statusColors = StatusColors.of(context);
     final statusColor = statusColors.getColor(record.status);
     final statusIcon = _getStatusIcon(record.status);
     final numericValue = record.value; // Get numeric value
     final displayUnit = record.unit ?? ''; // Get unit
     final parameterKey = "${record.category}_${record.parameterName}"; // Key for tracking
     final bool isTracked = _trackedParameterKeys.contains(parameterKey); // Check tracking status
     
     // Determine background color based on status 
     Color? cardBackgroundColor;
     if (record.status == ParameterStatus.attention) {
       cardBackgroundColor = Colors.amber.shade50; // Light amber for attention
     } else if (record.status == ParameterStatus.watch) {
        cardBackgroundColor = Colors.orange.shade50; // Light orange for watch
     }
     
     // Calculate difference text if value and range exist
     String differenceText = '';
     if (record.value != null) {
        if (record.refRangeLow != null && record.value! < record.refRangeLow!) {
            differenceText = '${_diffFormatter.format(record.value! - record.refRangeLow!)} bajo límite mínimo';
        } else if (record.refRangeHigh != null && record.value! > record.refRangeHigh!) {
           differenceText = '${_diffFormatter.format(record.value! - record.refRangeHigh!)} sobre límite máximo';
        }
     }

     // --- Define text colors based on theme and background --- 
     final Brightness currentBrightness = Theme.of(context).brightness;
     final bool isAttention = record.status == ParameterStatus.attention;
     final Color defaultTextColor = Theme.of(context).textTheme.bodyMedium?.color ?? (currentBrightness == Brightness.dark ? Colors.white : Colors.black);
     
     Color titleColor;
     Color categoryColor;
     Color referenceColor;
     Color unitDisplayColor;
     
     if (isAttention && currentBrightness == Brightness.light) {
       // Attention + Light Mode: Dark text on light yellow
       titleColor = Colors.black87;
       categoryColor = Colors.black54;
       referenceColor = Colors.black54;
       unitDisplayColor = Colors.black54;
     } else if (isAttention && currentBrightness == Brightness.dark) {
       // Attention + Dark Mode: Dark text on light yellow (same as light mode)
       titleColor = Colors.black87;
       categoryColor = Colors.black54;
       referenceColor = Colors.black54;
       unitDisplayColor = Colors.black54;
     } else {
        // Default: Use theme colors
        titleColor = Theme.of(context).textTheme.titleMedium?.color ?? defaultTextColor;
        final Color defaultSubtitleColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey[600]!;
        categoryColor = defaultSubtitleColor;
        referenceColor = defaultSubtitleColor;
        unitDisplayColor = defaultSubtitleColor;
     }

     final Color valueColor = numericValue != null ? statusColor : defaultTextColor; 
     // Keep difference text color as status color
     final Color differenceDisplayColor = statusColor.withOpacity(0.9);
     // -------------------------------------------------------

     return Card(
       color: cardBackgroundColor, // Apply conditional background
       margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0), // No horizontal margin needed due to padding
       elevation: cardBackgroundColor != null ? 1.5 : 1.0, // Slightly more elevation if colored
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
       child: InkWell( // Make the card tappable
         onTap: () => _navigateToParameterDetail(record),
         onLongPress: () => _handleLongPress(context, record),
         borderRadius: BorderRadius.circular(12.0), // Match card shape
         child: Padding(
           padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
           child: Row(
             children: [
               // Left: Icon + Optional Star
               Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Icon(statusIcon, color: statusColor, size: 36),
                     const SizedBox(width: 6),
                     // Show star icon ONLY if tracked and status loaded
                     if (!_isLoadingTracking && isTracked)
                         Icon(
                            Icons.star, // Only show filled star 
                            color: Colors.amber.shade600,
                            size: 18,
                         ), 
                      // Show loader if tracking status is loading
                      if (_isLoadingTracking) 
                          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      // Add placeholder SizedBox if not loading AND not tracked to maintain layout
                      if (!_isLoadingTracking && !isTracked)
                         const SizedBox(width: 18), // Empty space if not tracked
                  ],
               ),
               const SizedBox(width: 12),
               // Center: Parameter Name and Date/Diff
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(record.parameterName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500, color: titleColor)),
                     const SizedBox(height: 3),
                      // --- Add Category back --- 
                     Text(
                         record.category.toUpperCase(), 
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(color: categoryColor, fontSize: 11)
                     ),
                     const SizedBox(height: 5),
                     // --- Add Reference Range back --- 
                     Text(
                       'Referencia: ${record.refOriginal ?? "--"}',
                       style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11, color: referenceColor),
                     ),
                     // --- Show date or difference text (adjust spacing if needed) ---
                     if (differenceText.isNotEmpty) ...[ // Only show diff if it exists
                       const SizedBox(height: 5),
                       Text(
                         differenceText, 
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(color: differenceDisplayColor, fontSize: 11, fontWeight: FontWeight.w500)
                       ),
                     ] else ... [ // Otherwise, show date (consider if needed here or only on detail screen)
                        // Currently, date is not shown here if diff text is empty, keep it that way for now?
                        // Or add: const SizedBox(height: 3), Text(DateFormat('dd MMM yy').format(record.date), style: ...)
                     ]
                   ],
                 ),
               ),
               const SizedBox(width: 12),
               // Right: Value and Unit (if available)
               Column(
                 mainAxisAlignment: MainAxisAlignment.center, // Center vertically
                 crossAxisAlignment: CrossAxisAlignment.end,   // Align text to the right
                 children: [
                   Row( // Row for value and unit
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.baseline,
                     textBaseline: TextBaseline.alphabetic,
                     children: [
                       Text(
                         record.displayValue, 
                         style: Theme.of(context).textTheme.titleLarge?.copyWith(
                           fontWeight: FontWeight.bold, 
                           color: valueColor
                         )
                       ),
                       // --- Show unit only if value is numeric and unit exists ---
                       if (displayUnit.isNotEmpty && numericValue != null) ...[
                          const SizedBox(width: 4), // Space
                          Text(
                            displayUnit,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: unitDisplayColor),
                          ),
                       ],
                       // ---------------------------------------------------------
                     ],
                   ),
                 ],
               ),
             ],
           ),
         ),
       ),
     );
   }

  // --- Renamed method to handle long press logic ---
  Future<void> _handleLongPress(BuildContext context, ParameterRecord parameter) async {
     final parameterKey = "${parameter.category}_${parameter.parameterName}";
     final bool isCurrentlyTracked = _trackedParameterKeys.contains(parameterKey);
     final String actionVerb = isCurrentlyTracked ? 'Dejar de seguir' : 'Seguir';
     final String actionResultVerb = isCurrentlyTracked ? 'quitado de' : 'añadido a';
     
     // Show confirmation dialog
     final bool? confirmed = await showDialog<bool>(
       context: context,
       builder: (BuildContext dialogContext) {
         return AlertDialog(
           title: Text('$actionVerb Indicador'),
           content: Text('¿Quieres $actionVerb el parámetro "${parameter.parameterName}"?'),
           actions: <Widget>[
             TextButton(
               child: const Text('Cancelar'),
               onPressed: () => Navigator.of(dialogContext).pop(false),
             ),
             TextButton(
               style: TextButton.styleFrom(foregroundColor: isCurrentlyTracked ? Theme.of(context).colorScheme.error : null),
               child: Text(actionVerb),
               onPressed: () => Navigator.of(dialogContext).pop(true),
             ),
           ],
         );
       },
     );
     
     if (confirmed == true) {
       try {
         if (isCurrentlyTracked) {
           await dbService.removeTrackedParameter(parameter.category, parameter.parameterName);
         } else {
           await dbService.addTrackedParameter(parameter.category, parameter.parameterName);
         }
         
         // Update tracking status locally AFTER successful DB operation
         await _loadTrackingStatus(); 

         // Show confirmation SnackBar (check context mounted again)
         if (mounted && context.mounted) { 
           ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                 content: Text('"${parameter.parameterName}" $actionResultVerb seguimiento.', style: const TextStyle(color: Colors.white)), 
                 backgroundColor: Colors.green[700],
                 duration: const Duration(seconds: 2),
              ),
           );
           // --- Call the callback if provided --- 
           widget.onTrackingChanged?.call();
           // -------------------------------------
         }
       } catch (e) {
         print("Error updating tracking from ParameterListScreen: $e");
         if (mounted && context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(
                  content: Text('Error al $actionVerb "${parameter.parameterName}".', style: const TextStyle(color: Colors.white)), 
                  backgroundColor: Theme.of(context).colorScheme.error,
                  duration: const Duration(seconds: 2),
                ),
             );
         }
         // Optional: Reload status even on error to ensure consistency? 
         // await _loadTrackingStatus(); 
       }
     }
  }
  // ---------------------------------------------------------------
} 