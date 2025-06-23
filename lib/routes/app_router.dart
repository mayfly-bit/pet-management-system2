import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/main/app_shell.dart';
import '../screens/dogs/dogs_list_screen.dart';
import '../screens/dogs/dog_detail_screen.dart';
import '../screens/dogs/dog_form_screen.dart';
import '../screens/dogs/sale_record_screen.dart';
import '../screens/expenses/expenses_list_screen.dart';
import '../screens/expenses/add_expense_screen.dart';
import '../screens/main/dashboard_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/profile_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/splash/splash_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isAuthenticated = authProvider.isAuthenticated;
      final isInitialized = authProvider.isInitialized;
      
      // Show splash screen while initializing
      if (!isInitialized) {
        return '/splash';
      }
      
      // Redirect to login if not authenticated and trying to access protected routes
      if (!isAuthenticated && !_isPublicRoute(state.uri.path)) {
        return '/login';
      }
      
      // Redirect to main screen if authenticated and trying to access auth routes
      if (isAuthenticated && _isAuthRoute(state.uri.path)) {
        return '/main';
      }
      
      return null; // No redirect needed
    },
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Authentication Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      
      // Main App Routes
      ShellRoute(
        builder: (context, state, child) => AppShell(
          location: state.uri.path,
          child: child,
        ),
        routes: [
          // Dashboard
          GoRoute(
            path: '/main',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          
          // Dogs
          GoRoute(
            path: '/dogs',
            builder: (context, state) => const DogsListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const DogFormScreen(),
              ),
              GoRoute(
                path: 'sale',
                builder: (context, state) => const SaleRecordScreen(),
              ),
              GoRoute(
                path: ':dogId',
                builder: (context, state) {
                  final dogId = state.pathParameters['dogId']!;
                  return DogDetailScreen(dogId: dogId);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) {
                      final dogId = state.pathParameters['dogId']!;
                      return DogFormScreen(dogId: dogId);
                    },
                  ),
                ],
              ),
            ],
          ),
          
          // Expenses
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) {
                  final dogId = state.uri.queryParameters['dogId'];
                  return AddExpenseScreen(preselectedDogId: dogId);
                },
              ),
            ],
          ),
          
          // Reports
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          
          // Settings
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('页面未找到'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              '页面未找到',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '请求的页面不存在',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/main'),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
  
  static bool _isPublicRoute(String location) {
    const publicRoutes = [
      '/login',
      '/register',
      '/forgot-password',
      '/splash',
    ];
    return publicRoutes.contains(location);
  }
  
  static bool _isAuthRoute(String location) {
    const authRoutes = [
      '/login',
      '/register',
      '/forgot-password',
    ];
    return authRoutes.contains(location);
  }
}

// Route names for easy navigation
class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String main = '/main';
  static const String dashboard = '/dashboard';
  static const String dogs = '/dogs';
  static const String addDog = '/dogs/add';
  static const String recordSale = '/dogs/sale';
  static const String expenses = '/expenses';
  static const String addExpense = '/expenses/add';
  static const String reports = '/reports';
  static const String settings = '/settings';
  static const String profile = '/settings/profile';
  
  static String dogDetail(String dogId) => '/dogs/$dogId';
  static String editDog(String dogId) => '/dogs/$dogId/edit';
  static String addExpenseForDog(String dogId) => '/expenses/add?dogId=$dogId';
}