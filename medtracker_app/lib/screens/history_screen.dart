import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

// Import services and models
import '../services/database_service.dart';
import '../models/exam_record.dart';
import '../main.dart'; // Import StatusColors

// Import detail screen
import 'exam_categories_screen.dart'; // Import the new screen

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Store the future in the state to avoid re-fetching on every build
  late Future<List<Map<String, dynamic>>> _examRecordsFuture;
  final DateFormat _formatter = DateFormat('dd MMM yyyy'); // Use same format as HomeScreen
  final dbService = DatabaseService(); // Instance of DatabaseService
  // Get StatusColors instance
  late StatusColors statusColors;

  @override
  void initState() {
    super.initState();
    // Wait for didChangeDependencies to get StatusColors
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get StatusColors here, after context is available
    statusColors = StatusColors.of(context);
    // Load data after StatusColors is available
    _loadExamRecords();
  }

  // Method to fetch records, allows calling from initState and onRefresh
  Future<void> _loadExamRecords() async {
    // Assign the future to the state variable. FutureBuilder will handle awaiting it.
    setState(() {
      // Call the new method
      _examRecordsFuture = dbService.getAllExamRecordsWithAttentionCount();
    });
  }

  void _navigateToExamDetail(int examId, String fileName) async {
      // Fetch grouped parameters before navigating
      try {
          // Consider showing a loading indicator here
          final groupedParameters = await dbService.getGroupedParametersForExam(examId);
          if (mounted) { // Check if the widget is still mounted
             Navigator.push(
                 context,
                 MaterialPageRoute(
                     builder: (context) => ExamCategoriesScreen(
                         examName: fileName,
                         groupedParameters: groupedParameters, // Pass the map
                     )
                 ),
             );
          }
      } catch (e) {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Error al cargar detalles del examen: $e')),
             );
          }
      }
  }

  // --- Delete Confirmation Dialog ---
  Future<bool?> _showDeleteConfirmationDialog(String examName) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Borrado'),
          content: Text('¿Estás seguro de que quieres borrar el examen "$examName" y todos sus datos asociados? Esta acción no se puede deshacer.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop(false); // Return false
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error), // Use error color
              child: const Text('Borrar'),
              onPressed: () {
                Navigator.of(context).pop(true); // Return true
              },
            ),
          ],
        );
      },
    );
  }

  // --- Handle Exam Deletion ---
  Future<void> _deleteExam(int examId, String examName) async {
    // 1. Show confirmation dialog
    final confirmed = await _showDeleteConfirmationDialog(examName);

    // 2. If confirmed, proceed with deletion
    if (confirmed == true) {
      try {
        await dbService.deleteExamRecord(examId);
        // 3. Refresh the list after deletion
        await _loadExamRecords(); // Re-fetch the exam list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Examen "$examName" borrado.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al borrar el examen: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Exámenes'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadExamRecords, // Call the load method on refresh
        child: FutureBuilder<List<Map<String, dynamic>>>(
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
                // Extract data from the map
                final examData = exams[index];
                final examId = examData['id'] as int?;
                final fileName = examData['fileName'] as String? ?? 'Nombre no disponible';
                final importDate = DateTime.parse(examData['importDate'] as String? ?? DateTime.now().toIso8601String());
                final attentionCount = examData['attentionCount'] as int? ?? 0;

                return GestureDetector( // Wrap Card in GestureDetector
                   onLongPress: () {
                     if (examId != null) {
                       _deleteExam(examId, fileName); // Call delete handler
                     } 
                   },
                   child: Card(
                    elevation: 1.0,
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      title: Text(
                        fileName,
                        maxLines: 2, 
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Row( // Wrap subtitle in a Row
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[600]), // Add icon
                          const SizedBox(width: 4), // Add spacing
                          Text(
                            'Cargado: ${_formatter.format(importDate)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (attentionCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColors.watch.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, size: 12, color: statusColors.watch), // Icon added
                                  const SizedBox(width: 4), // Spacing
                                  Text(
                                    '$attentionCount ${attentionCount == 1 ? 'alerta' : 'alertas'}',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: statusColors.watch,
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (attentionCount > 0) const SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: Colors.grey[400]),
                        ],
                      ),
                      onTap: () {
                        if (examId != null) {
                           _navigateToExamDetail(examId, fileName);
                        } else {
                           ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error: ID de examen no válido.')),
                           );
                        }
                      },
                    ),
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