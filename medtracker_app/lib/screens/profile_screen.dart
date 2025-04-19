import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Import file_picker
import 'dart:io'; // For File
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:provider/provider.dart'; // Import Provider

import '../services/database_service.dart'; // Import DatabaseService
import '../providers/theme_provider.dart'; // Import ThemeProvider

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

  // --- Logic for Deleting All Data ---
  Future<void> _confirmAndDeleteAllData() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Borrado Total'),
          content: const Text(
              '¿Estás SEGURO de que quieres borrar TODOS los exámenes, parámetros, glosario y seguimiento? \n\nESTA ACCIÓN ES IRREVERSIBLE.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('BORRAR TODO'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
         // Show loading indicator / message
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Borrando todos los datos...'), duration: Duration(seconds: 3)),
         );
         
        await dbService.deleteAllUserData(); // Call the DB service method
        
         // Show success message
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Todos los datos han sido borrados.', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.green[700],
              ),
            );
            // Optionally navigate back or refresh home screen if needed
            // Navigator.of(context).pop(); // Example: Close profile screen
         }

      } catch (e) {
         print("Error deleting all user data: $e");
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('Error al borrar los datos: $e', style: const TextStyle(color: Colors.white)),
               backgroundColor: Theme.of(context).colorScheme.error,
             ),
           );
         }
      }
    }
  }
  // -----------------------------------

  @override
  Widget build(BuildContext context) {
    // --- Get ThemeProvider --- 
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode(context); // Use helper
    // -----------------------

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
          SwitchListTile(
             title: const Text('Tema'),
             subtitle: Text(isDarkMode ? 'Oscuro' : 'Claro'),
             value: isDarkMode,
             onChanged: (value) {
               Provider.of<ThemeProvider>(context, listen: false).setThemeMode(
                 value ? ThemeMode.dark : ThemeMode.light
               );
             },
             secondary: Icon(Icons.color_lens_outlined, color: Theme.of(context).colorScheme.secondary),
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
             onTap: _confirmAndDeleteAllData, // Call delete confirmation
          ),
        ],
      ),
    );
  }
} 