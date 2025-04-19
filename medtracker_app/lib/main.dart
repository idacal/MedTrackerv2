import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Keep provider import
import 'screens/home_screen.dart';
import 'services/database_service.dart'; // Ensure DB is initialized
import 'providers/theme_provider.dart'; // Import ThemeProvider

// Import the main scaffold
import 'screens/main_scaffold.dart'; 
// Import the model defining ParameterStatus
import 'models/parameter_record.dart'; 

// Import the database service if needed for early initialization (optional)
// import 'services/database_service.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Optional: Initialize database early if needed globally before first screen
  // await DatabaseService().database; 
  
  // Run the app, wrapping with ChangeNotifierProvider
  runApp(ChangeNotifierProvider(
       create: (context) => ThemeProvider(), // Create ThemeProvider instance
       child: const MedTrackerApp(),
     ));
}

class MedTrackerApp extends StatelessWidget {
  const MedTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define custom colors from the mockup
    const Color primaryBlue = Color(0xFF4285F4);
    const Color statusGreen = Color(0xFF4CAF50); // Green
    const Color statusWatch = Color(0xFFFFA726); // Amber/Orange for Watch
    // Use a distinct Yellow/Amber for Attention
    const Color statusAttention = Color(0xFFFFC107); // Material Amber 500
    const Color errorRed = Color(0xFFF44336); 

    // --- Consume ThemeProvider --- 
    final themeProvider = Provider.of<ThemeProvider>(context);
    // ---------------------------
    
    // Define your base light theme
    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue, // Base color for generating scheme
          primary: primaryBlue,    // Ensure primary is exactly this blue
          secondary: statusWatch,   // Keep Amber700 as secondary, distinct from attention yellow
          error: errorRed,        // Use Red for error states
          brightness: Brightness.light,
       ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: Colors.grey[100], // Light grey background

      // Define card themes 
      cardTheme: CardTheme(
        elevation: 1.5, // Subtle elevation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), 
        ),
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        color: Colors.white, // Explicitly white cards
      ),
      
      // Define button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue, 
          foregroundColor: Colors.white, 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0), // Slightly more rounded
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          textStyle: const TextStyle(fontWeight: FontWeight.bold)
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
         backgroundColor: primaryBlue, // Use primary blue for FAB
         foregroundColor: Colors.white,
         elevation: 4.0,
      ),

      // Define AppBar theme matching mockup (Blue background, white text)
      appBarTheme: const AppBarTheme(
         backgroundColor: primaryBlue,
         foregroundColor: Colors.white, // Title/icon color
         elevation: 1.0, 
         centerTitle: false, // Align title left usually
         titleTextStyle: TextStyle(
           fontSize: 18, // Adjust as needed
           fontWeight: FontWeight.bold,
           color: Colors.white
         )
      ),
      
      // Define BottomAppBar theme
      bottomAppBarTheme: const BottomAppBarTheme(
        color: Colors.white, 
        elevation: 2.0,
        shape: CircularNotchedRectangle(),
        padding: EdgeInsets.zero, // Remove default padding if needed
      ),
      
      // Define ListTile theme adjustments
      listTileTheme: ListTileThemeData(
        iconColor: Colors.grey[700], // Default icon color for ListTiles
        // tileColor: Colors.transparent, // Ensure it takes card color
        // shape: ..., // Add shape if desired
      ),

      // Define text themes (optional, customize further)
      textTheme: const TextTheme(
         // Example: Make bodyLarge slightly bolder
         // bodyLarge: TextStyle(fontWeight: FontWeight.w500),
      ),
      
      // Store status colors for easy access elsewhere
      extensions: <ThemeExtension<dynamic>>[
         const StatusColors(
           normal: statusGreen,
           watch: statusWatch, // Use the specific watch color
           attention: statusAttention, // Use the specific attention color
         ),
      ],

    );
    
    // Define your dark theme
    final ThemeData darkTheme = ThemeData(
       useMaterial3: true,
       brightness: Brightness.dark,
       // Use a dark background
       scaffoldBackgroundColor: Colors.grey[900], 
       colorScheme: ColorScheme.fromSeed(
           seedColor: Colors.blue, 
           brightness: Brightness.dark,
           // Define specific dark scheme colors if needed
           primary: Colors.blue[300], // Lighter blue for dark mode primary
           secondary: Colors.amber[600], // Adjust secondary if needed
           error: Colors.redAccent[100], // Lighter red for errors
           surface: Colors.grey[850], // Card/dialog background
           onSurface: Colors.white, // Text/icon color on surface
       ),
       appBarTheme: AppBarTheme(
         backgroundColor: Colors.grey[850], // Darker app bar
         foregroundColor: Colors.white,
         elevation: 1.0,
       ),
       cardTheme: CardTheme(
         color: Colors.grey[850], // Dark card background
         elevation: 1.5,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
         margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
       ),
       // Define dark text button theme
       textButtonTheme: TextButtonThemeData(
         style: TextButton.styleFrom(
           foregroundColor: Colors.blue[300], // Lighter blue for links
         ),
       ),
       // Define dark elevated button theme (e.g., for the '+' button)
       elevatedButtonTheme: ElevatedButtonThemeData(
         style: ElevatedButton.styleFrom(
           backgroundColor: Colors.blue[700], // Slightly darker blue button
           foregroundColor: Colors.white, 
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
           padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
           textStyle: const TextStyle(fontWeight: FontWeight.bold)
         ),
       ),
        // Define dark BottomNavigationBar theme
       bottomNavigationBarTheme: BottomNavigationBarThemeData(
         backgroundColor: Colors.grey[850], // Dark background
         selectedItemColor: Colors.white, // ENSURE this is white for high contrast
         unselectedItemColor: Colors.grey[500], // Keep inactive grey
         type: BottomNavigationBarType.fixed, 
         showUnselectedLabels: true,
       ),
       // Ensure default text colors are light
       textTheme: Typography.whiteMountainView, // Use a predefined white text theme
       visualDensity: VisualDensity.adaptivePlatformDensity,
       extensions: <ThemeExtension<dynamic>>[
         const StatusColors(
           normal: Color(0xFF4CAF50), // statusGreen
           watch: Color(0xFFFFA726), // statusWatch
           attention: Color(0xFFFFC107), // statusAttention
         ),
      ],
    );

    return MaterialApp(
      title: 'MedTracker',
      debugShowCheckedModeBanner: false,
      // --- Use Theme Settings from Provider --- 
      theme: lightTheme, 
      darkTheme: darkTheme,
      themeMode: themeProvider.themeMode, // Set based on provider
      // ---------------------------------------
      home: const HomeScreen(),
    );
  }
}

// KEEP THIS StatusColors CLASS DEFINITION
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.normal,
    required this.watch,
    required this.attention,
  });

  final Color normal;
  final Color watch;
  final Color attention;

  @override
  StatusColors copyWith({Color? normal, Color? watch, Color? attention}) {
    return StatusColors(
      normal: normal ?? this.normal,
      watch: watch ?? this.watch,
      attention: attention ?? this.attention,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) {
      return this;
    }
    return StatusColors(
      normal: Color.lerp(normal, other.normal, t)!,
      watch: Color.lerp(watch, other.watch, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
    );
  }

  // Optional: Helper method to access from context
  static StatusColors of(BuildContext context) {
    return Theme.of(context).extension<StatusColors>()!;
  }
}

// ADD HELPER EXTENSION HERE
// Helper extension on StatusColors to get color based on ParameterStatus enum
extension StatusColorGetter on StatusColors {
  Color getColor(ParameterStatus status) {
    switch (status) {
      case ParameterStatus.normal: return normal;
      case ParameterStatus.watch: return watch;
      case ParameterStatus.attention: return attention;
      case ParameterStatus.unknown: 
      // Use a neutral color for unknown, maybe from the theme?
      // Returning grey for now, consistent with previous logic.
      return Colors.grey.shade600; 
    }
  }
}

// --- REMOVE DUPLICATED DEFINITIONS BELOW THIS LINE --- 

// REMOVE: Duplicated statusColorsLight
// const statusColorsLight = StatusColors(
//   normal: Colors.green,         
//   watch: Colors.orange,         
//   attention: Colors.amber.shade700, 
// );

// REMOVE: Duplicated statusColorsDark
// const statusColorsDark = StatusColors(
//   normal: Colors.greenAccent,   
//   watch: Colors.orangeAccent,   
//   attention: Colors.amberAccent, 
// );

// REMOVE: Duplicated MyApp
// class MyApp extends StatelessWidget {
//   // ... 
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       // ...
//       home: const MainScreen(), // Incorrect home
//       // ...
//     );
//   }
// }

// REMOVE: Duplicated MainScreen reference (if any)
// class MainScreen extends StatelessWidget { ... }
