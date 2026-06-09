import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../presentation/providers/notification_provider.dart';
import '../../app/app.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with RouteAware {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData();
  }

  void _loadData() {
    context.read<NotificationProvider>().loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnread = notifications.any((n) => !n.isRead);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () => provider.markAllAsRead(),
              child: const Text('Mark All Read'),
            ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.notifications_none, size: 64, color: AppColors.grey400),
                    const SizedBox(height: 16),
                    Text('No notifications', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.grey500)),
                    const SizedBox(height: 8),
                    Text('Notifications will appear here', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.grey400)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: () => provider.loadNotifications(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (ctx, index) {
                      final notif = notifications[index];
                      return RepaintBoundary(child: Dismissible(
                        key: ValueKey(notif.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        onDismissed: (_) => provider.deleteNotification(notif.id),
                        child: GestureDetector(
                          onTap: () {
                            if (!notif.isRead) provider.markAsRead(notif.id);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: notif.isRead ? Theme.of(context).cardColor : (isDark ? AppColors.darkCard : AppColors.primary.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: notif.isRead ? (isDark ? AppColors.grey800 : AppColors.grey100) : AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: _getColor(notif.type).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Icon(_getIcon(notif.type), color: _getColor(notif.type), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(notif.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: notif.isRead ? FontWeight.normal : FontWeight.w600)),
                                  if (!notif.isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                                ]),
                                const SizedBox(height: 4),
                                Text(notif.message, style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 4),
                                Text(DateFormat('MMM dd, h:mm a').format(notif.createdAt), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.grey400)),
                              ])),
                            ]),
                          ),
                        ),
                      ));
                    },
                  ),
                ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'budget_warning': return Icons.warning_amber;
      case 'goal_reminder': return Icons.flag;
      case 'weekly_summary': return Icons.summarize;
      case 'saving_suggestion': return Icons.lightbulb;
      case 'achievement': return Icons.check_circle;
      default: return Icons.notifications_outlined;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'budget_warning': return AppColors.warning;
      case 'goal_reminder': return AppColors.primary;
      case 'weekly_summary': return AppColors.success;
      case 'saving_suggestion': return AppColors.secondary;
      case 'achievement': return AppColors.success;
      default: return AppColors.grey500;
    }
  }
}
