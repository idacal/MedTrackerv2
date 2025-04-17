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
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    // Use accentColor if defined, otherwise fallback to secondary or primary
    final Color fabColor = Theme.of(context).colorScheme.secondary; 

    return Scaffold(
      // Use IndexedStack to keep the state of the screens when switching tabs
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      // Use BottomAppBar for the notch effect with FAB
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(), // Shape for the notch
        notchMargin: 6.0, // Margin around the notch
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(Icons.home_outlined, Icons.home, 'Inicio', 0),
            _buildNavItem(Icons.history_outlined, Icons.history, 'Historial', 1),
            const SizedBox(width: 40), // Placeholder for the FAB notch space
            _buildNavItem(Icons.person_outline, Icons.person, 'Perfil', 2),
             // Add more items if needed, adjust spacing
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToUpload,
        tooltip: 'Cargar Examen',
        backgroundColor: fabColor, 
        foregroundColor: Colors.white, // Ensure contrast for icon
        elevation: 2.0,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, // Dock FAB in the notch
    );
  }

  // Helper widget to build navigation bar items to reduce repetition
  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    final Color color = isSelected ? Theme.of(context).colorScheme.primary : Colors.grey;
    return IconButton(
      icon: Icon(isSelected ? activeIcon : icon, color: color),
      tooltip: label, // Tooltip for accessibility
      onPressed: () => _onItemTapped(index),
    );
    // Alternative: Use InkWell for larger tap area if needed
    // return InkWell(
    //   onTap: () => _onItemTapped(index),
    //   child: Padding(
    //     padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    //     child: Column(
    //       mainAxisSize: MainAxisSize.min,
    //       children: [
    //         Icon(isSelected ? activeIcon : icon, color: color),
    //         Text(label, style: TextStyle(color: color, fontSize: 12)),
    //       ],
    //     ),
    //   ),
    // );
  }

} 