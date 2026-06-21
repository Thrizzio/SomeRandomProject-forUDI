import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../analytics/analytics_screen.dart';
import '../transactions/transaction_center_screen.dart';
import '../tax/tax_dashboard_screen.dart';
import '../settings/settings_center_screen.dart';
import '../../services/notification_service.dart';
import '../../widgets/notification_center_sheet.dart';
import '../../theme/design_system.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  bool _isDark = true;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const AnalyticsScreen(),
    const TransactionCenterScreen(),
    const TaxDashboardScreen(),
    const SettingsCenterScreen(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final initials = _getInitials(user?.email ?? '');

    return Scaffold(
      backgroundColor: _isDark ? DesignSystem.backgroundDark : DesignSystem.backgroundLight,
      appBar: AppBar(
        backgroundColor: _isDark ? DesignSystem.backgroundDark : Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: DesignSystem.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'GigTax',
              style: TextStyle(
                color: _isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Notification Bell with Badge
          StreamBuilder<List<AppNotification>>(
            stream: NotificationService.notificationsStream,
            initialData: const [],
            builder: (context, snapshot) {
              final notifs = snapshot.data ?? [];
              final unreadCount = notifs.where((n) => !n.isRead).length;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none_outlined, color: _isDark ? Colors.white70 : Colors.black87),
                    onPressed: () {
                      _showNotifications();
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: DesignSystem.error, shape: BoxShape.circle),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // User Profile Initials Circle
          Padding(
            padding: const EdgeInsets.only(right: DesignSystem.md),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: DesignSystem.primary.withValues(alpha: 0.15),
              child: Text(
                initials,
                style: const TextStyle(
                  color: DesignSystem.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: _isDark ? Colors.white10 : Colors.grey.shade200,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: _isDark ? DesignSystem.backgroundDark : Colors.white,
          selectedItemColor: DesignSystem.primary,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'Analytics'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Receipts'),
            BottomNavigationBarItem(icon: Icon(Icons.percent_outlined), activeIcon: Icon(Icons.percent), label: 'Tax'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const NotificationCenterSheet();
      },
    );
  }

  String _getInitials(String email) {
    if (email.isEmpty) return 'GT';
    final parts = email.split('@')[0].split('.');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return email[0].toUpperCase();
  }
}
