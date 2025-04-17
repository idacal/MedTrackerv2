import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Keep provider import

// Import the main scaffold
import 'screens/main_scaffold.dart'; 

// Import the database service if needed for early initialization (optional)
// import 'services/database_service.dart';

void main() {
  // Ensure Flutter bindings are initialized for plugin usage
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize DatabaseService singleton here if needed for eager initialization
  // final dbService = DatabaseService(); 
  // await dbService.database; // Example: Force initialization if required early

  runApp(const MedTrackerApp());
}

class MedTrackerApp extends StatelessWidget {
  const MedTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Remove MultiProvider wrapper for now
    // return MultiProvider(
    //   providers: [
    //   ],
    //   child: MaterialApp(
    //     ...
    //   ),
    // );
    
    // Return MaterialApp directly
    return MaterialApp(
      title: 'MedTracker',
      theme: ThemeData(
        // Define the primary color swatch
        primarySwatch: Colors.blue, 
        // Use ColorScheme for more modern color definitions
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4285F4), // Use the specific blue as seed
          primary: const Color(0xFF4285F4),    // Override primary if needed
          secondary: const Color(0xFFFFA726),  // Amber for accent/FAB (example)
          // Define status colors
          error: const Color(0xFFF44336),      // Red for Attention
          // Add custom colors if needed:
          // Example: Green color for Normal status
          // onSurface: Colors.green, // Placeholder example
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true, // Enable Material 3 features

        // Define card themes consistent with Material 3 elevation
        cardTheme: CardTheme(
          elevation: 1.0, // M3 default elevation for cards
           shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0), // M3 uses larger radius
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        ),
        
        // Define button themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4285F4), // CTA blue
            foregroundColor: Colors.white, // Text color on button
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
           backgroundColor: const Color(0xFFFFA726), // Amber color for FAB (example)
           foregroundColor: Colors.black, // Text/icon color on FAB
           // shape: ..., // Default circular shape is usually fine
        ),

        // Define AppBar theme
        appBarTheme: const AppBarTheme(
           backgroundColor: Colors.white, // Or match primary color?
           foregroundColor: Colors.black, // Title/icon color
           elevation: 0.5, // Subtle elevation
           centerTitle: true, // Center title if desired
        ),
        
        // Define BottomAppBar theme
        bottomAppBarTheme: const BottomAppBarTheme(
          color: Colors.white, // Background color of the bar
          elevation: 1.0,
          // padding: EdgeInsets.symmetric(horizontal: 10.0), // Adjust padding if needed
        ),

        // Define text themes (optional, customize further if needed)
        // textTheme: TextTheme(...),
      ),
      debugShowCheckedModeBanner: false, // Remove debug banner
      home: const MainScaffold(), // Start with the main scaffold widget
    );
  }
}
