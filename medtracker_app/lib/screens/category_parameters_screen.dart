import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/parameter_record.dart';
import '../main.dart'; // Import main to access StatusColors

// Import parameter detail screen 
import 'parameter_detail_screen.dart'; // Import the new screen

// Import parameter detail screen (will create later)
// import 'parameter_detail_screen.dart';

class CategoryParametersScreen extends StatelessWidget {
  final String examName;
  final String categoryName;
  final List<ParameterRecord> parameters;
  
  const CategoryParametersScreen({
    super.key, 
    required this.examName,
    required this.categoryName, 
    required this.parameters
  });

  // Use StatusColors from theme
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
  
  IconData _getStatusIcon(ParameterStatus status) {
     switch (status) {
      case ParameterStatus.normal:
        return Icons.check_circle_outline; // Consistent icon
      case ParameterStatus.watch:
        return Icons.watch_later_outlined; // Consistent icon
      case ParameterStatus.attention:
        return Icons.warning; // Use a filled, more prominent icon for attention
      case ParameterStatus.unknown:
        return Icons.help_outline; // Consistent icon
    }
  }

  void _navigateToParameterDetail(BuildContext context, ParameterRecord parameter) {
     // Implement actual navigation
     Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => ParameterDetailScreen(
          categoryName: parameter.category,
          parameterName: parameter.parameterName,
       )),
     );
  }

  @override
  Widget build(BuildContext context) {
     final NumberFormat valueFormatter = NumberFormat("#,##0.##"); 

    return Scaffold(
      appBar: AppBar(
        // Use theme style
        title: Text(categoryName), 
      ),
      body: ListView.builder(
         padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0), // Consistent padding
         itemCount: parameters.length,
         itemBuilder: (context, index) {
            final param = parameters[index];
            final statusColor = _getStatusColor(context, param.status);
            final statusIcon = _getStatusIcon(param.status);
            final valueString = param.value != null ? valueFormatter.format(param.value) : '--';
            final rangeString = param.refOriginal?.isNotEmpty == true ? param.refOriginal! : 'No Ref.';

            // Determine card background color based on status
            Color? cardBackgroundColor;
            if (param.status == ParameterStatus.attention) {
              cardBackgroundColor = Colors.amber.shade50; // Very light amber for attention
            }
            // Add cases for watch or normal if needed
            // else if (param.status == ParameterStatus.watch) {
            //   cardBackgroundColor = Colors.orange.shade50; 
            // }

            return Card(
              color: cardBackgroundColor, // Set background color conditionally
              margin: const EdgeInsets.symmetric(vertical: 5.0),
              child: ListTile(
                 contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                 leading: Tooltip( 
                     message: param.status.toString().split('.').last, 
                     // Ensure icon uses the (now potentially yellow) statusColor
                     child: Icon(statusIcon, color: statusColor, size: 30), 
                 ),
                 title: Text(param.parameterName, style: Theme.of(context).textTheme.titleMedium),
                 subtitle: Text(rangeString, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                 trailing: Text(
                    valueString, 
                    // Ensure value text uses the (now potentially yellow) statusColor
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: statusColor)
                 ),
                 onTap: () => _navigateToParameterDetail(context, param),
              ),
            );
         }
      ),
    );
  }
} 