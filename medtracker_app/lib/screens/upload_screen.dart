import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io'; // For File
import 'dart:convert'; // For utf8
import 'package:flutter/foundation.dart'; // For kDebugMode

// Import Database Service
import '../services/database_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isLoading = false;
  String? _feedbackMessage;
  Color _feedbackColor = Colors.red; // Default to error color

  Future<void> _pickAndProcessFile() async {
    setState(() {
      _isLoading = true;
      _feedbackMessage = null; // Clear previous message
    });

    try {
      // Pick a file, temporarily allow ANY type for diagnostics
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // <-- CHANGE: Allow any file type temporarily
        // allowedExtensions: ['json'], // <-- REMOVE/COMMENT OUT filter
        dialogTitle: 'Selecciona archivo (Prueba)',
      );

      if (result != null && result.files.single.path != null) {
        PlatformFile fileInfo = result.files.single;
        File file = File(fileInfo.path!);
        String fileName = fileInfo.name;
        
        // ADD VALIDATION: Check if the selected file IS actually a .json file
        if (!fileName.toLowerCase().endsWith('.json')) {
          throw Exception('Archivo seleccionado no es .json. Por favor, elige un archivo con la extensión .json.');
        }
        
        if (kDebugMode) {
          print('Selected file: ${file.path}');
        }

        // Read file content as String (handle potential encoding issues)
        // Using try-catch for file reading itself
        String jsonString;
        try {
          jsonString = await file.readAsString(encoding: utf8);
        } catch (e) {
           throw Exception('Error al leer el archivo: $e');
        }
        
        // Call Database Service to insert data
        final dbService = DatabaseService(); 
        int? insertedId = await dbService.insertExamFromJson(jsonString, fileName);

        if (insertedId != null) {
          setState(() {
            _feedbackMessage = 'Examen "$fileName" cargado con éxito (ID: $insertedId).';
            _feedbackColor = Colors.green;
          });
           // Optional: Pop screen after a short delay and pass back a success flag
           Future.delayed(const Duration(seconds: 2), () {
             if (mounted) Navigator.pop(context, true); // Pass true for success
           });
        } else {
          // Use a more specific error message if insertExamFromJson provides one
          throw Exception('Error al guardar el examen en la base de datos. Revisa el formato del JSON.');
        }
      } else {
        // User canceled the picker
        if (kDebugMode) {
           print('File selection cancelled by user.');
        }
        // Don't show error message if user just cancelled
        // setState(() {
        //   _feedbackMessage = 'Selección de archivo cancelada.';
        //   _feedbackColor = Colors.orange;
        // });
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error processing file: $e");
      }
      setState(() {
        // Provide a user-friendly error message
        String errorMessage = 'Ocurrió un error inesperado.';
        if (e is FileSystemException) {
          errorMessage = 'Error de archivo: ${e.message}';
        } else if (e is FormatException) {
           errorMessage = 'Error de formato JSON: El archivo no parece ser un JSON válido. (${e.message})';
        } else {
           errorMessage = 'Error al procesar el archivo: ${e.toString()}';
        }
        _feedbackMessage = errorMessage;
        _feedbackColor = Colors.red;
      });
    } finally {
      // Ensure loading indicator is always turned off
      if (mounted) {
        setState(() {
           _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cargar Nuevo Examen'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              InkWell(
                 onTap: _isLoading ? null : _pickAndProcessFile,
                 borderRadius: BorderRadius.circular(12.0),
                 child: Container(
                   padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 20.0),
                   decoration: BoxDecoration(
                     color: Colors.blueGrey[50],
                     borderRadius: BorderRadius.circular(12.0),
                     border: Border.all(
                       color: primaryColor.withOpacity(0.6), 
                       width: 1.5,
                     ),
                   ),
                   child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                           Icons.add_circle_outline_rounded, 
                           size: 50, 
                           color: primaryColor.withOpacity(0.8),
                         ),
                         const SizedBox(height: 16),
                         Text(
                            'Toca para seleccionar archivo JSON',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.grey[700]
                            ),
                          ),
                      ],
                   ),
                 ),
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                height: 60,
                child: Center(
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : _feedbackMessage != null
                          ? Text(
                              _feedbackMessage!,
                              style: TextStyle(
                                  color: _feedbackColor,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            )
                          : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 