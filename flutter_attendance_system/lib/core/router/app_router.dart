import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/firebase_service.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/role_selection_page.dart';
import '../../features/instructor/presentation/pages/instructor_dashboard_page.dart';
import '../../features/instructor/presentation/pages/create_session_page.dart';
import '../../features/instructor/presentation/pages/session_monitor_page.dart';
import '../../features/student/presentation/pages/student_dashboard_page.dart';
import '../../features/student/presentation/pages/join_session_page.dart';
import '../../features/shared/presentation/pages/splash_page.dart';
import '../../features/shared/presentation/pages/profile_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.asData?.value != null;
      final isLoggingIn = state.matchedLocation == '/login' || 
                         state.matchedLocation == '/register' ||
                         state.matchedLocation == '/role-selection';
      
      // Show splash while loading
      if (authState.isLoading) {
        return '/splash';
      }
      
      // Redirect to login if not authenticated
      if (!isLoggedIn && !isLoggingIn && state.matchedLocation != '/splash') {
        return '/login';
      }
      
      // Redirect to dashboard if already logged in and trying to access auth pages
      if (isLoggedIn && isLoggingIn) {
        return '/dashboard';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/role-selection',
        name: 'role-selection',
        builder: (context, state) => const RoleSelectionPage(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      // Instructor Routes
      GoRoute(
        path: '/instructor/dashboard',
        name: 'instructor-dashboard',
        builder: (context, state) => const InstructorDashboardPage(),
        routes: [
          GoRoute(
            path: 'create-session',
            name: 'create-session',
            builder: (context, state) => const CreateSessionPage(),
          ),
          GoRoute(
            path: 'session/:sessionId',
            name: 'session-monitor',
            builder: (context, state) {
              final sessionId = state.pathParameters['sessionId']!;
              return SessionMonitorPage(sessionId: sessionId);
            },
          ),
        ],
      ),
      // Student Routes
      GoRoute(
        path: '/student/dashboard',
        name: 'student-dashboard',
        builder: (context, state) => const StudentDashboardPage(),
        routes: [
          GoRoute(
            path: 'join-session',
            name: 'join-session',
            builder: (context, state) => const JoinSessionPage(),
          ),
        ],
      ),
      // Shared Routes
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'The page "${state.matchedLocation}" could not be found.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),
  );
});

// Dashboard router that redirects based on user role
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    return currentUser.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(
              child: Text('User data not available'),
            ),
          );
        }
        
        // Redirect based on user role
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (user.role.isInstructor) {
            context.go('/instructor/dashboard');
          } else if (user.role.isStudent) {
            context.go('/student/dashboard');
          } else {
            context.go('/login');
          }
        });
        
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading user data',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}