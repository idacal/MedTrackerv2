import 'package:flutter/material.dart';
import 'dart:math'; // For max/min
import 'package:intl/intl.dart'; // For number formatting

import 'package:medtracker_app/main.dart'; // For StatusColors
import 'package:medtracker_app/models/parameter_record.dart';
import 'package:medtracker_app/screens/parameter_detail_screen.dart';
import 'package:medtracker_app/services/database_service.dart';

class ParameterListScreen extends StatefulWidget {
  final ParameterStatus targetStatus;
  final int totalParameterCount; // Added total count

  const ParameterListScreen({
    super.key, 
    required this.targetStatus, 
    required this.totalParameterCount 
  });

  @override
  State<ParameterListScreen> createState() => _ParameterListScreenState();
}

class _ParameterListScreenState extends State<ParameterListScreen> {
  final dbService = DatabaseService();
  late Future<List<ParameterRecord>> _filteredParametersFuture;
  final NumberFormat _valueFormatter = NumberFormat("#,##0.##");
  final NumberFormat _diffFormatter = NumberFormat("+#,##0.##;-#,##0.##"); // Format for difference

  @override
  void initState() {
    super.initState();
    _loadFilteredParameters();
  }

  Future<void> _loadFilteredParameters() async {
    setState(() {
      _filteredParametersFuture = dbService.getLatestParameterValues().then((allLatest) {
        return allLatest.where((p) => p.status == widget.targetStatus).toList();
      });
    });
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

     return Card(
       color: cardBackgroundColor, // Apply conditional background
       margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 0), // No horizontal margin needed due to padding
       elevation: cardBackgroundColor != null ? 1.5 : 1.0, // Slightly more elevation if colored
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
       child: InkWell( // Make the card tappable
         onTap: () => _navigateToParameterDetail(record),
         borderRadius: BorderRadius.circular(12.0), // Match card shape
         child: Padding(
           padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
           child: Row(
             children: [
               // Left: Icon
               Icon(statusIcon, color: statusColor, size: 36),
               const SizedBox(width: 12),
               // Center: Parameter Name and Date/Diff
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(record.parameterName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
                     const SizedBox(height: 3),
                      // --- Add Category back --- 
                     Text(
                         record.category.toUpperCase(), 
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600], fontSize: 11)
                     ),
                     const SizedBox(height: 5),
                     // --- Add Reference Range back --- 
                     Text(
                       'Referencia: ${record.refOriginal ?? "--"}',
                       style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                     ),
                     // --- Show date or difference text (adjust spacing if needed) ---
                     if (differenceText.isNotEmpty) ...[ // Only show diff if it exists
                       const SizedBox(height: 5),
                       Text(
                         differenceText, 
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(color: statusColor.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w500)
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
                           color: numericValue != null ? statusColor : null // Color if numeric
                         )
                       ),
                       // --- Show unit only if value is numeric and unit exists ---
                       if (displayUnit.isNotEmpty && numericValue != null) ...[
                          const SizedBox(width: 4), // Space
                          Text(
                            displayUnit,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
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
} 