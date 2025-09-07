import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/firebase_service.dart';
import '../../../../core/services/bluetooth_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/attendance_session.dart';

class InstructorDashboardPage extends ConsumerStatefulWidget {
  const InstructorDashboardPage({super.key});

  @override
  ConsumerState<InstructorDashboardPage> createState() => _InstructorDashboardPageState();
}

class _InstructorDashboardPageState extends ConsumerState<InstructorDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final bluetoothState = ref.watch(bluetoothServiceProvider);

    return currentUser.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(child: Text('User not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Instructor Dashboard'),
            actions: [
              // Bluetooth status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: bluetoothState.isEnabled 
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bluetooth,
                      size: 16,
                      color: bluetoothState.isEnabled 
                          ? AppTheme.successColor 
                          : AppTheme.errorColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      bluetoothState.isEnabled ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: bluetoothState.isEnabled 
                            ? AppTheme.successColor 
                            : AppTheme.errorColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'I',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Profile'),
                    onTap: () => context.push('/profile'),
                  ),
                  PopupMenuItem(
                    child: const Text('Settings'),
                    onTap: () {
                      // TODO: Navigate to settings
                    },
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    child: const Text('Sign Out'),
                    onTap: () async {
                      await ref.read(firebaseServiceProvider).signOut();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildDashboardTab(user),
              _buildSessionsTab(user),
              _buildAnalyticsTab(user),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list),
                label: 'Sessions',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics),
                label: 'Analytics',
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/instructor/dashboard/create-session'),
            icon: const Icon(Icons.add),
            label: const Text('New Session'),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildDashboardTab(user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${user.name}!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ready to take attendance?',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick stats
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Today\'s Sessions',
                  '3',
                  Icons.today,
                  AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Students Present',
                  '24/28',
                  Icons.people,
                  AppTheme.successColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Attendance Rate',
                  '85.7%',
                  Icons.trending_up,
                  AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Flagged Records',
                  '2',
                  Icons.flag,
                  AppTheme.errorColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Quick actions
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildActionCard(
                'Start Session',
                Icons.play_arrow,
                AppTheme.successColor,
                () => context.push('/instructor/dashboard/create-session'),
              ),
              _buildActionCard(
                'View Sessions',
                Icons.list,
                AppTheme.primaryColor,
                () => setState(() => _selectedIndex = 1),
              ),
              _buildActionCard(
                'Scan Students',
                Icons.bluetooth_searching,
                AppTheme.warningColor,
                () => _startBluetoothScan(),
              ),
              _buildActionCard(
                'Reports',
                Icons.analytics,
                AppTheme.secondaryColor,
                () => setState(() => _selectedIndex = 2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab(user) {
    return StreamBuilder<List<AttendanceSession>>(
      stream: ref.read(firebaseServiceProvider).getInstructorSessionsStream(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final sessions = snapshot.data ?? [];

        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No sessions yet',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first attendance session',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return _buildSessionCard(session);
          },
        );
      },
    );
  }

  Widget _buildAnalyticsTab(user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics & Reports',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Analytics cards
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This Week\'s Overview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // TODO: Add charts and analytics
                  const Text('Analytics charts coming soon...'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(AttendanceSession session) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(session.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getStatusIcon(session.status),
            color: _getStatusColor(session.status),
            size: 20,
          ),
        ),
        title: Text(
          session.className,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${session.subject} • ${_formatDateTime(session.startTime)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${session.attendanceRecords.length} students',
              style: const TextStyle(fontSize: 12),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push('/instructor/dashboard/session/${session.id}'),
      ),
    );
  }

  Color _getStatusColor(SessionStatus status) {
    switch (status) {
      case SessionStatus.active:
        return AppTheme.successColor;
      case SessionStatus.completed:
        return AppTheme.primaryColor;
      case SessionStatus.cancelled:
        return AppTheme.errorColor;
      case SessionStatus.created:
        return AppTheme.warningColor;
    }
  }

  IconData _getStatusIcon(SessionStatus status) {
    switch (status) {
      case SessionStatus.active:
        return Icons.play_circle_filled;
      case SessionStatus.completed:
        return Icons.check_circle;
      case SessionStatus.cancelled:
        return Icons.cancel;
      case SessionStatus.created:
        return Icons.schedule;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _startBluetoothScan() {
    final bluetoothService = ref.read(bluetoothServiceProvider.notifier);
    bluetoothService.startScanning(timeout: const Duration(minutes: 2));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Scanning for student devices...'),
        action: SnackBarAction(
          label: 'Stop',
          onPressed: () => bluetoothService.stopScanning(),
        ),
      ),
    );
  }
}