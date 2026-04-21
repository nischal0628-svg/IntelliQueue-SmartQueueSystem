import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/feature/book_token/view/book_token_page.dart';
import 'package:intelliqueue/local_auth/local_auth.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/ui/app_scaffold_actions.dart';

class TrackQueuePage extends StatefulWidget {
  const TrackQueuePage({super.key});

  @override
  State<TrackQueuePage> createState() => _TrackQueuePageState();
}

class _TrackQueuePageState extends State<TrackQueuePage> {
  @override
  void initState() {
    super.initState();
    // Best-effort: sync status from backend.
    LocalAuth.refreshActiveBookingFromBackend();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LocalAuth.bookingsListenable(),
      builder: (context, _, __) {
        final booking = LocalAuth.getActiveBookingForCurrentUserSync();
        if (booking == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.headerBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('Queue Status'),
              actions: AppScaffoldActions.actions(context),
            ),
            body: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 22.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'No Active Token',
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Book a token to track the queue here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
                    ),
                    SizedBox(height: 18.h),
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const BookTokenPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.headerBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Book Token',
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final branchId = (booking['branchId'] ?? '').toString();
        final serviceId = (booking['serviceId'] ?? '').toString();

        return ValueListenableBuilder(
          valueListenable: LocalAuth.queueStateListenable(),
          builder: (context, _, __) {
            final queue = LocalAuth.getQueueStateSync(branchId: branchId, serviceId: serviceId);
            final nowServingRaw = (queue['nowServing'] is List) ? (queue['nowServing'] as List) : <dynamic>[];
            final nowServing = nowServingRaw
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();

            final waitingCount = (queue['waitingCount'] as int?) ?? 0;
            final avgWait = (queue['avgWaitMinutes'] as int?) ??
                (booking['estimatedWaitMinutes'] as int?) ??
                0;

            final token = (booking['tokenNumber'] ?? '').toString();
            final position = (booking['position'] ?? '').toString();
            final eta = (booking['estimatedWaitMinutes'] ?? 0).toString();

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                backgroundColor: AppColors.headerBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                title: const Text('Queue Status'),
                actions: AppScaffoldActions.actions(context),
              ),
              body: ListView(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
                children: [
                  _YourTokenCard(
                    token: token,
                    position: position,
                    eta: eta == '0' ? 'Now' : '$eta min',
                  ),
                  SizedBox(height: 18.h),
                  Text(
                    'Now Serving',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  if (nowServing.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      child: Center(
                        child: Text(
                          'No counters active yet',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    )
                  else
                    ...nowServing.map((e) {
                      final t = (e['tokenNumber'] ?? '').toString();
                      final c = (e['counterName'] ?? '').toString();
                      return Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: _ServingRow(token: t, counter: c),
                      );
                    }),
                  SizedBox(height: 18.h),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          title: 'Total Waiting',
                          value: waitingCount.toString(),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _StatTile(
                          title: 'Avg. Wait',
                          value: '$avgWait mins',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _YourTokenCard extends StatelessWidget {
  final String token;
  final String position;
  final String eta;

  const _YourTokenCard({
    required this.token,
    required this.position,
    required this.eta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: AppColors.headerBlue,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Token',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            token,
            style: TextStyle(
              color: Colors.white,
              fontSize: 44.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _SmallMetric(
                  label: 'Position',
                  value: position,
                ),
              ),
              Expanded(
                child: _SmallMetric(
                  label: 'Est. wait time',
                  value: eta,
                  alignRight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool alignRight;

  const _SmallMetric({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final align = alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 3.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ServingRow extends StatelessWidget {
  final String token;
  final String counter;

  const _ServingRow({required this.token, required this.counter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Text(
            token,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            counter,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;

  const _StatTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 10.h),
          Text(
            value,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

