import 'package:flutter/material.dart';
import 'dart:math'; // For max/min
import 'package:intl/intl.dart'; // For number formatting
import 'package:fl_chart/fl_chart.dart'; // Import the chart package
import 'package:collection/collection.dart'; // For firstWhereOrNull

import '../services/database_service.dart';
import '../models/parameter_record.dart';
import '../main.dart'; // For StatusColors

class ParameterDetailScreen extends StatefulWidget {
  final String categoryName;
  final String parameterName;

  const ParameterDetailScreen({
    super.key,
    required this.categoryName,
    required this.parameterName,
  });

  @override
  State<ParameterDetailScreen> createState() => _ParameterDetailScreenState();
}

class _ParameterDetailScreenState extends State<ParameterDetailScreen> {
  late Future<List<ParameterRecord>> _historyFuture;
  final dbService = DatabaseService();
  final NumberFormat _valueFormatter = NumberFormat("#,##0.##");
   // Format for difference, showing sign explicitly
  final NumberFormat _diffFormatter = NumberFormat("+#,##0.##;-#,##0.##;0");
  final DateFormat _chartTooltipFormatter = DateFormat('dd MMM yy');
  // Simpler format for axis labels
  final DateFormat _chartAxisFormatter = DateFormat("MMM ''yy");

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = dbService.getParameterHistory(
          widget.categoryName,
          widget.parameterName);
    });
  }

  // Helper to get status color (uses extension method now)
  Color _getStatusColor(BuildContext context, ParameterStatus status) {
    return StatusColors.of(context).getColor(status);
  }

  // Helper to get appropriate icon for status
  IconData _getStatusIcon(ParameterStatus status) {
     switch (status) {
      case ParameterStatus.normal:
        return Icons.check_circle; // Filled check
      case ParameterStatus.watch:
        return Icons.watch_later; // Or warning icon
      case ParameterStatus.attention:
        return Icons.warning_amber_rounded; // Filled warning icon
      case ParameterStatus.unknown:
      default:
        return Icons.help_outline; // Help icon
    }
  }

  @override
  Widget build(BuildContext context) {
     final statusColors = StatusColors.of(context); // Still useful for direct access if needed

    return Scaffold(
      // --- Custom Header (AppBar) ---
      appBar: AppBar(
        title: Text(widget.parameterName), // Parameter name in title
        backgroundColor: Theme.of(context).primaryColor, // Match mockup style
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<ParameterRecord>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Use the correct status color for error message
            Color errorColor = statusColors.attention; 
            return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error al cargar historial: ${snapshot.error}', style: TextStyle(color: errorColor))));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No hay historial disponible para este parámetro.')));
          }

          final history = snapshot.data!;
          final latestRecord = history.first;
          final latestValueString = latestRecord.value != null ? _valueFormatter.format(latestRecord.value) : 'N/A';
          final latestStatusColor = _getStatusColor(context, latestRecord.status);
          const String unit = ""; // TODO: Placeholder for unit
          final String rangeString = latestRecord.refOriginal ?? 'No Ref.';

          // Prepare chart data
           final chartData = history.reversed
             .where((record) => record.value != null)
             .map((record) => FlSpot(
                  record.date.millisecondsSinceEpoch.toDouble(),
                  record.value!,
             ))
             .toList();

          // --- Main Content ---
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Card Valor Actual ---
              _buildCurrentValueCard(context, latestRecord, latestValueString, unit, rangeString, latestStatusColor),
              const SizedBox(height: 16), // Spacing

              // --- NEW: Status Message Card ---
              if (latestRecord.status != ParameterStatus.normal && latestRecord.status != ParameterStatus.unknown)
                  _buildStatusMessageCard(context, latestRecord, latestStatusColor),
              if (latestRecord.status != ParameterStatus.normal && latestRecord.status != ParameterStatus.unknown)
                  const SizedBox(height: 16), // Spacing only if message card shown

              // --- Card Evolución (Gráfico) ---
              Card(
                 child: Padding(
                   padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('Evolución', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 20),
                       if (chartData.length < 2)
                         const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Text('No hay suficientes datos para graficar.')))
                       else
                         SizedBox(
                            height: 200,
                            child: _buildLineChart(context, chartData, latestRecord),
                         ),
                     ],
                   ),
                 ),
              ),
              const SizedBox(height: 16), // Spacing
              
              // --- NEW: Description Card (if description exists) ---
              if (latestRecord.description != null && latestRecord.description!.isNotEmpty)
                  _buildDescriptionCard(context, latestRecord.description!),
              if (latestRecord.description != null && latestRecord.description!.isNotEmpty)
                   const SizedBox(height: 16), // Spacing only if description shown

              // --- Recommendation Card (using new field) ---
              // Show recommendation only if it exists
              if (latestRecord.recommendation != null && latestRecord.recommendation!.isNotEmpty)
                  _buildRecommendationCard(context, latestRecord.recommendation!), // Pass only the recommendation string

            ],
          );
        },
      ),
    );
  }

 // --- Widget Builder Methods ---

 Widget _buildCurrentValueCard(BuildContext context, ParameterRecord latestRecord, String latestValueString, String unit, String rangeString, Color latestStatusColor) {
      // Get both potential values
      final numericValue = latestRecord.value;
      final secondaryString = latestRecord.resultString;
      final primaryDisplay = latestRecord.displayValue; // Numeric or text
      final valueColor = numericValue != null ? latestStatusColor : Theme.of(context).textTheme.bodyLarge?.color;
      // Check if we have the percentage case
      final bool showPercentage = numericValue != null && secondaryString != null && secondaryString.isNotEmpty;
      
      // --- Improved Range String Logic (same as CategoryParametersScreen) ---
      String displayRangeString;
      if (latestRecord.refOriginal != null && latestRecord.refOriginal!.isNotEmpty) {
         displayRangeString = latestRecord.refOriginal!;
      } else if (latestRecord.refRangeLow != null || latestRecord.refRangeHigh != null) {
         // Format numeric range if original is missing
         final formatter = _valueFormatter; // Use existing formatter
         final low = latestRecord.refRangeLow != null ? formatter.format(latestRecord.refRangeLow) : null;
         final high = latestRecord.refRangeHigh != null ? formatter.format(latestRecord.refRangeHigh) : null;
         if (low != null && high != null) {
           displayRangeString = '$low - $high';
         } else if (low != null) {
           displayRangeString = '> $low'; 
         } else if (high != null) {
           displayRangeString = '< $high'; 
         } else {
           displayRangeString = 'No Ref.';
         }
      } else {
         displayRangeString = 'No Ref.';
      }
      // -------------------------------------------------------------------

      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Valor Actual', style: TextStyle(color: Colors.grey[700])), 
                const SizedBox(height: 8),
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline, 
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        primaryDisplay, // Show absolute value or text
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold, 
                          color: valueColor // Apply status color only if numeric
                        ),
                      ),
                      // Show unit only if value is numeric 
                      if (unit.isNotEmpty && numericValue != null) ...[
                        const SizedBox(width: 4),
                        Padding(
                            padding: const EdgeInsets.only(bottom: 4.0), 
                            child: Text(
                              unit, 
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey[700]),
                            ),
                        ),
                      ]
                    ],
                ),
                 // Show percentage below if applicable
                if (showPercentage) ...[
                   const SizedBox(height: 4),
                   Text(
                     '($secondaryString %)', // Show percentage
                     style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700])
                   ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Valores normales: $displayRangeString', // Use the updated displayRangeString
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                  ),
              ]
          ),
        ),
      );
 }

 // --- NEW: Status Message Card Builder ---
 Widget _buildStatusMessageCard(BuildContext context, ParameterRecord record, Color statusColor) {
    String message = "";
    IconData icon = _getStatusIcon(record.status); // Get appropriate icon
    // Use the darker foreground colors from the fixed version
    Color backgroundColor; 
    Color foregroundColor; 

    // Determine message, icon, and colors based on status
    switch (record.status) {
       case ParameterStatus.watch:
          backgroundColor = Colors.orange.shade50; // Very light orange background
          foregroundColor = Colors.orange.shade800; // Darker orange for text/icon
          if (record.value != null && record.refRangeLow != null && record.value! < record.refRangeLow!) {
             message = "Ligeramente por debajo del valor normal";
          } else if (record.value != null && record.refRangeHigh != null && record.value! > record.refRangeHigh!) {
             message = "Ligeramente por encima del valor normal";
          } else {
             message = "Valor en rango de vigilancia"; // Fallback
          }
          break;
       case ParameterStatus.attention:
          backgroundColor = Colors.amber.shade50; // Very light amber background
          foregroundColor = Colors.amber.shade900; // Darker amber for text/icon
           if (record.value != null && record.refRangeLow != null && record.value! < record.refRangeLow!) {
             message = "Valor por debajo del rango normal";
          } else if (record.value != null && record.refRangeHigh != null && record.value! > record.refRangeHigh!) {
             message = "Valor por encima del rango normal";
          } else {
             message = "Requiere atención"; // Fallback
          }
          break;
       // Add cases for normal/unknown if you want messages for them too
       default:
          return Container(); // Don't show for normal/unknown by default
    }

    return Card(
       color: backgroundColor,
       elevation: 1.0,
       shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          // Use the darker foregroundColor for the border for consistency
          side: BorderSide(color: foregroundColor.withOpacity(0.3), width: 1) 
       ),
       child: Padding(
         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
         child: Row(
           children: [
             // Use the determined darker foregroundColor
             Icon(icon, color: foregroundColor, size: 24),
             const SizedBox(width: 12),
             Expanded(
               child: Text(
                 message, 
                 // Use the determined darker foregroundColor
                 style: Theme.of(context).textTheme.titleSmall?.copyWith(color: foregroundColor, fontWeight: FontWeight.w500),
               ),
             ),
           ],
         ),
       ),
    );
 }

 // --- NEW: Description Card Builder ---
 Widget _buildDescriptionCard(BuildContext context, String description) {
    return Card(
       color: Colors.blueGrey.shade50, // A neutral, soft background
       elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: Colors.blueGrey.shade100, width: 1) // Optional border
       ),
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               children: [
                 Icon(Icons.info_outline, color: Colors.blueGrey.shade700, size: 20),
                 const SizedBox(width: 8),
                 Text(
                   'Descripción del Parámetro',
                   style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)
                 ),
               ],
             ),
             const SizedBox(height: 10),
             Text(
               description,
               style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
             ),
           ],
         ),
       ),
    );
 }

 // --- Updated Recommendation Card Builder (uses direct recommendation text) ---
 Widget _buildRecommendationCard(BuildContext context, String recommendation) {
    // Use a distinct but soft background color
    Color recommendationBgColor = Colors.lightBlue.shade50;

    return Card(
       color: recommendationBgColor,
       elevation: 1.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(color: Colors.lightBlue.shade100, width: 1) // Optional border
       ),
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               children: [
                 Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20), // Changed Icon
                 const SizedBox(width: 8),
                 Text(
                   'Recomendación General',
                   style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade800)
                 ),
               ],
             ),
             const SizedBox(height: 10),
             Text(
               recommendation, // Display the recommendation passed from the record
               style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
             ),
           ],
         ),
       ),
    );
 }

  // --- Line Chart Builder ---
  Widget _buildLineChart(BuildContext context, List<FlSpot> spots, ParameterRecord latestRecord) {
    final statusColors = StatusColors.of(context);
     final lineStyle = LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary, // Chart line color
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true, // Show dots on data points
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(radius: 4, color: Theme.of(context).colorScheme.primary, strokeWidth: 1, strokeColor: Colors.white),
            ),
            belowBarData: BarAreaData(
              show: true, // Optional gradient below line
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  Theme.of(context).colorScheme.primary.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          );

      // Determine min/max Y based on data and reference range
      double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      if(latestRecord.refRangeLow != null) minY = min(minY, latestRecord.refRangeLow!);
      if(latestRecord.refRangeHigh != null) maxY = max(maxY, latestRecord.refRangeHigh!);

      // Add padding and handle case where min == max
      double effectiveMinY = minY;
      double effectiveMaxY = maxY;
      if (effectiveMinY == effectiveMaxY) {
        effectiveMinY -= 1.0;
        effectiveMaxY += 1.0;
      }
      double yPadding = (effectiveMaxY - effectiveMinY) * 0.15; // 15% padding
      effectiveMinY -= yPadding;
      effectiveMaxY += yPadding;
      // Ensure min Y is not excessively low
      if (effectiveMinY < 0 && spots.every((s) => s.y >= 0) && latestRecord.refRangeLow == null) effectiveMinY = 0;

      // Calculate interval AFTER adjusting min/max Y
      double horizontalInterval = (effectiveMaxY - effectiveMinY) / 4;
      // Ensure interval is valid
      if (horizontalInterval <= 0) {
        horizontalInterval = 1; // Default interval if calculation fails
      }

      // Horizontal lines for reference range
       List<HorizontalLine> horizontalLines = [];
       // Use the color for 'watch' status for the reference lines
       Color refLineColor = statusColors.watch; 
       if (latestRecord.refRangeLow != null) {
         horizontalLines.add(HorizontalLine(
            y: latestRecord.refRangeLow!,
            color: refLineColor.withOpacity(0.8),
            strokeWidth: 1,
            dashArray: [5, 5],
            label: HorizontalLineLabel(show: false)
          ));
       }
        if (latestRecord.refRangeHigh != null) {
         horizontalLines.add(HorizontalLine(
            y: latestRecord.refRangeHigh!,
            color: refLineColor.withOpacity(0.8),
            strokeWidth: 1,
            dashArray: [5, 5],
            label: HorizontalLineLabel(show: false)
          ));
       }

    return LineChart(
      LineChartData(
        minY: effectiveMinY,
        maxY: effectiveMaxY,
        lineBarsData: [lineStyle],
        clipData: FlClipData.all(), // Clip line to border
        gridData: FlGridData(
           show: true,
           drawVerticalLine: false,
           horizontalInterval: horizontalInterval,
           getDrawingHorizontalLine: (value) {
             return FlLine(
               color: Colors.grey[300],
               strokeWidth: 0.5,
             );
           },
        ),
        borderData: FlBorderData(
           show: true,
           border: Border(
             bottom: BorderSide(color: Colors.grey[400]!, width: 1),
             left: BorderSide(color: Colors.grey[400]!, width: 1),
           )
        ),
        titlesData: FlTitlesData(
           leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40,
                interval: horizontalInterval,
                getTitlesWidget: leftTitleWidgets
              ),
           ),
           bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                interval: _calculateDateInterval(spots),
                // Pass spots to the title widget function
                getTitlesWidget: (value, meta) => bottomTitleWidgets(value, meta, spots)
              ),
           ),
           topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
           rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
         extraLinesData: ExtraLinesData(horizontalLines: horizontalLines),
         lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                 return touchedSpots.map((LineBarSpot touchedSpot) {
                    final DateTime date = DateTime.fromMillisecondsSinceEpoch(touchedSpot.x.toInt());
                    final String dateStr = _chartTooltipFormatter.format(date);
                    final String valueStr = _valueFormatter.format(touchedSpot.y);
                    return LineTooltipItem(
                      '$valueStr\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      children: [TextSpan(text: dateStr, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.normal, fontSize: 12))]
                    );
                  }).toList();
              }
            ),
         ),
      ),
    );
  }

  // Helper for Y Axis labels
   Widget leftTitleWidgets(double value, TitleMeta meta) {
    final style = TextStyle(color: Colors.grey[700], fontSize: 10);
    String text = _valueFormatter.format(value);
    // Avoid showing min/max labels if they are too close to the edges or zero
    if (value == meta.min || value == meta.max || (value == 0 && meta.min < 0) ) return Container();
    return SideTitleWidget(meta: meta, space: 6, child: Text(text, style: style));
  }

  // Helper for X Axis labels - FILTERS BASED ON ACTUAL SPOT DATA
  Widget bottomTitleWidgets(double value, TitleMeta meta, List<FlSpot> spots) {
    final style = TextStyle(color: Colors.grey[700], fontSize: 10);

    // Check if the current value corresponds to an actual data point
    final bool isDataPoint = spots.any((spot) => spot.x.toInt() == value.toInt());

    if (isDataPoint) {
       final DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
       // Use the simpler axis formatter
       final String text = _chartAxisFormatter.format(date);
       return SideTitleWidget(meta: meta, space: 6, child: Text(text, style: style, textAlign: TextAlign.center));
    } else {
        // Don't show a label if it doesn't correspond to a data point
        return Container();
    }
  }

  // Calculate appropriate interval for date axis labels
  double _calculateDateInterval(List<FlSpot> spots) {
    if (spots.length < 2) return 1;
    final double minDateMillis = spots.first.x;
    final double maxDateMillis = spots.last.x;
    final double durationDays = (maxDateMillis - minDateMillis) / (1000 * 60 * 60 * 24);

    double intervalMillis;
    if (durationDays <= 14) {
      intervalMillis = 4 * 24 * 60 * 60 * 1000; // ~4 days interval
    } else if (durationDays <= 90) {
       intervalMillis = 30 * 24 * 60 * 60 * 1000; // ~1 month interval
    } else if (durationDays <= 365) {
       intervalMillis = 90 * 24 * 60 * 60 * 1000; // ~3 months interval
    } else {
       intervalMillis = 365 * 24 * 60 * 60 * 1000; // ~1 year interval
    }

    const double minIntervalMillis = 24 * 60 * 60 * 1000; // One day minimum
    return max(intervalMillis, minIntervalMillis);
  }

   // --- Math helpers for min/max ---
  double min(double a, double b) => a < b ? a : b;
  double max(double a, double b) => a > b ? a : b;
}

// Extension is now defined in main.dart 