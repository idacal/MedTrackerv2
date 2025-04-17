import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final DateFormat _chartTooltipFormatter = DateFormat('dd MMM yy');
  final DateFormat _chartAxisFormatter = DateFormat('MMM'); // Short month for axis

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

  // Helper to get status color (can be moved to utils)
  Color _getStatusColor(BuildContext context, ParameterStatus status) {
    final statusColors = StatusColors.of(context);
    switch (status) {
      case ParameterStatus.normal:
        return statusColors.normal;
      case ParameterStatus.watch:
        return statusColors.watch;
      case ParameterStatus.attention:
        return statusColors.attention;
      case ParameterStatus.unknown:
        return Colors.grey.shade600;
    }
  }
  
  @override
  Widget build(BuildContext context) {
     final statusColors = StatusColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.parameterName), // Parameter name in title
      ),
      body: FutureBuilder<List<ParameterRecord>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error al cargar historial: ${snapshot.error}', style: TextStyle(color: statusColors.attention))));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No hay historial disponible para este parámetro.')));
          }

          final history = snapshot.data!;
          // Data is ordered DESC by date, so first is latest
          final latestRecord = history.first;
          final latestValueString = latestRecord.value != null ? _valueFormatter.format(latestRecord.value) : 'N/A';
          final latestStatusColor = _getStatusColor(context, latestRecord.status);
          // TODO: Get unit (mg/dl etc.) - needs to be stored or inferred
          const String unit = ""; // Placeholder for unit
          final String rangeString = latestRecord.refOriginal ?? 'No Ref.';

          // Prepare data for the chart (reverse history for chronological order)
           final chartData = history.reversed
             .where((record) => record.value != null) // Only plot points with values
             .map((record) => FlSpot(
                  record.date.millisecondsSinceEpoch.toDouble(), // X axis: time
                  record.value!, // Y axis: value
             ))
             .toList();

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Card Valor Actual --- 
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.center,
                     children: [
                        const Text('Valor Actual', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                           mainAxisAlignment: MainAxisAlignment.center,
                           crossAxisAlignment: CrossAxisAlignment.baseline, // Align baseline of value and unit
                           textBaseline: TextBaseline.alphabetic,
                           children: [
                              Text(
                                latestValueString,
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold, color: latestStatusColor),
                              ),
                              if (unit.isNotEmpty) const SizedBox(width: 4),
                              if (unit.isNotEmpty)
                                Padding(
                                   padding: const EdgeInsets.only(bottom: 4.0), // Adjust alignment
                                   child: Text(
                                    unit, 
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey[700]),
                                  ),
                                ),
                           ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Valores normales: $rangeString', 
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                         ),
                     ]
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                            height: 200, // Fixed height for the chart
                            child: _buildLineChart(context, chartData, latestRecord),
                         ),
                     ],
                   ),
                 ),
              ),
            ],
          );
        },
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
        // If all values are the same, add a small range for display
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

      // Horizontal lines for reference range (if available)
       List<HorizontalLine> horizontalLines = [];
       if (latestRecord.refRangeLow != null) {
         horizontalLines.add(HorizontalLine(
            y: latestRecord.refRangeLow!, 
            color: statusColors.watch.withOpacity(0.8), 
            strokeWidth: 1,
            dashArray: [5, 5], // Dashed line
            label: HorizontalLineLabel(show: false)
          ));
       }
        if (latestRecord.refRangeHigh != null) {
         horizontalLines.add(HorizontalLine(
            y: latestRecord.refRangeHigh!, 
            color: statusColors.watch.withOpacity(0.8), 
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
        gridData: FlGridData(
           show: true,
           drawVerticalLine: false, // Hide vertical grid lines
           horizontalInterval: horizontalInterval, // Use calculated, validated horizontalInterval
           getDrawingHorizontalLine: (value) {
             return FlLine(
               color: Colors.grey[300], // Light grey grid lines
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
              sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: _calculateDateInterval(spots), getTitlesWidget: bottomTitleWidgets),
           ),
           topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
           rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
         // Reference range lines
         extraLinesData: ExtraLinesData(horizontalLines: horizontalLines),
         // Tooltip customization
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
    if (value == meta.min || value == meta.max) return Container(); 
    return SideTitleWidget(meta: meta, space: 6, child: Text(text, style: style));
  }

  // Helper for X Axis labels
  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    final style = TextStyle(color: Colors.grey[700], fontSize: 10);
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    final String text = _chartAxisFormatter.format(date);
    return SideTitleWidget(meta: meta, space: 6, child: Text(text, style: style));
  }

  // Calculate appropriate interval for date axis labels
  double _calculateDateInterval(List<FlSpot> spots) {
    if (spots.length < 2) return 1; // Default if not enough data
    final double minDateMillis = spots.first.x;
    final double maxDateMillis = spots.last.x;
    final double durationDays = (maxDateMillis - minDateMillis) / (1000 * 60 * 60 * 24);
    
    // Adjust interval based on duration (example logic)
    if (durationDays <= 14) { // 2 weeks
      return 2 * 24 * 60 * 60 * 1000; // ~2 days interval
    } else if (durationDays <= 90) { // 3 months
       return 15 * 24 * 60 * 60 * 1000; // ~15 days interval
    } else if (durationDays <= 365) { // 1 year
       return 60 * 24 * 60 * 60 * 1000; // ~2 months interval
    } else { // More than a year
       return 180 * 24 * 60 * 60 * 1000; // ~6 months interval
    }
  }
  
   // --- Math helpers for min/max --- 
  double min(double a, double b) => a < b ? a : b;
  double max(double a, double b) => a > b ? a : b;
} 