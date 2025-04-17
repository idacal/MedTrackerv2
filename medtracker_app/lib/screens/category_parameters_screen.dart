import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/parameter_record.dart';

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

  // Re-use helper methods from ExamCategoriesScreen (or move to a common utility file)
  Color _getStatusColor(BuildContext context, ParameterStatus status) {
    switch (status) {
      case ParameterStatus.normal:
        return Colors.green.shade700;
      case ParameterStatus.watch:
        return Colors.orange.shade800;
      case ParameterStatus.attention:
        return Theme.of(context).colorScheme.error;
      case ParameterStatus.unknown:
        return Colors.grey.shade600;
    }
  }
  
  IconData _getStatusIcon(ParameterStatus status) {
     switch (status) {
      case ParameterStatus.normal:
        return Icons.check_circle_outline;
      case ParameterStatus.watch:
        return Icons.watch_later_outlined;
      case ParameterStatus.attention:
        return Icons.error_outline;
      case ParameterStatus.unknown:
        return Icons.help_outline;
    }
  }

  void _navigateToParameterDetail(BuildContext context, ParameterRecord parameter) {
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

  @override
  Widget build(BuildContext context) {
     final NumberFormat valueFormatter = NumberFormat("#,##0.##"); // Local formatter

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName, style: Theme.of(context).textTheme.titleMedium), 
        // Optional: Add subtitle with exam name?
        // title: Column(
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   children: [
        //     Text(categoryName, style: Theme.of(context).textTheme.titleMedium),
        //     Text(examName, style: Theme.of(context).textTheme.bodySmall), 
        //   ],
        // ),
      ),
      body: ListView.builder(
         padding: const EdgeInsets.all(8.0),
         itemCount: parameters.length,
         itemBuilder: (context, index) {
            final param = parameters[index];
            final statusColor = _getStatusColor(context, param.status);
            final statusIcon = _getStatusIcon(param.status);
            final valueString = param.value != null ? valueFormatter.format(param.value) : '--';
            final rangeString = param.refOriginal ?? 'No disponible';

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                 leading: Icon(statusIcon, color: statusColor, size: 28),
                 title: Text(param.parameterName),
                 subtitle: Text('Ref: $rangeString'),
                 trailing: Text(
                    valueString, 
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: statusColor)
                 ),
                 onTap: () => _navigateToParameterDetail(context, param),
              ),
            );
         }
      ),
    );
  }
} 