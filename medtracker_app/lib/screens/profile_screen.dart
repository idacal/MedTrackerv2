import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
        children: const [
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
        ],
      ),
    );
  }
} 