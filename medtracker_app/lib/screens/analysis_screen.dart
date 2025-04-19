import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Import fl_chart for radar chart

// Convert to StatefulWidget
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Data remains the same, but not final if we plan to load dynamically later
  final List<String> systemTitles = const [
    'Cardiovascular', 'Metabólico', 'Hematológico', 'Inmunológico', 'Nutricional', 'Hepático'
  ];
  // Keep data initialization out of build if possible, but it's ok here for now
  // since it depends on non-const values (withOpacity)
  final List<RadarDataSet> radarDataSets = [
    RadarDataSet(
      dataEntries: const [
        RadarEntry(value: 4.5), RadarEntry(value: 3.8), RadarEntry(value: 4.0),
        RadarEntry(value: 3.5), RadarEntry(value: 4.2), RadarEntry(value: 4.8),
      ],
      borderColor: Colors.blue, fillColor: Colors.blue.withOpacity(0.4),
      borderWidth: 2, entryRadius: 3,
    ),
    RadarDataSet(
      dataEntries: const [
        RadarEntry(value: 5.0), RadarEntry(value: 5.0), RadarEntry(value: 5.0),
        RadarEntry(value: 5.0), RadarEntry(value: 5.0), RadarEntry(value: 5.0),
      ],
      borderColor: Colors.green, fillColor: Colors.green.withOpacity(0.2),
      borderWidth: 2, entryRadius: 3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize TabController (adjust length based on number of tabs)
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // colorScheme might not be needed directly here anymore
    // final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis Inteligente'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 1.0,
        automaticallyImplyLeading: false,
        actions: [
           IconButton(
             icon: Icon(Icons.psychology_outlined, color: Colors.white.withOpacity(0.8)),
             tooltip: 'Información sobre el análisis',
             onPressed: () { /* ... */ },
           ),
        ],
        // Add TabBar to the bottom of the AppBar
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Patrones'),
            Tab(text: 'Tendencias'),
            Tab(text: 'Predicciones'),
          ],
        ),
      ),
      // Use TabBarView for the body
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Resumen
          _buildSummaryTab(context),

          // Tab 2: Patrones
          _buildPatternsTab(context),

          // Tab 3: Tendencias
          _buildTrendsTab(context),
          
          // Tab 4: Predicciones
          _buildPredictionsTab(context),
        ],
      ),
    );
  }

  // --- Build methods for each tab content --- 

  Widget _buildSummaryTab(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionTitle(context, Icons.lightbulb_outline, 'Insights Personalizados'),
        Card(
          elevation: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                 Expanded(
                   child: Text(
                     '⚠\u{fe0f} Patrón de deficiencia de hierro emergente detectado.', // Example insight
                     style: textTheme.bodyMedium?.copyWith(color: Colors.orange[800]),
                   ),
                 ),
                 Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {}, iconSize: 20, constraints: const BoxConstraints()),
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {}, iconSize: 20, constraints: const BoxConstraints()),
                   ],
                 )
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle(context, Icons.radar_outlined, 'Estado de Sistemas Corporales'),
        Card(
          elevation: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
               children: [
                 SizedBox(
                   height: 250,
                   child: RadarChart(
                     RadarChartData(
                       dataSets: radarDataSets, // Use the data defined in the state
                       radarBackgroundColor: Colors.transparent,
                       borderData: FlBorderData(show: false),
                       radarBorderData: BorderSide.none,
                       getTitle: (index, angle) {
                          final style = textTheme.bodySmall?.copyWith(color: Colors.grey[700]);
                          if (index < systemTitles.length) {
                            return RadarChartTitle(text: systemTitles[index]);
                          }
                          return RadarChartTitle(text: '');
                       },
                       tickCount: 5,
                       ticksTextStyle: const TextStyle(color: Colors.grey, fontSize: 10),
                       tickBorderData: BorderSide(color: Colors.grey, width: 0.5),
                       gridBorderData: BorderSide(color: Colors.grey, width: 0.5),
                       titleTextStyle: textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                     ),
                     swapAnimationDuration: const Duration(milliseconds: 400),
                   ),
                 ),
                 const SizedBox(height: 16),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                      _buildLegendItem(Colors.blue, 'Estado actual'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.green, 'Nivel óptimo'),
                   ],
                 ),
                  const SizedBox(height: 8),
                 Text(
                     'Análisis basado en parámetros clasificados.',
                     style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                     textAlign: TextAlign.center,
                   ),
               ]
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Button might belong outside tabs or at the end of a specific tab?
        // For now, keep it out or remove if each tab has its own actions.
         Center(
           child: ElevatedButton.icon(
             icon: const Icon(Icons.science_outlined),
             label: const Text('Ejecutar nuevo análisis'), // Changed label maybe?
             onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Ejecutar análisis no implementado.')),
                );
             },
             style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
             ),
           ),
        )
      ],
    );
  }

  Widget _buildPatternsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildPlaceholderSection(context, 'Clusters de Patrones', Icons.hub_outlined),
        const SizedBox(height: 16),
        _buildPlaceholderSection(context, 'Anomalías Detectadas', Icons.warning_amber_outlined),
      ],
    );
  }

  Widget _buildTrendsTab(BuildContext context) {
     return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
         _buildPlaceholderSection(context, 'Patrones Temporales', Icons.timeline_outlined),
         // Here we would add the LineChart later
      ],
    );
  }

  Widget _buildPredictionsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildPlaceholderSection(context, 'Predicciones de Riesgo', Icons.health_and_safety_outlined),
        const SizedBox(height: 16),
        _buildPlaceholderSection(context, 'Análisis IA', Icons.auto_awesome_outlined),
        const SizedBox(height: 16),
        _buildPlaceholderSection(context, 'Predicciones IA', Icons.online_prediction_outlined),
      ],
    );
  }

  // --- Helper Widgets (Keep these) --- 

  Widget _buildSectionTitle(BuildContext context, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

   Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildPlaceholderSection(BuildContext context, String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, icon, title),
        Card(
          elevation: 1.0,
           color: Theme.of(context).cardColor.withOpacity(0.5),
          child: const SizedBox(
            height: 80,
            child: Center(
              child: Text('(Próximamente)', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ),
      ],
    );
  }
} 