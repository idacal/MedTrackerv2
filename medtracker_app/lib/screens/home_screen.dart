import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../models/parameter_record.dart';
import '../models/exam_record.dart';
import 'exam_categories_screen.dart';
import '../main.dart'; // Import main to access StatusColors

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ExamRecord>> _recentExamsFuture;
  final DateFormat _listDateFormatter = DateFormat('dd/MM/yyyy');
  final dbService = DatabaseService();
  late Future<Map<String, int>> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _summaryFuture = _calculateSummary(); // Ensure this is called
      _recentExamsFuture = dbService.getAllExamRecords();
    });
  }

  // Calculate summary using real data
  Future<Map<String, int>> _calculateSummary() async {
    final latestValues = await dbService.getLatestParameterValues();
    int normalCount = 0;
    int watchCount = 0;
    int attentionCount = 0;
    for (var param in latestValues) {
      switch (param.status) {
        case ParameterStatus.normal:
          normalCount++;
          break;
        case ParameterStatus.watch:
          watchCount++;
          break;
        case ParameterStatus.attention:
          attentionCount++;
          break;
        case ParameterStatus.unknown:
          // Optionally count unknown or ignore
          break;
      }
    }
    return {'normal': normalCount, 'watch': watchCount, 'attention': attentionCount};
  }

   void _navigateToExamDetail(int examId, String fileName) {
     Navigator.push(
       context,
       MaterialPageRoute(
         builder: (context) => ExamCategoriesScreen(examId: examId, examName: fileName)
       ),
     ).then((_) {
        // Optional: Refresh data if needed after returning
        // _loadData();
     });
  }


  @override
  Widget build(BuildContext context) {
    // Access status colors from theme extension
    final statusColors = StatusColors.of(context);

    return Scaffold(
      // Use AppBar from theme
      appBar: AppBar(
        title: const Text('Mi Salud'),
        actions: [
          // User ID Icon from Mockup
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Perfil', // Tooltip
            onPressed: () {
               // Maybe navigate to profile tab?
               // Or open a profile details page?
               ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navegación a Perfil (No implementado)')),
               );
             },
          ),
          const SizedBox(width: 8), // Add some padding
        ],
      ),
      body: RefreshIndicator(
         onRefresh: _loadData,
         child: ListView(
           padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
           children: [
             // Use FutureBuilder for the summary card data
             FutureBuilder<Map<String, int>>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                   // Calculate counts based on snapshot or default to 0
                   int normalCount = snapshot.hasData ? snapshot.data!['normal'] ?? 0 : 0;
                   int watchCount = snapshot.hasData ? snapshot.data!['watch'] ?? 0 : 0;
                   int attentionCount = snapshot.hasData ? snapshot.data!['attention'] ?? 0 : 0;
                   bool isLoading = snapshot.connectionState == ConnectionState.waiting;
                   bool hasError = snapshot.hasError;

                   // Pass calculated counts and loading state to the card builder
                   return _buildSummaryCard(context, statusColors, normalCount, watchCount, attentionCount, isLoading, hasError);
                },
             ),
             const SizedBox(height: 20),
             // Section Title for Recent Exams
             Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Text(
                  'Exámenes Recientes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
             _buildRecentExamsList(), // FutureBuilder for the list
           ],
         ),
      ),
    );
  }

  // Summary Card Widget - Now uses passed arguments
  Widget _buildSummaryCard(BuildContext context, StatusColors colors, int normalCount, int watchCount, int attentionCount, bool isLoading, bool hasError) {
    // Remove const example data

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumen de Salud', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (isLoading)
               const Center(child: SizedBox(height: 40, child: CircularProgressIndicator(strokeWidth: 3)))
            else if (hasError)
               Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text("Error al calcular resumen", style: TextStyle(color: Theme.of(context).colorScheme.error))))
            else
               Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatusIndicator(colors.normal, 'Normal', normalCount),
                  _buildStatusIndicator(colors.watch, 'Vigilar', watchCount),
                  _buildStatusIndicator(colors.attention, 'Atención', attentionCount),
                ],
              ),
            const SizedBox(height: 12),
            // Show description only if not loading and no error
             if (!isLoading && !hasError)
                Text(
                  watchCount + attentionCount > 0
                   ? '$normalCount parámetros normales / ${watchCount + attentionCount} por revisar'
                   : (normalCount > 0 ? '$normalCount parámetros normales' : 'Sin datos para resumir'), // Handle case with 0 counts
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
             // Optional: Add last updated time here if needed
          ],
        ),
      ),
    );
  }

   // Helper for status indicators
   Widget _buildStatusIndicator(Color color, String label, int count) {
     return Column(
       mainAxisSize: MainAxisSize.min,
       children: [
         CircleAvatar(
           backgroundColor: color,
           radius: 18, // Slightly larger
           child: Text(
             count.toString(),
             style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
           ),
         ),
         const SizedBox(height: 6),
         Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey[700])), // Slightly larger label
       ],
     );
   }

   // Recent Exams List - Uses FutureBuilder and styled ListTiles
   Widget _buildRecentExamsList() {
     return FutureBuilder<List<ExamRecord>>(
       future: _recentExamsFuture,
       builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))));
          }
          if (snapshot.hasError) {
             return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error al cargar exámenes: ${snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error))));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Card(
                  color: Colors.white,
                  child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                          'No hay exámenes recientes. Carga uno usando el botón (+).',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                          ),
                      ),
                  );
          }

          final exams = snapshot.data!;
          return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exams.length > 5 ? 5 : exams.length, // Limit to 5 most recent
              itemBuilder: (context, index) {
                final exam = exams[index];
                return Card(
                   elevation: 1.0,
                   margin: const EdgeInsets.symmetric(vertical: 4.0),
                   child: ListTile(
                     contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                     title: Text(exam.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                     subtitle: Text(_listDateFormatter.format(exam.importDate), style: Theme.of(context).textTheme.bodySmall),
                     trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                     onTap: () {
                        if (exam.id != null) {
                          _navigateToExamDetail(exam.id!, exam.fileName);
                       } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Error: ID de examen no válido.')),
                          );
                       }
                     },
                   ),
                );
              },
            );
       },
     );
   }
}
