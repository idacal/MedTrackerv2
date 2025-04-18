import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/database_service.dart';
import '../models/parameter_record.dart';
import '../models/exam_record.dart';
import 'exam_categories_screen.dart';
import 'parameter_list_screen.dart';
import '../main.dart'; // Import main to access StatusColors

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final dbService = DatabaseService();
  Future<Map<ParameterStatus, int>>? _summaryFuture;
  Future<List<Map<String, dynamic>>>? _recentExamsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _summaryFuture = _calculateSummary();
      _recentExamsFuture = dbService.getRecentExamsWithAttentionCount(limit: 3);
    });
  }

  Future<Map<ParameterStatus, int>> _calculateSummary() async {
    final latestParameters = await dbService.getLatestParameterValues();
    final summary = {
      ParameterStatus.normal: 0,
      ParameterStatus.watch: 0,
      ParameterStatus.attention: 0,
      ParameterStatus.unknown: 0, // Include unknown if needed, or filter out
    };

    for (var param in latestParameters) {
      summary[param.status] = (summary[param.status] ?? 0) + 1;
    }
    // Exclude unknown from the summary card display if desired
    summary.remove(ParameterStatus.unknown);
    return summary;
  }

  void _navigateToExamCategories(int examId, String examName) async {
    try {
      // Show loading indicator maybe?
      final groupedParams = await dbService.getGroupedParametersForExam(examId);
      if (mounted) { // Check if the widget is still in the tree
         Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExamCategoriesScreen(
                 examName: examName,
                 groupedParameters: groupedParams,
              ),
            ),
         );
      }
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error al cargar categorías: $e')),
          );
       }
    }
  }

  void _navigateToParameterList(ParameterStatus status) {
    // Calculate total count from the summary map before navigating
    _summaryFuture?.then((summary) { // Access the future result
      if (summary.isNotEmpty) {
        int totalCount = summary.values.reduce((sum, element) => sum + element);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParameterListScreen(
              targetStatus: status,
              totalParameterCount: totalCount, // Pass the calculated total
            ),
          ),
        );
      } else {
         // Handle case where summary is empty or still loading (optional)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Resumen no disponible aún.')),
           );
      }
    }).catchError((error) {
        // Handle error loading summary (optional)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar resumen: $error')),
        );
    });
  }

  // --- Delete Confirmation Dialog (copied from HistoryScreen for consistency) ---
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

  // --- Handle Exam Deletion (similar to HistoryScreen) ---
  Future<void> _deleteExam(int examId, String examName) async {
    final confirmed = await _showDeleteConfirmationDialog(examName);
    if (confirmed == true) {
      try {
        await dbService.deleteExamRecord(examId);
        // Refresh both summary and recent exams after deletion
        _loadData(); 
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
    final statusColors = StatusColors.of(context); // Get status colors

    return Scaffold(
      // Remove the default AppBar
      // appBar: AppBar(title: const Text('Pantalla Principal')),
      body: SafeArea( // <-- Wrap body content with SafeArea
        child: RefreshIndicator(
          onRefresh: () async {
            _loadData(); // Reload data on pull-to-refresh
          },
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // --- Custom Header ---
              _buildCustomHeader(context),
              // Increase spacing below header
              const SizedBox(height: 30), 

              // --- Health Summary Card ---
              FutureBuilder<Map<ParameterStatus, int>>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error al cargar resumen: ${snapshot.error}', style: TextStyle(color: statusColors.attention)));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No hay datos de resumen.'));
                  }
                  // Use actual data
                  return _buildSummaryCard(context, snapshot.data ?? {});
                },
              ),
              const SizedBox(height: 24),

              // --- Recent Exams Section ---
              _buildRecentExams(context),
            ],
          ),
        ),
      ),
    );
  }

  // --- Custom Header Widget ---
  Widget _buildCustomHeader(BuildContext context) {
    // TODO: Replace 'Ignacio' with actual user name if available
    String userName = "Ignacio"; 
    // TODO: Replace 'ID' with actual user ID/icon if available
    String userId = "ID"; 

    return Card(
      color: Theme.of(context).primaryColor, // Use primary color for background
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mi Salud',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hola, $userName',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
            // Placeholder for ID/Icon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                userId, 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // --- Summary Card Widget ---
  Widget _buildSummaryCard(BuildContext context, Map<ParameterStatus, int> summary) {
    final statusColors = StatusColors.of(context); // Get status colors

    // Get counts, defaulting to 0 if a status is missing
    final normalCount = summary[ParameterStatus.normal] ?? 0;
    final watchCount = summary[ParameterStatus.watch] ?? 0;
    final attentionCount = summary[ParameterStatus.attention] ?? 0;

    // Helper to build each status indicator (NOW WRAPPED IN GestureDetector)
    Widget buildStatusIndicator(ParameterStatus status, int count) {
      String label;
      Color color;
      VoidCallback onTapAction;

      switch (status) {
        case ParameterStatus.normal:
          label = 'Normal';
          color = statusColors.normal;
          onTapAction = () => _navigateToParameterList(ParameterStatus.normal);
          break;
        case ParameterStatus.watch:
          label = 'Vigilar';
          color = statusColors.watch;
           onTapAction = () => _navigateToParameterList(ParameterStatus.watch);
          break;
        case ParameterStatus.attention:
          label = 'Atención';
          color = statusColors.attention;
           onTapAction = () => _navigateToParameterList(ParameterStatus.attention);
          break;
        default: // Should not happen if unknown is removed
          label = 'Desconocido';
          color = Colors.grey;
          onTapAction = () {}; // No action for unknown
      }
      
      // Wrap the Column in GestureDetector
      return GestureDetector(
         onTap: count > 0 ? onTapAction : null, // Only allow tap if count > 0
         child: Column(
           children: [
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: color,
                 shape: BoxShape.circle,
                 boxShadow: [
                   BoxShadow(
                     color: color.withOpacity(0.5),
                     spreadRadius: 1,
                     blurRadius: 5,
                     offset: const Offset(0, 2),
                   ),
                 ],
               ),
               child: Text(
                 count.toString(),
                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
               ),
             ),
             const SizedBox(height: 6),
             Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
           ],
         ),
      );
    }

    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de Salud',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Build the indicators which are now tappable
                if (normalCount > 0 || (watchCount == 0 && attentionCount == 0)) 
                   buildStatusIndicator(ParameterStatus.normal, normalCount),
                if (watchCount > 0)
                   buildStatusIndicator(ParameterStatus.watch, watchCount),
                if (attentionCount > 0)
                   buildStatusIndicator(ParameterStatus.attention, attentionCount),
              ],
            ),
            // REMOVED TEXT LINE:
            // const SizedBox(height: 12),
            // Text(
            //   '$totalNormal parámetros normales / $totalReview por revisar',
            //   style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            //   textAlign: TextAlign.center, // Center align the text
            // ),
          ],
        ),
      ),
    );
  }


  // --- Recent Exams Section Widget ---
  Widget _buildRecentExams(BuildContext context) {
    final DateFormat formatter = DateFormat('dd MMM yyyy');
    final statusColors = StatusColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exámenes Recientes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _recentExamsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error al cargar exámenes: ${snapshot.error}', style: TextStyle(color: statusColors.attention)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No hay exámenes recientes.')));
            }

            final recentExams = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true, // Important inside another ListView
              physics: const NeverScrollableScrollPhysics(), // Prevent scrolling conflicts
              itemCount: recentExams.length,
              itemBuilder: (context, index) {
                final examData = recentExams[index];
                final examId = examData['id'] as int?;
                final fileName = examData['fileName'] as String? ?? 'Nombre no disponible';
                final importDate = DateTime.parse(examData['importDate'] as String? ?? DateTime.now().toIso8601String());
                final attentionCount = examData['attentionCount'] as int? ?? 0;
                
                // --- Wrap Card in GestureDetector --- 
                return GestureDetector(
                  onLongPress: () {
                     if (examId != null) {
                       _deleteExam(examId, fileName); // Call delete handler
                     } 
                   },
                  child: Card(
                    elevation: 1.0,
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                      title: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        formatter.format(importDate),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- Use Container for Custom Alert Tag --- 
                          if (attentionCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColors.watch.withOpacity(0.2), // Light yellow/amber background
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$attentionCount ${attentionCount == 1 ? 'alerta' : 'alertas'}', // Dynamic text
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: statusColors.watch, // Darker amber/yellow text
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          if (attentionCount > 0) const SizedBox(width: 8), // Keep space if tag is shown
                          Icon(Icons.chevron_right, color: Colors.grey[400]),
                        ],
                      ),
                      onTap: () {
                        if (examId != null) {
                           _navigateToExamCategories(examId, fileName);
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
      ],
    );
  }
}
