import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'dart:io'; // For File
import 'package:flutter/foundation.dart'; // For kDebugMode

import '../services/database_service.dart'; // Import DatabaseService

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final dbService = DatabaseService(); // Add DatabaseService instance
  bool _isProcessingGlossary = false; // Loading state for glossary update

  // --- File Picking and Processing Logic for Glossary ---
  Future<void> _pickAndProcessGlossaryFile() async {
      if (_isProcessingGlossary) return; // Prevent multiple calls
      
      setState(() { _isProcessingGlossary = true; });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccionando archivo de glosario...'), duration: Duration(seconds: 2)),
      );

      print("Attempting to pick glossary file...");
      try {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
              // Use FileType.any for better compatibility
              type: FileType.any, 
              // allowedExtensions: ['json'], // Remove this line
          );

          if (result != null && result.files.single.path != null) {
              String path = result.files.single.path!;
              String fileName = result.files.single.name;
              print("Glossary file picked: $fileName at $path");

              // --- Add manual check for .json extension ---
              if (!fileName.toLowerCase().endsWith('.json')) {
                  print("Selected file is not a JSON file.");
                   if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Por favor, selecciona un archivo .json.'), backgroundColor: Colors.orangeAccent),
                      );
                   }
                  // Reset loading state and stop processing
                  setState(() { _isProcessingGlossary = false; });
                  return; 
              }
              // --------------------------------------------

              try {
                  final file = File(path); 
                  String jsonString = await file.readAsString();
                  print("Glossary file content read successfully.");

                  ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Actualizando glosario...'), duration: Duration(seconds: 2)),
                  );
                  
                  // Call the database service method
                  await dbService.updateGlossaryFromJson(jsonString);
                  // --- Call debug print (use public method name) --- 
                  await dbService.debugPrintGlossary();
                  // ----------------------

                  print("Successfully updated glossary from: $fileName");
                   if (mounted) { // Check mounted before showing SnackBar
                     ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Glosario actualizado desde "$fileName".'), backgroundColor: Colors.green[700]),
                     );
                   }

              } catch (e) {
                  print("Error reading or processing glossary file content: $e");
                   if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al leer o procesar el archivo de glosario: $e'), backgroundColor: Theme.of(context).colorScheme.error),
                      );
                   }
              }

          } else {
              print("Glossary file picking cancelled by user.");
          }
      } catch (e) {
          print("Error picking glossary file: $e");
           if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al seleccionar archivo de glosario: $e'), backgroundColor: Theme.of(context).colorScheme.error),
              );
           }
      } finally {
        if (mounted) {
            setState(() { _isProcessingGlossary = false; }); // Always finish loading state
        }
      }
  }
  // ----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Placeholder - Implement screen UI based on description later
    // This could include user details, settings, app info, etc.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil y Configuración'),
      ),
      body: ListView( // Use ListView for potential list of settings
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
             leading: Icon(Icons.person_pin_rounded),
             title: Text('Usuario'),
             subtitle: Text('user@example.com'), // Example User ID
          ),
          Divider(),
          ListTile(
             leading: Icon(Icons.color_lens_outlined),
             title: Text('Tema'),
             subtitle: Text('Claro / Oscuro (Próximamente)'),
             // onTap: () { /* Change theme */ },
          ),
           ListTile(
             leading: Icon(Icons.notifications_none),
             title: Text('Notificaciones'),
             subtitle: Text('Activadas (Próximamente)'),
             // onTap: () { /* Notification settings */ },
          ),
           Divider(),
           ListTile(
             leading: Icon(Icons.info_outline),
             title: Text('Acerca de MedTracker'),
             subtitle: Text('Versión 1.0.0'), // Example version
             // onTap: () { /* Show about dialog */ },
          ),
          ListTile(
             leading: Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.secondary),
             title: const Text('Actualizar Glosario'),
             subtitle: const Text('Carga un archivo JSON con descripciones.'),
             trailing: _isProcessingGlossary 
                       ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                       : const Icon(Icons.upload_file),
             onTap: _isProcessingGlossary ? null : _pickAndProcessGlossaryFile, // Disable while processing
          ),
          ListTile(
             leading: Icon(Icons.delete_sweep_outlined, color: Theme.of(context).colorScheme.error),
             title: const Text('Borrar Todos los Datos'),
          ),
        ],
      ),
    );
  }
} 