import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'dart:io'; // Import dart:io for File
import 'dart:convert'; // Needed for jsonDecode

import '../services/database_service.dart';
import '../models/parameter_record.dart';
import '../models/exam_record.dart';
import 'exam_categories_screen.dart';
import 'parameter_list_screen.dart';
import '../main.dart'; // Import main to access StatusColors
import 'dart:math'; // For calculation
// Import the detail screen if needed for navigation later
import 'parameter_detail_screen.dart'; 
// Import History Screen for navigation
import 'history_screen.dart';
import 'profile_screen.dart'; // Import the ProfileScreen
import 'tracked_parameters_screen.dart'; // Import the new screen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final dbService = DatabaseService();
  Future<Map<String, dynamic>>? _headerDataFuture;
  Future<List<Map<String, dynamic>>>? _recentExamsFuture;
  Future<List<Map<String, dynamic>>>? _trackedParametersFuture;
  final NumberFormat _percentFormatter = NumberFormat("+0.0%;-0.0%;0.0%");
  DateTime? _latestExamDate;

  // --- State for Bottom Navigation Bar --- 
  int _selectedIndex = 0; 
  // ---------------------------------------

  @override
  void initState() {
    super.initState();
    // Set default tracked parameters if list is empty (fire and forget)
    dbService.setDefaultTrackedParametersIfEmpty(); 
    _loadData();
  }

  void _loadData() {
    // --- Fetch latest date separately --- 
    dbService.getLatestExamImportDate().then((date) {
       if (mounted) {
         setState(() { _latestExamDate = date; });
       }
    });
    // ----------------------------------
    setState(() {
      _headerDataFuture = _loadHeaderAndSummaryData();
      _recentExamsFuture = dbService.getRecentExamsWithAttentionCount(limit: 3);
      _trackedParametersFuture = _loadTrackedParametersData(); 
    });
  }

  Future<Map<String, dynamic>> _loadHeaderAndSummaryData() async {
    final latestParameters = await dbService.getLatestParameterValues();
    final latestImportDate = await dbService.getLatestExamImportDate();
    final summaryCounts = {
      ParameterStatus.normal: 0,
      ParameterStatus.watch: 0,
      ParameterStatus.attention: 0,
    };
    int totalCount = latestParameters.length;

    for (var param in latestParameters) {
      if (summaryCounts.containsKey(param.status)) {
         summaryCounts[param.status] = (summaryCounts[param.status] ?? 0) + 1;
      }
    }
    
    return {
      'counts': summaryCounts, 
      'total': totalCount,
      'lastUpdate': latestImportDate,
    };
  }

  Future<List<Map<String, dynamic>>> _loadTrackedParametersData() async {
    final trackedParamsData = await dbService.getLatestTrackedParameterValues();
    return trackedParamsData; 
  }

  void _navigateToExamCategories(int examId, String examName) async {
    try {
      final groupedParams = await dbService.getGroupedParametersForExam(examId);
      if (mounted) {
         Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExamCategoriesScreen(
                 examName: examName,
                 groupedParameters: groupedParams,
              ),
            ),
         ).then((_) => _loadData());
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
    _headerDataFuture?.then((summary) {
      if (summary.isNotEmpty) {
        int totalCount = summary['total'];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParameterListScreen(
              targetStatus: status,
              totalParameterCount: totalCount,
              onTrackingChanged: () {
                if (mounted) {
                  setState(() {
                    _trackedParametersFuture = _loadTrackedParametersData();
                  });
                }
              },
            ),
          ),
        );
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Resumen no disponible aún.')),
           );
      }
    }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar resumen: $error')),
        );
    });
  }

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
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Borrar'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteExam(int examId, String examName) async {
    final confirmed = await _showDeleteConfirmationDialog(examName);
    if (confirmed == true) {
      try {
        await dbService.deleteExamRecord(examId);
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

  // --- File Picking and Processing Logic ---
  Future<void> _pickAndProcessFile() async {
      print("Attempting to pick file...");
      try {
          // --- Try using FileType.any --- 
          FilePickerResult? result = await FilePicker.platform.pickFiles(
              // type: FileType.custom,
              // allowedExtensions: ['json'],
              type: FileType.any, // Allow picking any file type
          );
          // ------------------------------

          if (result != null && result.files.single.path != null) {
              String path = result.files.single.path!;
              String fileName = result.files.single.name;
              print("File picked: $fileName at $path");

              // --- Add manual check for .json extension --- 
              if (!fileName.toLowerCase().endsWith('.json')) {
                  print("Selected file is not a JSON file.");
                  ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Por favor, selecciona un archivo .json.')),
                   );
                   return; // Stop processing if not JSON
              }
              // --------------------------------------------

              try {
                  final file = File(path); 
                  String jsonString = await file.readAsString();
                  print("File content read successfully.");

                  // Show loading indicator while processing
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Procesando examen...'), duration: Duration(seconds: 1)),
                  );
                  
                  int? examId = await dbService.insertExamFromJson(jsonString, fileName);

                  if (examId != null) {
                      print("Successfully inserted exam with ID: $examId");
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Examen "$fileName" cargado con éxito.')),
                      );
                      // --- Trigger data reload --- 
                      _loadData(); // Reload summary, trends, recent exams
                      // ---------------------------
                  } else {
                      print("Failed to insert exam into database.");
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al guardar el examen "$fileName". Asegúrate que el formato es correcto.')),
                      );
                  }

              } catch (e) {
                  print("Error reading or processing file content: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al leer o procesar el archivo: $e')),
                  );
              }

          } else {
              print("File picking cancelled by user.");
          }
      } catch (e) {
          print("Error picking file: $e");
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al seleccionar archivo: $e')),
          );
      }
  }

  // --- Navigation to Parameter Detail (from Tracked Indicator Card) ---
  void _navigateToParameterDetailFromIndicator(String categoryName, String parameterName) {
     // Similar to navigation from CategoryParametersScreen
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParameterDetailScreen(
          categoryName: categoryName, 
          parameterName: parameterName
        ),
      ),
     ).then((_) => _loadData()); 
  }

  // --- Add back navigation method for Tracked Parameters --- 
  void _navigateToTrackedParameters() {
     Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => const TrackedParametersScreen()),
     ).then((_) => _loadData()); // Refresh data when returning
  }
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Remove explicit color definitions - rely on theme
    // final theme = Theme.of(context);
    // final isDarkMode = theme.brightness == Brightness.dark;
    // final Color activeColor = isDarkMode ? Colors.white : theme.primaryColor;
    // final Color inactiveColor = isDarkMode ? Colors.grey[500]! : Colors.grey[600]!;

    // --- Define Widgets for each Tab --- 
    final List<Widget> _widgetOptions = <Widget>[
      _buildHomeTabContent(context), // Index 0: Inicio
      const Center(child: Text('Análisis (Próximamente)')), // Index 1: Análisis
      const HistoryScreen(), // Index 2: Historial
      const Center(child: Text('Compartir (Próximamente)')), // Index 3: Compartir - Added back
      const ProfileScreen(), // Index 4: Ajustes
    ];
    // -----------------------------------

    return Scaffold(
      // --- Body now uses IndexedStack for Tab Navigation --- 
      body: SafeArea( 
         child: IndexedStack(
           index: _selectedIndex,
           children: _widgetOptions,
         ),
       ),
       // -----------------------------------------------------

      // --- Update Bottom Navigation Bar Icons --- 
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[ // Use const if items are static
          BottomNavigationBarItem(
            // Remove explicit colors from icons
            icon: Icon(Icons.home_outlined), 
            activeIcon: Icon(Icons.home), 
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined), 
            activeIcon: Icon(Icons.bar_chart), 
            label: 'Análisis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined), 
            activeIcon: Icon(Icons.calendar_today), 
            label: 'Historial',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.share_outlined), 
            activeIcon: Icon(Icons.share), 
            label: 'Compartir',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined), 
            activeIcon: Icon(Icons.settings), 
            label: 'Ajustes',
          ),
        ],
        currentIndex: _selectedIndex,
        // Remove explicitly set item colors - let theme handle it
        // selectedItemColor: activeColor, 
        // unselectedItemColor: inactiveColor, 
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed, 
        // Remove explicit background color if theme handles it
        // backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
        onTap: (int index) {
          setState(() {
             // Ensure index stays within bounds (0-4)
            if (index >= 0 && index < _widgetOptions.length) {
               _selectedIndex = index;
            }
          });
        },
      ),
      // -----------------------------------------
    );
  }

  // --- Extracted Home Tab Content Builder ---
  Widget _buildHomeTabContent(BuildContext context) {
      // This is the previous body content (RefreshIndicator + ListView)
       return RefreshIndicator(
          onRefresh: () async {
            _loadData();
          },
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16.0),
            children: [
              const SizedBox(height: 16),
              _buildCustomHeader(context, _latestExamDate),
              FutureBuilder<Map<String, dynamic>>(
                future: _headerDataFuture, 
                builder: (context, snapshot) {
                  Map<String, dynamic>? summaryDataForCard; 
                  if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                    summaryDataForCard = snapshot.data; 
                  } else if (snapshot.connectionState == ConnectionState.done && snapshot.hasError) {
                     print("Error loading summary data: ${snapshot.error}"); 
                  }
                  
                  return _buildHealthSummaryCard(context, summaryDataForCard);
                },
              ),
              const SizedBox(height: 30),

              _buildTrackedIndicatorsSection(context),
              const SizedBox(height: 30),

              _buildRecentExams(context),
              const SizedBox(height: 20),
            ],
          ),
        );
  }
  // -----------------------------------------

  Widget _buildCustomHeader(BuildContext context, DateTime? latestUpdateDate) {
    String userName = "Ignacio";
    String lastUpdateString = 'No hay exámenes cargados';
    if (latestUpdateDate != null) {
       // Format the date nicely
       lastUpdateString = 'Últ. act: ${DateFormat('dd MMM yyyy, HH:mm').format(latestUpdateDate)}';
    }

    return Card(
       color: Theme.of(context).primaryColor,
       elevation: 0,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
       margin: EdgeInsets.zero,
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
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hola, $userName',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white70),
                ),
                if (latestUpdateDate != null) ...[
                   const SizedBox(height: 6),
                   Text(
                     lastUpdateString,
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.6), fontSize: 11),
                   ),
                ]
              ],
            ),
            IconButton(
              icon: Icon(Icons.account_circle_outlined, color: Colors.white, size: 32), 
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Perfil no implementado')),
                );
              },
              tooltip: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSummaryCard(BuildContext context, Map<String, dynamic>? summaryData) {
    final statusColors = StatusColors.of(context);

    final Map<ParameterStatus, int> counts = summaryData?['counts'] ?? {};
    final int total = summaryData?['total'] ?? 0;
    final bool isLoading = summaryData == null;

    final normalCount = counts[ParameterStatus.normal] ?? 0;
    final attentionCount = counts[ParameterStatus.attention] ?? 0;
    final double normalPercent = total > 0 ? (normalCount / total) : 0.0;
    final double attentionPercent = total > 0 ? (attentionCount / total) : 0.0;

    const double gaugeSize = 65.0;
    const double strokeWidth = 6.0;

    if (isLoading) {
      return Card(
        elevation: 2.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: SizedBox(
             height: 150,
             child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        ),
      );
    }
    
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
       margin: const EdgeInsets.only(top: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // --- Row for Title and Link --- 
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween, // Pushes items apart
               crossAxisAlignment: CrossAxisAlignment.start, // Align items to top
               children: [
                 Text(
                    'Estado de Salud',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                 // Move TextButton here
                 SizedBox(
                    height: 24, // Constrain height for better alignment
                    child: TextButton(
                     onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ver detalle no implementado')),
                          );
                     },
                     style: TextButton.styleFrom(
                        padding: EdgeInsets.zero, // Remove default padding
                        minimumSize: Size.zero, // Allow small size
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduce tap area
                        alignment: Alignment.topRight,
                        foregroundColor: Theme.of(context).brightness == Brightness.dark 
                             ? Colors.blue[200] // Brighter blue for dark mode contrast
                             : Theme.of(context).primaryColor, // Standard primary for light
                     ),
                     child: const Text(
                        'Ver detalle',
                        style: TextStyle(fontSize: 13)
                      ),
                   ),
                 ),
               ],
             ),
             // ---------------------------
             const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: normalCount > 0 ? () => _navigateToParameterList(ParameterStatus.normal) : null,
                  child: Row(
                     crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: gaugeSize,
                        height: gaugeSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: gaugeSize,
                              height: gaugeSize,
                              child: CircularProgressIndicator(
                                value: 1.0,
                                strokeWidth: strokeWidth,
                                valueColor: AlwaysStoppedAnimation<Color>(statusColors.normal.withOpacity(0.2)),
                              ),
                            ),
                             SizedBox(
                              width: gaugeSize,
                              height: gaugeSize,
                              child: CircularProgressIndicator(
                                value: normalPercent,
                                strokeWidth: strokeWidth,
                                valueColor: AlwaysStoppedAnimation<Color>(statusColors.normal),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Text(
                              normalCount.toString(),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: statusColors.normal),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Normales'),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.check_circle, size: 14, color: statusColors.normal),
                              const SizedBox(width: 4),
                              Text('${(normalPercent * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(height: 50, width: 1, color: Colors.grey[300]),

                GestureDetector(
                  onTap: attentionCount > 0 ? () => _navigateToParameterList(ParameterStatus.attention) : null,
                  child: Row(
                     crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Atención'),
                           const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 14, color: statusColors.attention),
                              const SizedBox(width: 4),
                              Text('${(attentionPercent * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                       CircleAvatar(
                         radius: 20,
                         backgroundColor: statusColors.attention.withOpacity(0.2),
                         child: Text(
                           attentionCount.toString(),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: statusColors.attention),
                         ),
                       )
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackedIndicatorsSection(BuildContext context) {
    final statusColors = StatusColors.of(context);

    // Define visuals based on CATEGORY
    final categoryVisuals = {
      // Use category names as keys (ensure they match your JSON exactly)
      'HEMATOLOGIA': { 'icon': Icons.water_drop_outlined, 'iconColor': Colors.red.shade300, 'bgColor': Colors.red.shade50 },
      'PERFIL BIOQUIMICO': { 'icon': Icons.science_outlined, 'iconColor': Colors.blue.shade300, 'bgColor': Colors.blue.shade50 }, // Example: science icon
      'VITAMINAS': { 'icon': Icons.spa_outlined, 'iconColor': Colors.green.shade400, 'bgColor': Colors.green.shade50 }, // Example: spa icon
      'ENDOCRINOLOGIA': { 'icon': Icons.bubble_chart_outlined, 'iconColor': Colors.purple.shade200, 'bgColor': Colors.purple.shade50 }, // Example
      // Add more categories as needed
      'default': { 'icon': Icons.monitor_heart, 'iconColor': Colors.grey.shade500, 'bgColor': Colors.grey.shade100 } // Default fallback
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Padding(
           padding: const EdgeInsets.only(bottom: 8.0, left: 4.0, right: 4.0), 
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                // Updated Title
                Text(
                 'Indicadores Seguidos',
                 style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
               ),
                TextButton(
                 onPressed: _navigateToTrackedParameters, // Keep existing navigation call
                 // --- ADD style for dark mode visibility --- 
                 style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).brightness == Brightness.dark 
                         ? Colors.blue[200] // Brighter blue for dark mode contrast
                         : Theme.of(context).primaryColor, // Standard primary for light
                    padding: EdgeInsets.zero, // Keep compact
                    minimumSize: Size.zero, 
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                 ),
                 // -----------------------------------------
                 child: const Text('Ver todos'), // Use const
               ),
             ],
           ),
         ),
          // Update FutureBuilder to use the new future type
          FutureBuilder<List<Map<String, dynamic>>>(
             future: _trackedParametersFuture,
             builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                   return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(strokeWidth: 2)));
                }
                if (snapshot.hasError) {
                   return Center(child: Text('Error al cargar indicadores: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                   return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text('No hay indicadores seguidos aún.')));
                }

                final trackedData = snapshot.data!;
                // Limit to 6 items for display on home screen
                final displayedData = trackedData.take(6).toList();

                return SizedBox(
                   height: 160, // Adjust height if needed
                   child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Row(
                         // Use displayedData here
                         children: displayedData.map((dataMap) {
                           // Extract data from the map
                           final paramRecord = dataMap['record'] as ParameterRecord;
                           final changeString = dataMap['changeString'] as String; 
                           // Get visuals based on category, fallback to default
                           final visuals = categoryVisuals[paramRecord.category.toUpperCase()] ?? categoryVisuals['default']!;
                           
                           return Container(
                              width: MediaQuery.of(context).size.width * 0.4, // Adjust width if needed
                              margin: const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                 // Update navigation call
                                 onTap: () => _navigateToParameterDetailFromIndicator(paramRecord.category, paramRecord.parameterName),
                                 // Add Long Press handler
                                 onLongPress: () => _showUntrackDialogFromHome(paramRecord, dataMap['changeString'] ?? '--'), // Pass record for untracking
                                 // Update card builder call
                                 child: _buildIndicatorCard(
                                  context,
                                  title: paramRecord.parameterName,
                                  value: paramRecord.displayValue, 
                                  unit: paramRecord.unit ?? '', 
                                  // Pass change string
                                  change: changeString, 
                                  icon: visuals['icon'] as IconData,
                                  iconColor: visuals['iconColor'] as Color,
                                  status: paramRecord.status, 
                                  bgColor: visuals['bgColor'] as Color, 
                                  statusColors: statusColors,
                                  // Pass isTracking (always true here, but needed for consistency later)
                                  isTracking: true, 
                                ),
                              ),
                            );
                         }).toList(),
                      ),
                   ),
                 );
             },
          ),
      ],
    );
  }

  Widget _buildIndicatorCard(BuildContext context, {
    required String title,
    required String value,
    required String unit,
    required String change,
    required IconData icon,
    required Color iconColor,
    required ParameterStatus status,
    required Color bgColor,
    required StatusColors statusColors,
    required bool isTracking,
  }) {
    final bool isAttention = status == ParameterStatus.attention;
    // --- Use theme colors for dark mode compatibility --- 
    final Color cardBgColor = Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor;
    final Color titleColor = Theme.of(context).textTheme.titleMedium?.color ?? Colors.white;
    final Color valueColor = Theme.of(context).textTheme.headlineSmall?.color ?? Colors.white;
    final Color unitColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey[400]!;
    final Color changeValueColor = _getChangeColor(change, context, isDarkMode: Theme.of(context).brightness == Brightness.dark); // Pass brightness
    final IconData changeIconData = _getChangeIconData(change); // Get icon data
    final Color statusIconColor = statusColors.getColor(status); // Get specific status color
    // -----------------------------------------------------

    return Card(
       color: cardBgColor, // Use theme card color
       elevation: 1.0,
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
       child: Padding(
         padding: const EdgeInsets.all(12.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween, // Allow space for star
               children: [
                 // Show star if tracking
                 if (isTracking) 
                    Icon(Icons.star, color: Colors.amber.shade600, size: 16)
                 else 
                    const SizedBox(width: 16), // Placeholder if not tracking
                  Icon(icon, color: iconColor, size: 18),
               ],
             ),
             Flexible(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500, color: titleColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                       crossAxisAlignment: CrossAxisAlignment.baseline,
                       textBaseline: TextBaseline.alphabetic,
                       children: [
                         Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 20, color: valueColor)), 
                         const SizedBox(width: 3),
                         Flexible(child: Text(unit, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: unitColor, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)), 
                       ],
                    ),
                 ],
               ),
             ),
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 // Re-introduce change display
                 Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(changeIconData, size: 12, color: changeValueColor), // Use IconData and color
                     const SizedBox(width: 3),
                     Text(
                        change, 
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11, 
                          color: changeValueColor // Use calculated change color
                        )
                      ),
                   ],
                 ),
                 isAttention 
                     ? Icon(Icons.warning_amber_rounded, size: 14, color: statusIconColor)
                     : const SizedBox(width: 14),
               ],
             )
           ],
         ),
       ),
    );
  }

  IconData _getChangeIconData(String change) { // Renamed and return IconData
    if (change.startsWith('+')) {
      return Icons.arrow_upward;
    } else if (change.startsWith('-')) {
      return Icons.arrow_downward;
    } else {
      return Icons.remove; // Return a neutral icon like 'remove' (horizontal line)
    }
  }

  Color _getChangeColor(String change, BuildContext context, {bool isDarkMode = false}) { // Added isDarkMode
    // Use theme colors for better dark mode contrast
    final Color increaseColor = isDarkMode ? Colors.greenAccent[400]! : Colors.green[700]!;
    final Color decreaseColor = isDarkMode ? Colors.redAccent[100]! : Colors.red[700]!;
    final Color neutralColor = isDarkMode ? Colors.grey[500]! : Colors.grey[600]!;

    if (change.startsWith('+')) {
      return increaseColor;
    } else if (change.startsWith('-')) {
      return decreaseColor;
    } else {
      return neutralColor;
    }
  }

  Widget _buildRecentExams(BuildContext context) {
    final DateFormat formatter = DateFormat('dd MMM yyyy');
    final statusColors = StatusColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             // Add Icon before title
             Row(
                children: [
                  Icon(Icons.article, color: Theme.of(context).primaryColor, size: 22), // Changed Icon & Color
                  const SizedBox(width: 8), // Spacing
                   Text(
                    'Exámenes Recientes',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
             ),
            ElevatedButton(
              onPressed: _pickAndProcessFile,
              style: ElevatedButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(10),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Icon(Icons.add, size: 20),
            ),
          ],
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
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentExams.length,
              itemBuilder: (context, index) {
                final examData = recentExams[index];
                final examId = examData['id'] as int?;
                final fileName = examData['fileName'] as String? ?? 'Nombre no disponible';
                final importDate = DateTime.parse(examData['importDate'] as String? ?? DateTime.now().toIso8601String());
                final attentionCount = examData['attentionCount'] as int? ?? 0;
                
                return GestureDetector(
                  onLongPress: () {
                     if (examId != null) {
                       _deleteExam(examId, fileName);
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
                      subtitle: Row( // Wrap subtitle in a Row
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]), // Changed Icon
                          const SizedBox(width: 4), // Add spacing
                          Text(
                            formatter.format(importDate),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
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
                              // Wrap Text in Row and add Icon
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

  // --- Dialog to confirm untracking from Home screen --- 
  Future<void> _showUntrackDialogFromHome(ParameterRecord parameter, String changeString) async {
     // Note: We might not strictly need changeString here, but kept for consistency if needed later
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
        _loadData(); // Reload all data for HomeScreen, including tracked parameters
      } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error al quitar seguimiento: $e')),
         );
      }
    }
  }

  // --- Helper to add parameter to tracking from status sections ---
  Future<void> _addParameterToTracking(BuildContext context, ParameterRecord parameter) async {
     try {
       await dbService.addTrackedParameter(parameter.category, parameter.parameterName);
       if (mounted && context.mounted) { // Check mounted status for both widget and context
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
                content: Text('"${parameter.parameterName}" añadido a seguimiento.', style: const TextStyle(color: Colors.white)), 
                backgroundColor: Colors.green[700],
                duration: const Duration(seconds: 2),
             ),
          );
          // --- Reload tracked parameters for immediate update ---
          setState(() { 
              _trackedParametersFuture = _loadTrackedParametersData(); 
          });
          // -----------------------------------------------------
       }
     } catch (e) {
       print("Error adding parameter to tracking from HomeScreen: $e");
       if (mounted && context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
                content: Text('Error al añadir "${parameter.parameterName}" a seguimiento.', style: const TextStyle(color: Colors.white)), 
                backgroundColor: Theme.of(context).colorScheme.error,
                duration: const Duration(seconds: 2),
              ),
           );
       }
     }
  }
  // ----------------------------------------------------------------
}
