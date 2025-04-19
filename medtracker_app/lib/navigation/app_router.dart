import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:medtracker_app/screens/main_scaffold_shell.dart'; // We will create this next
import 'package:medtracker_app/screens/home_screen.dart';
import 'package:medtracker_app/screens/history_screen.dart';
import 'package:medtracker_app/screens/profile_screen.dart';
import 'package:medtracker_app/screens/placeholder_screen.dart'; // Simple placeholder
import 'package:medtracker_app/screens/parameter_list_screen.dart';
import 'package:medtracker_app/screens/exam_categories_screen.dart';
import 'package:medtracker_app/screens/category_parameters_screen.dart';
import 'package:medtracker_app/screens/parameter_detail_screen.dart';
import 'package:medtracker_app/screens/tracked_parameters_screen.dart';
// Import model needed for ParameterStatus enum
import 'package:medtracker_app/models/parameter_record.dart';
// Import detail screens later when we add their routes

// Define Navigator Keys
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

// Configure GoRouter
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home', // Start at the home tab
  debugLogDiagnostics: true, // Enable debug logging
  routes: <RouteBase>[
    // ShellRoute for main navigation with BottomNavigationBar
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (BuildContext context, GoRouterState state, Widget child) {
        // This builder creates the Scaffold with the BottomNav
        // 'child' is the widget for the currently selected route (e.g., HomeScreen)
        return MainScaffoldShell(child: child);
      },
      routes: <RouteBase>[
        // Routes for each tab within the shell
        GoRoute(
          path: '/home',
          builder: (BuildContext context, GoRouterState state) {
            return const HomeScreenContent(); // We'll refactor HomeScreen soon
          },
        ),
        GoRoute(
          path: '/analysis', // Placeholder
          builder: (BuildContext context, GoRouterState state) {
            return const PlaceholderScreen(title: 'Análisis');
          },
        ),
        GoRoute(
          path: '/history',
          builder: (BuildContext context, GoRouterState state) {
            return const HistoryScreen(); // HistoryScreen might need refactoring too
          },
        ),
          GoRoute(
           path: '/share', // Placeholder for share
           builder: (BuildContext context, GoRouterState state) {
             return const PlaceholderScreen(title: 'Compartir');
           },
         ),
        GoRoute(
          path: '/profile',
          builder: (BuildContext context, GoRouterState state) {
            return const ProfileScreen(); // ProfileScreen might need refactoring
          },
        ),
        
        // --- MOVE DETAIL ROUTES INSIDE SHELLROUTE --- 
        GoRoute(
          path: '/parameter-list/:statusName',
          builder: (BuildContext context, GoRouterState state) {
            final statusName = state.pathParameters['statusName']!;
            final ParameterStatus status = ParameterStatus.values.firstWhere(
                  (e) => e.name == statusName, 
                  orElse: () => ParameterStatus.unknown 
               );
            return ParameterListScreen(
              targetStatus: status, 
            );
          },
        ),
        GoRoute(
          path: '/exam/:examId/:examName/categories',
          builder: (BuildContext context, GoRouterState state) {
            final examId = int.tryParse(state.pathParameters['examId'] ?? '0') ?? 0;
            final examName = state.pathParameters['examName'] ?? 'Examen Desconocido';
            return ExamCategoriesScreen(
              examId: examId,
              examName: examName,
            );
          },
        ),
        GoRoute(
          path: '/exam/:examId/category/:categoryName',
          builder: (BuildContext context, GoRouterState state) {
            final examId = int.tryParse(state.pathParameters['examId'] ?? '0') ?? 0;
            final categoryName = state.pathParameters['categoryName'] ?? 'Categoría Desconocida';
            final examName = state.uri.queryParameters['examName'] ?? 'Examen Desconocido';
            return CategoryParametersScreen(
              examId: examId,
              examName: examName,
              categoryName: categoryName,
            );
          },
        ),
        GoRoute(
          path: '/parameter-detail/:categoryName/:parameterName',
          builder: (BuildContext context, GoRouterState state) {
            final categoryName = Uri.decodeComponent(state.pathParameters['categoryName'] ?? 'Categoría Desconocida');
            final parameterName = Uri.decodeComponent(state.pathParameters['parameterName'] ?? 'Parámetro Desconocido');
            return ParameterDetailScreen(
              categoryName: categoryName,
              parameterName: parameterName, 
            );
          },
        ),
        GoRoute(
          path: '/tracked-parameters',
          builder: (BuildContext context, GoRouterState state) {
            return const TrackedParametersScreen();
          },
          routes: [
             GoRoute(
               path: 'parameter-detail/:categoryName/:parameterName', 
               builder: (BuildContext context, GoRouterState state) {
                 final categoryName = Uri.decodeComponent(state.pathParameters['categoryName'] ?? 'Categoría Desconocida');
                 final parameterName = Uri.decodeComponent(state.pathParameters['parameterName'] ?? 'Parámetro Desconocido');
                 return ParameterDetailScreen(
                   categoryName: categoryName,
                   parameterName: parameterName, 
                 );
               },
             ),
          ]
        ),
        // ----------------------------------------------
      ],
    ),

    // --- REMOVE Top-level routes that were moved --- 
    /*
     GoRoute(
      path: '/parameter-list/:statusName',
       ...
     ),
     GoRoute(
      path: '/exam/:examId/:examName/categories',
       ...
     ),
     GoRoute(
       path: '/exam/:examId/category/:categoryName',
       ...
     ),
     GoRoute(
       path: '/parameter-detail/:categoryName/:parameterName',
       ...
     ),
     GoRoute(
       path: '/tracked-parameters',
       ...
     ),
    */

  ],
); 