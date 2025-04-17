import 'package:flutter/material.dart';
import 'package:medtracker_app/main.dart'; // For StatusColors
import 'package:medtracker_app/models/parameter_record.dart';
import 'package:medtracker_app/screens/parameter_detail_screen.dart';
import 'package:medtracker_app/services/database_service.dart';

class ParameterListScreen extends StatefulWidget {
  final ParameterStatus targetStatus;

  const ParameterListScreen({super.key, required this.targetStatus});

  @override
  State<ParameterListScreen> createState() => _ParameterListScreenState();
}

class _ParameterListScreenState extends State<ParameterListScreen> {
  final dbService = DatabaseService();
  late Future<List<ParameterRecord>> _filteredParametersFuture;

  @override
  void initState() {
    super.initState();
    _loadFilteredParameters();
  }

  Future<void> _loadFilteredParameters() async {
    setState(() {
      _filteredParametersFuture = dbService.getLatestParameterValues().then((allLatest) {
        // Filter the list based on the target status
        return allLatest.where((p) => p.status == widget.targetStatus).toList();
      });
    });
  }

  String _getTitleForStatus(ParameterStatus status) {
    switch (status) {
      case ParameterStatus.normal:
        return 'Parámetros Normales';
      case ParameterStatus.watch:
        return 'Parámetros a Vigilar';
      case ParameterStatus.attention:
        return 'Parámetros que requieren Atención';
      case ParameterStatus.unknown:
        return 'Parámetros Desconocidos';
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
    final statusColors = StatusColors.of(context); // Get status colors
    Color statusColor;
     switch (widget.targetStatus) {
      case ParameterStatus.normal: statusColor = statusColors.normal; break;
      case ParameterStatus.watch: statusColor = statusColors.watch; break;
      case ParameterStatus.attention: statusColor = statusColors.attention; break;
      case ParameterStatus.unknown: statusColor = Colors.grey; break;
    }


    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitleForStatus(widget.targetStatus)),
        // Optional: Style AppBar based on status color
        // backgroundColor: statusColor.withOpacity(0.1), 
        // foregroundColor: statusColor,
      ),
      body: FutureBuilder<List<ParameterRecord>>(
        future: _filteredParametersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar parámetros: ${snapshot.error}', style: TextStyle(color: statusColors.attention)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No se encontraron parámetros con este estado.')));
          }

          final parameters = snapshot.data!;

          return ListView.builder(
            itemCount: parameters.length,
            itemBuilder: (context, index) {
              final record = parameters[index];
              // Use a slightly more informative ListTile
              return ListTile(
                leading: Icon(Icons.circle, color: statusColor, size: 12), // Small status indicator
                title: Text(record.parameterName),
                subtitle: Text(record.category),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _navigateToParameterDetail(record),
              );
            },
          );
        },
      ),
    );
  }
} 