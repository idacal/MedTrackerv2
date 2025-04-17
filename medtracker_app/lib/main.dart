import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Keep provider import

// Import the main scaffold
import 'screens/main_scaffold.dart'; 
// Import the model defining ParameterStatus
import 'models/parameter_record.dart'; 

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
    // Define custom colors from the mockup
    const Color primaryBlue = Color(0xFF4285F4);
    const Color statusGreen = Color(0xFF4CAF50); // Green
    const Color statusWatch = Color(0xFFFFA726); // Amber/Orange for Watch
    // Use a distinct Yellow/Amber for Attention
    const Color statusAttention = Color(0xFFFFC107); // Material Amber 500
    const Color errorRed = Color(0xFFF44336); 

    return MaterialApp(
      title: 'MedTracker',
      theme: ThemeData(
        // Use ColorScheme for more flexible theming
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue, // Base color for generating scheme
          primary: primaryBlue,    // Ensure primary is exactly this blue
          secondary: statusWatch,   // Keep Amber700 as secondary, distinct from attention yellow
          error: errorRed,        // Use Red for error states
          // Define brightness or other scheme colors if needed
          // brightness: Brightness.light,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true, // Enable Material 3 styling

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

      ),
       // --- NO DARK THEME DEFINED FOR SIMPLICITY NOW ---
      // darkTheme: ..., 
      // themeMode: ThemeMode.system, 
      debugShowCheckedModeBanner: false, 
      // Ensure home points to MainScaffold
      home: const MainScaffold(), 
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
