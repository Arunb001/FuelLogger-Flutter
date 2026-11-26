import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/garage_provider.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/update_dialog.dart';
import '../calculations/calculations_view.dart';
import '../home/home_view.dart';
import '../logs/logs_view.dart';
import '../notifications/notifications_view.dart';
import '../service/service_logs_view.dart';
import '../upload/upload_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  StreamSubscription<String?>? _notifSub;

  @override
  void initState() {
    super.initState();
    _notifSub =
        NotificationService.onNotificationTap.listen(_handleNotificationPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      context.read<GarageProvider>().loadGarage();
      UpdateDialog.checkAndShow(context);
      await NotificationService.requestPermissionIfNeeded();
      await NotificationService.maybeSendWelcome();
      final pending = NotificationService.consumePendingInitialPayload();
      if (pending != null && mounted) {
        _handleNotificationPayload(pending);
      }
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  void _handleNotificationPayload(String? payload) {
    if (!mounted || payload == null) return;
    switch (payload) {
      case 'service':
        _selectTab(2);
        break;
      case 'upload':
        _openLogFillUp();
        break;
      case 'logs':
        _selectTab(1);
        break;
      case 'insights':
        _selectTab(3);
        break;
      case 'notifications':
        _openNotifications();
        break;
      case 'home':
        _selectTab(0);
        break;
    }
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NotificationsView(onNavigatePayload: _handleNotificationPayload),
      ),
    );
  }

  void _selectTab(int idx) {
    if (_currentIndex == idx) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = idx);
  }

  Future<void> _openLogFillUp() async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UploadView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final pages = [
      HomeView(
        onSwitchTab: _selectTab,
        onLogTap: _openLogFillUp,
        onOpenNotifications: _openNotifications,
      ),
      const LogsView(),
      const ServiceLogsView(),
      const CalculationsView(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: c.navBarBg,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _selectTab,
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: FloatingActionButton.extended(
                      elevation: 0,
                      backgroundColor: c.accentPrimary,
                      foregroundColor: Colors.white,
                      onPressed: _openLogFillUp,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Log'),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Logs'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.build_outlined),
                      selectedIcon: Icon(Icons.build_rounded),
                      label: Text('Service'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights_rounded),
                      label: Text('Insights'),
                    ),
                  ],
                ),
                VerticalDivider(width: 1, color: c.subtleBorder),
                Expanded(
                  child: IndexedStack(index: _currentIndex, children: pages),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: pages),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: c.navBarBg,
              border: Border(
                top: BorderSide(color: c.subtleBorder.withOpacity(0.75), width: 0.8),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      selected: _currentIndex == 0,
                      onTap: () => _selectTab(0),
                    ),
                    _NavItem(
                      icon: Icons.receipt_long_outlined,
                      activeIcon: Icons.receipt_long_rounded,
                      label: 'Logs',
                      selected: _currentIndex == 1,
                      onTap: () => _selectTab(1),
                    ),
                    GestureDetector(
                      onTap: _openLogFillUp,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: c.accentPrimary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: c.accentPrimary.withOpacity(0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 4),
                            Text(
                              'Log',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _NavItem(
                      icon: Icons.build_outlined,
                      activeIcon: Icons.build_rounded,
                      label: 'Service',
                      selected: _currentIndex == 2,
                      onTap: () => _selectTab(2),
                    ),
                    _NavItem(
                      icon: Icons.insights_outlined,
                      activeIcon: Icons.insights_rounded,
                      label: 'Insights',
                      selected: _currentIndex == 3,
                      onTap: () => _selectTab(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final color = selected ? c.accentPrimary : c.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
