import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/feature/book_token/view/book_token_page.dart';
import 'package:intelliqueue/local_auth/local_auth.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/ui/app_scaffold_actions.dart';

class MyTokenPage extends StatefulWidget {
  final String? bookingId;
  const MyTokenPage({super.key, this.bookingId});

  @override
  State<MyTokenPage> createState() => _MyTokenPageState();
}

class _MyTokenPageState extends State<MyTokenPage> {
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    // Best-effort: sync status from backend (so completed tokens disappear).
    LocalAuth.refreshActiveBookingFromBackend();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Token Details'),
        actions: AppScaffoldActions.actions(context),
      ),
      body: ValueListenableBuilder(
        valueListenable: LocalAuth.bookingsListenable(),
        builder: (context, _, __) {
          final booking = widget.bookingId == null
              ? LocalAuth.getActiveBookingForCurrentUserSync()
              : LocalAuth.getBookingByIdSync(widget.bookingId!);
          return _buildBody(context, booking);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic>? booking) {
    if (booking == null) {
      return _EmptyTokenState(
        onBook: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const BookTokenPage()),
          );
        },
      );
    }

    final tokenNumber = (booking['tokenNumber'] ?? '').toString();
    final serviceName = (booking['serviceName'] ?? '').toString();
    final branchName = (booking['branchName'] ?? '').toString();
    final tokenType = (booking['tokenType'] ?? 'Normal').toString();
    final createdAt = (booking['createdAt'] ?? '').toString();
    final position = (booking['position'] ?? 0).toString();
    final queueSize = (booking['queueSize'] ?? 0).toString();
    final peopleAhead = (booking['peopleAhead'] ?? 0).toString();
    final etaMinutes = (booking['estimatedWaitMinutes'] ?? 0).toString();
    final bookingId = (booking['bookingId'] ?? '').toString();
    final status = (booking['status'] ?? '').toString();
    final canCancel = status == 'active' && widget.bookingId == null;

    return ListView(
      padding: EdgeInsets.only(bottom: 22.h),
      children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 22.h),
                decoration: const BoxDecoration(color: AppColors.headerBlue),
                child: Column(
                  children: [
                    SizedBox(height: 10.h),
                    Text(
                      'Your Token Number',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      tokenNumber,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 54.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                child: _CardContainer(
                  child: Column(
                    children: [
                      _InfoRow(label: 'Service', value: serviceName),
                      _InfoRow(label: 'Branch', value: branchName),
                      _InfoRow(label: 'Token Type', value: tokenType),
                      _InfoRow(label: 'Booked At', value: _formatBookedAt(createdAt)),
                      if (widget.bookingId != null)
                        _InfoRow(label: 'Status', value: status.isEmpty ? '-' : status),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7D3B0),
                    borderRadius: BorderRadius.circular(18.r),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Estimated Wait Time',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        '${etaMinutes.padLeft(2, '0')}:00',
                        style: TextStyle(fontSize: 44.sp, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'minutes',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                child: _CardContainer(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Your Position',
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '$position/$queueSize',
                            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '$peopleAhead people ahead of you',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 22.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                child: SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: canCancel
                        ? (_isCancelling ? null : () => _confirmCancel(bookingId))
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF3B30),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 0,
                    ),
                    child: _isCancelling
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            canCancel ? 'Cancel Token' : 'Token ${status.isEmpty ? 'Details' : status}',
                            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
      ],
    );
  }

  Future<void> _confirmCancel(String bookingId) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Token?'),
          content: const Text('Are you sure you want to cancel your token?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30),
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) return;

    setState(() => _isCancelling = true);
    final result = await LocalAuth.cancelActiveBooking(bookingId);
    if (!mounted) return;

    setState(() {
      _isCancelling = false;
    });

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Cancel failed')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token cancelled')),
    );
  }

  String _formatBookedAt(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$min $ampm';
    } catch (_) {
      return iso;
    }
  }
}

class _EmptyTokenState extends StatelessWidget {
  final VoidCallback onBook;
  const _EmptyTokenState({required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Center(
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
              'Book a token to see your queue status here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
            ),
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: onBook,
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
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;
  const _CardContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

