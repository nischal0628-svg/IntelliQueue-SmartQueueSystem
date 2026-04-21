import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/feature/my_token/view/my_token_page.dart';
import 'package:intelliqueue/local_auth/local_auth.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/ui/app_scaffold_actions.dart';

class TokenHistoryPage extends StatefulWidget {
  const TokenHistoryPage({super.key});

  @override
  State<TokenHistoryPage> createState() => _TokenHistoryPageState();
}

class _TokenHistoryPageState extends State<TokenHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    ('All', null),
    ('Active', 'active'),
    ('Completed', 'completed'),
    ('Cancelled', 'cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Token History'),
        actions: AppScaffoldActions.actions(context),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
          tabs: _tabs.map((t) => Tab(text: t.$1)).toList(),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: LocalAuth.bookingsListenable(),
        builder: (context, _, __) {
          return TabBarView(
            controller: _tabController,
            children: _tabs.map((t) {
              return _BookingList(status: t.$2);
            }).toList(),
          );
        },
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final String? status;
  const _BookingList({required this.status});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LocalAuth.listBookingsForCurrentUser(status: status),
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
                    'No Tokens Found',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Your token history will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final b = items[index];
            final bookingId = (b['bookingId'] ?? '').toString();
            final token = (b['tokenNumber'] ?? '').toString();
            final service = (b['serviceName'] ?? '').toString();
            final branch = (b['branchName'] ?? '').toString();
            final status = (b['status'] ?? '').toString();
            final createdAt = (b['createdAt'] ?? '').toString();

            return Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: InkWell(
                borderRadius: BorderRadius.circular(16.r),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MyTokenPage(bookingId: bookingId),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64.w,
                        height: 64.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.headerBlue.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Text(
                          token,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.headerBlue,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              service,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              branch,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                      _StatusPill(status: status),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day/$month/$year • $hour:$min $ampm';
    } catch (_) {
      return iso;
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.isEmpty ? 'unknown' : status;
    final (bg, fg) = switch (normalized) {
      'active' => (const Color(0xFFD4F6E6), const Color(0xFF2DBE78)),
      'completed' => (const Color(0xFFE3F2FF), AppColors.headerBlue),
      'cancelled' => (const Color(0xFFFFD7D7), const Color(0xFFE74C3C)),
      _ => (Colors.grey.shade200, Colors.grey.shade700),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: fg,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

