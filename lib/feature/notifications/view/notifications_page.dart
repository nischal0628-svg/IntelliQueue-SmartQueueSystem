import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/feature/my_token/view/my_token_page.dart';
import 'package:intelliqueue/feature/notifications/view/notification_detail_page.dart';
import 'package:intelliqueue/local_auth/local_auth.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/ui/app_scaffold_actions.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _reload();
  }

  Future<List<Map<String, dynamic>>> _reload() async {
    await LocalAuth.syncNotificationsFromBackend();
    return await LocalAuth.listNotificationsForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Notifications'),
        actions: AppScaffoldActions.actions(context),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 22.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'No Notifications',
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Updates about your token will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _itemsFuture = _reload();
              });
              await _itemsFuture;
            },
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade300),
              itemBuilder: (context, index) {
                final item = items[index];
                final id = (item['notificationId'] ?? '').toString();
                final title = (item['title'] ?? '').toString();
                final subtitle = (item['subtitle'] ?? '').toString();
                final createdAt = (item['createdAt'] ?? '').toString();
                final unread = item['isRead'] != true;
                final relatedBookingId = (item['relatedBookingId'] ?? '').toString();

                return InkWell(
                  onTap: () async {
                    await LocalAuth.markNotificationRead(id);
                    if (!context.mounted) return;

                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NotificationDetailPage(notification: item),
                      ),
                    );

                    if (!context.mounted) return;
                    setState(() => _itemsFuture = _reload());
                    if (relatedBookingId.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyTokenPage()),
                      );
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 14.5.sp,
                                  fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                subtitle,
                                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                _timeAgo(createdAt),
                                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        if (unread)
                          Container(
                            margin: EdgeInsets.only(top: 6.h),
                            height: 8.r,
                            width: 8.r,
                            decoration: const BoxDecoration(
                              color: AppColors.headerBlue,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(width: 8),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return iso;
    }
  }
}
