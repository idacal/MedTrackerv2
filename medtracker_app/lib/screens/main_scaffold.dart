import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart'; // Placeholder for Profile
import 'upload_screen.dart'; // Import UploadScreen for potential FAB or direct access

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  // List of widgets to display based on the selected index
  // Use const constructors for the screens if they don't take parameters
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(), 
    HistoryScreen(),
    ProfileScreen(), 
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToUpload() {
     Navigator.push(
        context,
        // Ensure UploadScreen() is const if possible
        MaterialPageRoute(builder: (context) => const UploadScreen()), 
     );
  }

  @override
  Widget build(BuildContext context) {
    // Define colors based on the theme for clarity
    // final Color primaryColor = Theme.of(context).colorScheme.primary;
    // Use accentColor if defined, otherwise fallback to secondary or primary
    // final Color fabColor = Theme.of(context).colorScheme.secondary; 

    return Scaffold(
      // Use IndexedStack to keep the state of the screens when switching tabs
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      // --- REMOVE OLD NAVIGATION AND FAB ---
      /*
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), 
        notchMargin: 6.0, 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(Icons.home_outlined, Icons.home, 'Inicio', 0),
            _buildNavItem(Icons.history_outlined, Icons.history, 'Historial', 1),
            const SizedBox(width: 40), // Placeholder for the FAB notch space
            _buildNavItem(Icons.person_outline, Icons.person, 'Perfil', 2),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToUpload,
        tooltip: 'Cargar Examen',
        backgroundColor: fabColor, 
        foregroundColor: Colors.white,
        elevation: 2.0,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      */
      // ------------------------------------
    );
  }

  // --- REMOVE _buildNavItem HELPER (No longer used) ---
  /*
  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    // ... (implementation)
  }
  */

} 