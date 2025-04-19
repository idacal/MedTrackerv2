import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Imports needed for this screen
import '../services/database_service.dart';
import '../models/exam_record.dart';

// Enum for Share Duration
enum ShareDuration { fifteenMin, thirtyMin, oneHour, permanent }

// Enum for Report Format
enum ReportFormat { pdf, excel, html }

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isPasswordProtected = false;
  ShareDuration _selectedDuration = ShareDuration.permanent; // Default duration

  // --- State for Report Tab --- 
  final dbService = DatabaseService(); // Instance of DatabaseService
  Future<List<ExamRecord>>? _examListFuture;
  final Set<int> _selectedExamIds = {}; // Store IDs of selected exams
  bool _includeAllParams = true;
  bool _includeCharts = true;
  bool _includeAttention = true;
  bool _includeNotes = false;
  ReportFormat _selectedFormat = ReportFormat.pdf;
  // ---------------------------

  // --- Placeholder Data for History Tab ---
  final List<Map<String, dynamic>> _shareHistory = [
    {
      'type': 'email',
      'recipient': 'Dr. González',
      'detail': 'doctor.gonzalez@hospital.com',
      'date': DateTime(2025, 4, 19),
      'extraInfo': 'Exámenes_2023_actualizados',
      'action': 'Reenviar'
    },
    {
      'type': 'link',
      'recipient': 'Enlace compartido',
      'detail': '3 accesos • Caduca: 10 May 2025',
      'date': DateTime(2025, 4, 15),
      'extraInfo': 'Creado: 10 Abr 2025',
      'action': 'Revocar',
      'actionColor': Colors.red // Specific color for revoke
    },
  ];

  final List<Map<String, String>> _savedDoctors = [
    {
      'name': 'Dra. Martínez',
      'specialty': 'Cardiología',
      'email': 'dra.martinez@hospital.com'
    },
    {
      'name': 'Dr. Sánchez',
      'specialty': 'Medicina General',
      'email': 'dr.sanchez@clinica.com'
    },
  ];
  // ------------------------------------

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = 1; 
    _loadExams(); // <-- Load exams on init
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Helper to get display text for ShareDuration
  String _getDurationText(ShareDuration duration) {
    switch (duration) {
      case ShareDuration.fifteenMin: return '15 minutos';
      case ShareDuration.thirtyMin: return '30 minutos';
      case ShareDuration.oneHour: return '1 hora';
      case ShareDuration.permanent: return 'Permanente';
    }
  }

  // --- Method to load exams --- 
  void _loadExams() {
     setState(() {
       _examListFuture = dbService.getAllExamRecords(); // Fetch all exams
     });
  }
  // ----------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compartir Resultados'),
        backgroundColor: Theme.of(context).primaryColor, // Consistent header color
        foregroundColor: Colors.white,
        elevation: 1.0,
        automaticallyImplyLeading: false, // No back button needed here
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.description_outlined), text: 'INFORME'),
            Tab(icon: Icon(Icons.share_outlined), text: 'COMPARTIR'),
            Tab(icon: Icon(Icons.history_outlined), text: 'HISTORIAL'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReportTabContent(context),   // Placeholder for Informe
          _buildShareTabContent(context),    // Main content for Compartir
          _buildHistoryTabContent(context), // Placeholder for Historial
        ],
      ),
    );
  }

  // --- Placeholder Builders ---
  Widget _buildReportTabContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<List<ExamRecord>>(
      future: _examListFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar exámenes: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay exámenes disponibles para generar informes.'));
        }

        final exams = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Section: Seleccionar Exámenes ---
            Text('Seleccionar Exámenes', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 1.0,
              child: Column(
                // Limit height or make scrollable if too many exams
                children: exams.map((exam) {
                  final bool isSelected = _selectedExamIds.contains(exam.id);
                  return CheckboxListTile(
                    title: Text(exam.fileName),
                    subtitle: Text(DateFormat('dd MMM yyyy').format(exam.importDate)),
                    value: isSelected,
                    onChanged: (bool? value) {
                      if (exam.id != null) {
                         setState(() {
                            if (value == true) {
                              _selectedExamIds.add(exam.id!); // Use non-null assertion
                            } else {
                              _selectedExamIds.remove(exam.id!);
                            }
                         });
                      }
                    },
                    secondary: isSelected ? const Chip(label: Text('Actual', style: TextStyle(fontSize: 10)), padding: EdgeInsets.all(2), visualDensity: VisualDensity.compact) : null,
                     activeColor: Theme.of(context).primaryColor,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // --- Section: Opciones de Informe ---
            Text('Opciones de Informe', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
               elevation: 1.0,
               child: Padding(
                 padding: const EdgeInsets.symmetric(vertical: 8.0), // Padding inside card
                 child: Column(
                   children: [
                      CheckboxListTile(
                         title: const Text('Todos los parámetros'),
                         value: _includeAllParams,
                         onChanged: (val) => setState(() => _includeAllParams = val ?? false),
                         controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: Theme.of(context).primaryColor,
                      ),
                       CheckboxListTile(
                         title: const Text('Gráficos de evolución'),
                         value: _includeCharts,
                         onChanged: (val) => setState(() => _includeCharts = val ?? false),
                         controlAffinity: ListTileControlAffinity.leading,
                         dense: true,
                          activeColor: Theme.of(context).primaryColor,
                      ),
                       CheckboxListTile(
                         title: const Text('Parámetros que requieren atención'),
                         value: _includeAttention,
                         onChanged: (val) => setState(() => _includeAttention = val ?? false),
                         controlAffinity: ListTileControlAffinity.leading,
                         dense: true,
                          activeColor: Theme.of(context).primaryColor,
                      ),
                       CheckboxListTile(
                         title: const Text('Mis notas personales'),
                         value: _includeNotes,
                         onChanged: (val) => setState(() => _includeNotes = val ?? false),
                         controlAffinity: ListTileControlAffinity.leading,
                         dense: true,
                          activeColor: Theme.of(context).primaryColor,
                      ),
                   ],
                 ),
               ),
            ),
             const SizedBox(height: 24),

            // --- Section: Formato ---
            Text('Formato', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
             Card(
               elevation: 1.0,
               child: Padding(
                 padding: const EdgeInsets.symmetric(vertical: 8.0), // Padding inside card
                 child: Column(
                   children: ReportFormat.values.map((format) {
                      return RadioListTile<ReportFormat>(
                        title: Text(format.name.toUpperCase()), // PDF, EXCEL, HTML
                        value: format,
                        groupValue: _selectedFormat,
                        onChanged: (ReportFormat? value) {
                          if (value != null) {
                            setState(() {
                              _selectedFormat = value;
                            });
                          }
                        },
                         dense: true,
                         activeColor: Theme.of(context).primaryColor,
                      );
                   }).toList(),
                 ),
               ),
             ),
             const SizedBox(height: 24),

            // --- Section: Vista Previa / Descarga ---
             Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                   color: Colors.blue.shade50,
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                       child: Text(
                         'Informe médico de exámenes seleccionados',
                         style: textTheme.bodyMedium?.copyWith(color: Colors.blue.shade900)
                       ),
                    )
                  ],
                )
             ),
             const SizedBox(height: 16),
             Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   OutlinedButton.icon(
                     icon: const Icon(Icons.visibility_outlined),
                     label: const Text('Vista previa'),
                     onPressed: _selectedExamIds.isEmpty ? null : () { // Disable if no exams selected
                        // TODO: Implement preview logic
                         ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vista previa no implementada.')),
                        );
                     },
                   ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Descargar'),
                      onPressed: _selectedExamIds.isEmpty ? null : () { // Disable if no exams selected
                         // TODO: Implement download logic
                          ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Descarga no implementada.')),
                        );
                      },
                   ),
                ],
             ),
              const SizedBox(height: 16), // Bottom padding
          ],
        );
      },
    );
  }

  Widget _buildHistoryTabContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Helper function to build history cards
    Widget buildHistoryCard(Map<String, dynamic> historyItem) {
      final bool isEmail = historyItem['type'] == 'email';
      final IconData leadingIcon = isEmail ? Icons.email_outlined : Icons.link;
      final Color? actionColor = historyItem['actionColor'] as Color?;
      final String dateString = DateFormat('dd MMM yyyy').format(historyItem['date'] as DateTime);

      return Card(
        elevation: 1.0,
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Row(
                     children: [
                       Icon(leadingIcon, size: 20, color: Colors.grey[700]),
                       const SizedBox(width: 12),
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            Text(historyItem['recipient'] as String, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(historyItem['detail'] as String, style: textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                         ],
                       ),
                     ],
                   ),
                    Chip(
                      label: Text(isEmail ? 'Email' : 'Enlace', style: TextStyle(fontSize: 10, color: isEmail ? Colors.blue[800] : Colors.green[800])),
                      backgroundColor: isEmail ? Colors.blue[50] : Colors.green[50],
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      side: BorderSide.none,
                    )
                 ],
               ),
               const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Text(
                        isEmail 
                          ? 'Enviado: $dateString\n${historyItem['extraInfo']}'
                          : '${historyItem['extraInfo']}\nÚltimo acceso: $dateString', 
                         style: textTheme.bodySmall?.copyWith(color: Colors.grey[600], height: 1.4),
                     ),
                     TextButton(
                        child: Text(historyItem['action'] as String, style: TextStyle(color: actionColor ?? colorScheme.primary)),
                        onPressed: () {
                           // TODO: Implement action (Resend/Revoke)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${historyItem['action']} no implementado.')),
                           );
                        },
                     )
                  ],
               )
             ],
           ),
        ),
      );
    }
    
    // Helper function to build doctor tiles
    Widget buildDoctorTile(Map<String, String> doctor) {
      return ListTile(
        leading: CircleAvatar(child: Icon(Icons.person_outline, color: Colors.grey[600]), backgroundColor: Colors.grey[200]),
        title: Text(doctor['name']!, style: textTheme.titleMedium),
        subtitle: Text('${doctor['specialty']!} • ${doctor['email']!}', style: textTheme.bodySmall?.copyWith(color: Colors.grey[600])), 
        trailing: TextButton(
           child: const Text('Compartir'),
           onPressed: () {
              // TODO: Implement direct share with doctor
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Compartir con ${doctor['name']} no implementado.')),
              );
           },
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0), // Adjust padding
      );
    }

    return ListView(
       padding: const EdgeInsets.all(16.0),
       children: [
          Text('Historial de compartición', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_shareHistory.isEmpty)
            const Text('Aún no has compartido resultados.', style: TextStyle(color: Colors.grey))
          else
            ..._shareHistory.map((item) => buildHistoryCard(item)).toList(),
          
          const SizedBox(height: 32),
          Text('Médicos guardados', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
           if (_savedDoctors.isEmpty)
            const Text('No tienes médicos guardados.', style: TextStyle(color: Colors.grey))
          else
            ..._savedDoctors.map((doc) => buildDoctorTile(doc)).toList(),

          const SizedBox(height: 20),
          Center(
             child: ElevatedButton.icon(
               icon: const Icon(Icons.add_circle_outline),
               label: const Text('Añadir nuevo médico'),
               onPressed: () {
                  // TODO: Implement add new doctor functionality
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Añadir médico no implementado.')),
                  );
               },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.secondary, // Use secondary color?
                  foregroundColor: colorScheme.onSecondary, 
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                ),
             ),
          ),
          const SizedBox(height: 16), // Bottom padding
       ],
    );
  }
  
  // --- Builder for "Compartir" Tab ---
  Widget _buildShareTabContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView( // Use ListView for scrolling
      padding: const EdgeInsets.all(16.0),
      children: [
        // --- Section: Compartir con Código QR ---
        Card(
          elevation: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compartir con código QR', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                 Text('Duración del enlace', style: textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                 const SizedBox(height: 8),
                 // Dropdown for Duration
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                   decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8.0),
                   ),
                   child: DropdownButtonHideUnderline(
                      child: DropdownButton<ShareDuration>(
                        value: _selectedDuration,
                        isExpanded: true, // Make dropdown take available width
                        icon: const Icon(Icons.arrow_drop_down),
                        elevation: 16,
                        style: textTheme.bodyLarge,
                        onChanged: (ShareDuration? newValue) {
                          if (newValue != null) {
                             setState(() {
                               _selectedDuration = newValue;
                             });
                          }
                        },
                        items: ShareDuration.values
                            .map<DropdownMenuItem<ShareDuration>>((ShareDuration value) {
                          return DropdownMenuItem<ShareDuration>(
                            value: value,
                            child: Text(_getDurationText(value)),
                          );
                        }).toList(),
                      ),
                   ),
                 ),
                const SizedBox(height: 16),
                // QR Code Display Placeholder
                 Center(
                   child: Container(
                     width: 150, 
                     height: 150, 
                     color: Colors.grey[200], 
                     child: const Center(child: Icon(Icons.qr_code_2, size: 80, color: Colors.grey))
                    ),
                 ),
                const SizedBox(height: 16),
                Center(
                   child: ElevatedButton.icon(
                     icon: const Icon(Icons.qr_code_scanner), // Or Icons.qr_code_2_outlined
                     label: const Text('Generar QR'),
                     onPressed: () {
                        // TODO: Implement QR code generation logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Generación de QR no implementada.')),
                        );
                     },
                     style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                   ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // --- Section: Compartir con Profesionales Médicos ---
        Text('Compartir con profesionales médicos', style: textTheme.titleMedium),
        const SizedBox(height: 16),

        // Card: Enviar por email
        Card(
          elevation: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enviar por email', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email del médico',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Mensaje (opcional)',
                    hintText: 'Añade un mensaje para tu médico...',
                    border: OutlineInputBorder(),
                     prefixIcon: Icon(Icons.message_outlined),
                  ),
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Enviar informe'),
                    onPressed: () {
                      // TODO: Implement email sending logic
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Envío por email no implementado.')),
                      );
                    },
                     style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Card: Compartir enlace
        Card(
          elevation: 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compartir enlace', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                 // Placeholder for link display
                 Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                    decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey.shade400),
                       borderRadius: BorderRadius.circular(8.0),
                       color: Colors.grey.shade100,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('https://medtracker.app/s/...', style: TextStyle(color: Colors.grey[600])),
                        IconButton(
                           icon: const Icon(Icons.copy, size: 18),
                           tooltip: 'Copiar enlace',
                           onPressed: () { /* TODO: Implement copy */ },
                           padding: EdgeInsets.zero,
                           constraints: const BoxConstraints(),
                        )
                      ],
                    )
                 ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text('Protección con contraseña', style: textTheme.bodyLarge),
                  subtitle: Text('Para acceso privado a tus datos', style: textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                  value: _isPasswordProtected,
                  onChanged: (bool value) {
                    setState(() {
                      _isPasswordProtected = value;
                    });
                  },
                   contentPadding: EdgeInsets.zero, // Remove default padding
                   activeColor: colorScheme.primary,
                ),
                 const SizedBox(height: 16),
                 Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.link),
                    label: const Text('Generar enlace'),
                     onPressed: () {
                       // TODO: Implement link generation logic
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Generación de enlace no implementado.')),
                      );
                     },
                      style: ElevatedButton.styleFrom(minimumSize: const Size(200, 45)),
                  ),
                 ),
                 const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_clock_outlined, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Los enlaces caducan automáticamente después de 30 días por seguridad', 
                        style: textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                 )
              ],
            ),
          ),
        ),
      ],
    );
  }
} 