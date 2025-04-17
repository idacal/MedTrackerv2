import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

// Import services and models
import '../services/database_service.dart';
import '../models/exam_record.dart';

// Import detail screen
import 'exam_categories_screen.dart'; // Import the new screen

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Store the future in the state to avoid re-fetching on every build
  late Future<List<ExamRecord>> _examRecordsFuture;
  final DateFormat _formatter = DateFormat('dd/MM/yyyy HH:mm'); // Formatter for display

  @override
  void initState() {
    super.initState();
    _loadExamRecords();
  }

  // Method to fetch records, allows calling from initState and onRefresh
  Future<void> _loadExamRecords() async {
    // Assign the future to the state variable. FutureBuilder will handle awaiting it.
    setState(() {
      _examRecordsFuture = DatabaseService().getAllExamRecords();
    });
  }

  void _navigateToExamDetail(int examId, String fileName) {
     Navigator.push(
       context,
       MaterialPageRoute(
         // Navigate to ExamCategoriesScreen
         builder: (context) => ExamCategoriesScreen(examId: examId, examName: fileName)
       ),
     ).then((_) {
        // Optional: Reload list if returning might have caused changes
        // _loadExamRecords();
     });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Exámenes'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadExamRecords, // Call the load method on refresh
        child: FutureBuilder<List<ExamRecord>>(
          future: _examRecordsFuture, // Use the state variable future
          builder: (context, snapshot) {
            // Handle loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // Handle error state
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error al cargar el historial: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              );
            }
            // Handle empty state (no data or empty list)
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return LayoutBuilder( // Use LayoutBuilder to enable pull-to-refresh even when empty
                builder: (context, constraints) {
                  return SingleChildScrollView(
                     physics: const AlwaysScrollableScrollPhysics(),
                     child: ConstrainedBox(
                       constraints: BoxConstraints(minHeight: constraints.maxHeight),
                       child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Text(
                              'No hay exámenes cargados todavía.\nUsa el botón (+) para añadir uno.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                            ),
                          ),
                        ),
                     ),
                  );
                }
              );
            }

            // Display the list of exams
            final exams = snapshot.data!;
            return ListView.builder(
              // Add physics to allow scrolling even if list fits screen (for refresh)
              physics: const AlwaysScrollableScrollPhysics(), 
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0), // Add padding
              itemCount: exams.length,
              itemBuilder: (context, index) {
                final exam = exams[index];
                return Card(
                  elevation: 1.0,
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    title: Text(
                      exam.fileName,
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Cargado: ${_formatter.format(exam.importDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
        ),
      ),
    );
  }
} 