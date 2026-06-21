import 'package:flutter/material.dart';
import '../../services/notification_service.dart';
import '../../theme/design_system.dart';

class NotificationCenterSheet extends StatelessWidget {
  const NotificationCenterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? DesignSystem.backgroundDark : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(DesignSystem.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: DesignSystem.md),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Inbox & Alerts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      await NotificationService.markAllAsRead();
                    },
                    child: const Text('Mark all read', style: TextStyle(fontSize: 12, color: DesignSystem.primary)),
                  ),
                  TextButton(
                    onPressed: () async {
                      await NotificationService.clearNotifications();
                    },
                    child: const Text('Clear', style: TextStyle(fontSize: 12, color: DesignSystem.error)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: DesignSystem.sm),

          // Notification List
          Flexible(
            child: StreamBuilder<List<AppNotification>>(
              stream: NotificationService.notificationsStream,
              initialData: const [],
              builder: (context, snapshot) {
                final notifs = snapshot.data ?? [];
                if (notifs.isEmpty) {
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 48, color: isDark ? Colors.white24 : Colors.grey),
                          const SizedBox(height: DesignSystem.sm),
                          const Text('All caught up!', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifs.length,
                  itemBuilder: (context, index) {
                    final notif = notifs[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: _getNotifColor(notif.type).withValues(alpha: 0.1),
                        child: Icon(_getNotifIcon(notif.type), color: _getNotifColor(notif.type), size: 20),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (!notif.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: DesignSystem.primary, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          notif.body,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getNotifIcon(String type) {
    switch (type) {
      case 'milestone':
        return Icons.emoji_events_outlined;
      case 'tax':
        return Icons.percent_outlined;
      case 'report':
        return Icons.summarize_outlined;
      case 'income':
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  Color _getNotifColor(String type) {
    switch (type) {
      case 'milestone':
        return DesignSystem.success;
      case 'tax':
        return DesignSystem.warning;
      case 'report':
        return DesignSystem.primary;
      default:
        return DesignSystem.primary;
    }
  }
}
