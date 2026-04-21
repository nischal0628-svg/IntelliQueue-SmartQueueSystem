import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/ui/app_colors.dart';

class NotificationDetailPage extends StatelessWidget {
  final Map<String, dynamic> notification;
  const NotificationDetailPage({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final title = (notification['title'] ?? '').toString();
    final subtitle = (notification['subtitle'] ?? '').toString();
    final createdAt = (notification['createdAt'] ?? '').toString();
    final type = (notification['type'] ?? '').toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Notification'),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.isEmpty ? '-' : title,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8.h),
            Text(
              _timeAgo(createdAt),
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
            if (type.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                type,
                style: TextStyle(fontSize: 11.5.sp, color: Colors.grey.shade500),
              ),
            ],
            SizedBox(height: 14.h),
            Divider(height: 1, color: Colors.grey.shade300),
            SizedBox(height: 14.h),
            Text(
              subtitle.isEmpty ? '-' : subtitle,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade800, height: 1.4),
            ),
          ],
        ),
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

