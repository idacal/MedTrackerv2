import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

// Import services and models
import '../services/database_service.dart';
import '../models/parameter_record.dart'; // Keep for summary logic later
import '../models/exam_record.dart';

// Import detail screen
import 'exam_categories_screen.dart'; // Import the new screen

class HomeScreen extends StatefulWidget {
  // Changed to StatefulWidget to potentially fetch data
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ExamRecord>> _recentExamsFuture;
  final DateFormat _listDateFormatter = DateFormat('dd/MM/yyyy'); // Simpler format for list
  final dbService = DatabaseService(); // Instance of database service

  // Placeholder for data fetching logic
  // Future<Map<String, dynamic>>? _summaryData;

  @override
  void initState() {
    super.initState();
    _loadData(); 
  }

  // Load both summary (placeholder for now) and recent exams
  Future<void> _loadData() async {
    setState(() {
      // _summaryFuture = _calculateSummary(); // TODO: Implement summary calculation
      _recentExamsFuture = dbService.getAllExamRecords();
    });
  }

  // TODO: Implement summary calculation using getLatestParameterValues()
  // Future<Map<String, int>> _calculateSummary() async {
  //   final latestValues = await dbService.getLatestParameterValues();
  //   int normalCount = 0;
  //   int watchCount = 0; // Assuming ParameterStatus.watch exists
  //   int attentionCount = 0;
  //   for (var param in latestValues) {
  //     switch (param.status) {
  //       case ParameterStatus.normal:
  //         normalCount++;
  //         break;
  //       case ParameterStatus.watch:
  //         watchCount++;
  //         break;
  //       case ParameterStatus.attention:
  //         attentionCount++;
  //         break;
  //       case ParameterStatus.unknown:
  //         break;
  //     }
  //   }
  //   return {'normal': normalCount, 'watch': watchCount, 'attention': attentionCount};
  // }

  void _navigateToExamDetail(int examId, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Navigate to ExamCategoriesScreen
        builder: (context) => ExamCategoriesScreen(examId: examId, examName: fileName)
      ),
    ).then((_) {
       // Optional: Refresh data if needed after returning 
       // _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Salud'),
        // actions: [
        //   // Placeholder for User ID icon
        //   IconButton(
        //     icon: const Icon(Icons.account_circle), 
        //     onPressed: () { /* Navigate to Profile? */ },
        //   ),
        // ],
      ),
      body: RefreshIndicator(
         onRefresh: _loadData, // Refresh both summary and list
         child: ListView( 
           padding: const EdgeInsets.all(8.0),
           children: [
             _buildSummaryCard(), // Placeholder UI, needs real data from _summaryFuture
             const SizedBox(height: 16),
             // Section Title for Recent Exams
             Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Text(
                  'Exámenes Recientes', 
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
             _buildRecentExamsList(), // Use FutureBuilder here
           ],
         ),
      ),
      // FAB is now managed by MainScaffold
    );
  }

  // Placeholder Widget for the Summary Card
  Widget _buildSummaryCard() {
    // TODO: Use FutureBuilder with _summaryFuture here
    const int normalCount = 10; // Example data
    const int watchCount = 2; // Example data
    const int attentionCount = 0; // Example data

    return Card(
       // elevation defined in main theme
       // margin defined in main theme
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de Salud', 
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusIndicator(Colors.green, 'Normal', normalCount),
                _buildStatusIndicator(Colors.orange, 'Vigilar', watchCount),
                _buildStatusIndicator(Colors.red, 'Atención', attentionCount),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$normalCount parámetros normales / $watchCount por vigilar', 
              style: Theme.of(context).textTheme.bodyMedium,
            ),
             const SizedBox(height: 16),
             Text(
              'Datos basados en los últimos valores registrados.' , // TODO: Add last update time
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for status indicators in the summary card
  Widget _buildStatusIndicator(Color color, String label, int count) {
    // Use theme colors if possible
    final Color statusColor = 
       color == Colors.green ? Colors.green // Or Theme.of(context).colorScheme.primaryVariant?
     : color == Colors.orange ? Theme.of(context).colorScheme.secondary // Assuming secondary is Amber
     : color == Colors.red ? Theme.of(context).colorScheme.error
     : Colors.grey;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          backgroundColor: statusColor,
          radius: 16,
          child: Text(
            count.toString(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  // Recent Exams List - Now uses FutureBuilder with real data
  Widget _buildRecentExamsList() {
    return FutureBuilder<List<ExamRecord>>(
      future: _recentExamsFuture,
      builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
            // Show a smaller loading indicator within the list area
            return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))));
         }
         if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('Error al cargar exámenes: ${snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error))));
         }
         if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No hay exámenes recientes.')));
         }

         final exams = snapshot.data!;
         // Use ListView.builder directly without Column/shrinkWrap/NeverScrollable
         // since it's now the primary content of this builder.
         return ListView.builder(
             shrinkWrap: true, // Need shrinkWrap if inside another ListView
             physics: const NeverScrollableScrollPhysics(), // Disable scroll if inside ListView
             itemCount: exams.length, // Show all exams for now
             // itemCount: exams.length > 3 ? 3 : exams.length, // Limit to 3?
             itemBuilder: (context, index) {
               final exam = exams[index];
               return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 5.0), // Adjust margin
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined), 
                    title: Text(exam.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Fecha: ${_listDateFormatter.format(exam.importDate)}'),
                    trailing: const Icon(Icons.chevron_right),
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