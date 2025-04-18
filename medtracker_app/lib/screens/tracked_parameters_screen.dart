import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For potential formatting

import '../services/database_service.dart';
import '../models/parameter_record.dart';
import '../main.dart'; // For StatusColors
import 'parameter_detail_screen.dart'; // For navigation

class TrackedParametersScreen extends StatefulWidget {
  const TrackedParametersScreen({super.key});

  @override
  State<TrackedParametersScreen> createState() => _TrackedParametersScreenState();
}

class _TrackedParametersScreenState extends State<TrackedParametersScreen> {
  final dbService = DatabaseService();
  Future<List<Map<String, dynamic>>>? _trackedParametersFuture;
  late StatusColors statusColors; // To use in cards

  // Define visuals based on CATEGORY (Copied from HomeScreen)
  final Map<String, Map<String, dynamic>> categoryVisuals = {
    'HEMATOLOGIA': { 'icon': Icons.water_drop_outlined, 'iconColor': Colors.red.shade300, 'bgColor': Colors.red.shade50 },
    'PERFIL BIOQUIMICO': { 'icon': Icons.science_outlined, 'iconColor': Colors.blue.shade300, 'bgColor': Colors.blue.shade50 },
    'VITAMINAS': { 'icon': Icons.spa_outlined, 'iconColor': Colors.green.shade400, 'bgColor': Colors.green.shade50 },
    'ENDOCRINOLOGIA': { 'icon': Icons.bubble_chart_outlined, 'iconColor': Colors.purple.shade200, 'bgColor': Colors.purple.shade50 },
    'default': { 'icon': Icons.monitor_heart, 'iconColor': Colors.grey.shade500, 'bgColor': Colors.grey.shade100 }
  };

  @override
  void initState() {
    super.initState();
    // Initialize statusColors in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    statusColors = StatusColors.of(context); // Get StatusColors
    _loadTrackedParameters(); // Load data now
  }

  Future<void> _loadTrackedParameters() async {
    setState(() {
      _trackedParametersFuture = dbService.getLatestTrackedParameterValues();
    });
  }

  void _navigateToParameterDetail(ParameterRecord parameter) {
     Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => ParameterDetailScreen(
          categoryName: parameter.category,
          parameterName: parameter.parameterName,
       )),
     ).then((_) => _loadTrackedParameters()); // Refresh list if tracking changed in detail view
  }

   // --- Handle Long Press for UnTracking ---
  Future<void> _showUnTrackDialog(ParameterRecord parameter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Dejar de Seguir Indicador'),
          content: Text('¿Quieres dejar de seguir el parámetro "${parameter.parameterName}"?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Dejar de Seguir'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await dbService.removeTrackedParameter(parameter.category, parameter.parameterName);
        // Update local state and refresh UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${parameter.parameterName}" quitado de seguimiento.')),
        );
        _loadTrackedParameters(); // Reload the list
      } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al quitar seguimiento: $e')),
         );
      }
    }
  }
  // ------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Indicadores Seguidos'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTrackedParameters,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _trackedParametersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error al cargar indicadores: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return LayoutBuilder( // Needed for refresh when empty
                 builder: (context, constraints) => SingleChildScrollView(
                   physics: const AlwaysScrollableScrollPhysics(),
                   child: ConstrainedBox(
                     constraints: BoxConstraints(minHeight: constraints.maxHeight),
                     child: const Center(child: Padding(
                       padding: EdgeInsets.all(24.0),
                       child: Text(
                         'No sigues ningún indicador todavía.\nMantén presionado un parámetro en la lista de una categoría para agregarlo.',
                         textAlign: TextAlign.center,
                       ),
                     )),
                   )
                 ),
              );
            }

            final trackedParametersData = snapshot.data!;

            return ListView.builder(
              itemCount: trackedParametersData.length,
              padding: const EdgeInsets.all(8.0),
              itemBuilder: (context, index) {
                final dataMap = trackedParametersData[index];
                final parameter = dataMap['record'] as ParameterRecord;
                final changeString = dataMap['changeString'] as String;
                return _buildTrackedParameterCard(context, parameter, changeString);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTrackedParameterCard(BuildContext context, ParameterRecord parameter, String changeString) {
    final NumberFormat valueFormatter = NumberFormat("#,##0.##"); // Keep formatter if needed
    final Color paramStatusColor = statusColors.getColor(parameter.status);
    final String displayValue = parameter.displayValue;
    final String displayUnit = parameter.unit ?? '';
    final bool isAttention = parameter.status == ParameterStatus.attention;
    final Color statusIconColor = statusColors.attention;
    
    // Get visuals based on category, fallback to default
    final visuals = categoryVisuals[parameter.category.toUpperCase()] ?? categoryVisuals['default']!;
    final Color bgColor = visuals['bgColor'] as Color;
    final Color iconColor = visuals['iconColor'] as Color;
    final IconData icon = visuals['icon'] as IconData;

    return Card(
       color: bgColor, // Use category background color
       elevation: 1.0,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
       margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 4.0), // Adjusted margin
       child: InkWell( // Keep InkWell for tap effect
         onTap: () => _navigateToParameterDetail(parameter),
         onLongPress: () => _showUnTrackDialog(parameter),
         child: Padding(
           padding: const EdgeInsets.all(12.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             // Use min size to avoid excessive height if content is short
             mainAxisSize: MainAxisSize.min, 
             children: [
               // Top Row: Star and Icon
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Icon(Icons.star, color: Colors.amber.shade600, size: 16), // Always tracked here
                   Icon(icon, color: iconColor, size: 18), // Use category icon/color
                 ],
               ),
               const SizedBox(height: 8), // Spacer

               // Middle Section: Title, Value, Unit
               Text(
                  parameter.parameterName, 
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis
                ),
               const SizedBox(height: 4),
               Row(
                 crossAxisAlignment: CrossAxisAlignment.baseline,
                 textBaseline: TextBaseline.alphabetic,
                 children: [
                   Text(displayValue, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 20)),
                   const SizedBox(width: 3),
                   Flexible(child: Text(displayUnit, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                 ],
               ),
               const SizedBox(height: 8), // Spacer

               // Bottom Row: Change display and Status Icon
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between change and status
                 children: [
                   // Change display (similar to HomeScreen)
                   Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       _getChangeIcon(changeString),
                       const SizedBox(width: 3),
                       Text(
                         changeString,
                         style: Theme.of(context).textTheme.bodySmall?.copyWith(
                           fontSize: 11,
                           color: _getChangeColor(changeString, context),
                         ),
                       ),
                     ],
                   ),
                   // Status Icon
                   if (isAttention)
                     Icon(Icons.warning_amber_rounded, size: 14, color: statusIconColor)
                   else 
                     const SizedBox(width: 14), // Keep placeholder if not attention
                 ],
               )
             ],
           ),
         ),
       ),
     );
  }

  // --- Add Change Icon/Color Helpers (Copied from HomeScreen) ---
  Widget _getChangeIcon(String change) {
    if (change.startsWith('+')) {
      return Icon(Icons.arrow_upward, size: 12, color: Colors.green[700]);
    } else if (change.startsWith('-')) {
      return Icon(Icons.arrow_downward, size: 12, color: Colors.red[700]);
    } else {
      return const SizedBox(width: 12);
    }
  }

  Color _getChangeColor(String change, BuildContext context) {
    if (change.startsWith('+')) {
      return Colors.green[700]!;
    } else if (change.startsWith('-')) {
      return Colors.red[700]!;
    } else {
       // Use a default text color from the theme if available
      return Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey[600]!;
    }
  }
  // ---------------------------------------------------------
} 