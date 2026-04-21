import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/feature/help_support/view/send_feedback_page.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/ui/app_scaffold_actions.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Help & Support'),
        actions: AppScaffoldActions.actions(context),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        children: [
          _SectionTitle(title: 'Quick help'),
          SizedBox(height: 10.h),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FaqTile(
                  q: 'How do I book a token?',
                  a: 'Go to Home → Book Token, select a branch and service, then confirm booking.',
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _FaqTile(
                  q: 'How do I track my queue?',
                  a: 'Go to Home → Track Queue to view your position, ETA and now-serving counters.',
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _FaqTile(
                  q: 'Why am I not receiving notifications?',
                  a: 'Check Settings → Enable notifications. Notifications are local and work offline.',
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                _FaqTile(
                  q: 'Can I cancel a token?',
                  a: 'Yes. Go to My Token and tap Cancel Token. The token will be moved to history.',
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          _SectionTitle(title: 'Contact'),
          SizedBox(height: 10.h),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(label: 'Email', value: 'support@intelliqueue.com'),
                SizedBox(height: 10.h),
                _InfoLine(label: 'Phone', value: '+977-98XXXXXXXX'),
                SizedBox(height: 10.h),
                _InfoLine(label: 'Hours', value: 'Sun–Fri • 10:00 AM – 5:00 PM'),
              ],
            ),
          ),
          SizedBox(height: 18.h),
          SizedBox(
            width: double.infinity,
            height: 52.h,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SendFeedbackPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.headerBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              icon: const Icon(Icons.feedback_outlined),
              label: Text(
                'Send Feedback',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            'Your feedback is saved locally on this device.',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade800,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String q;
  final String a;
  const _FaqTile({required this.q, required this.a});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.q,
                    style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(_open ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade600),
              ],
            ),
            if (_open) ...[
              SizedBox(height: 8.h),
              Text(
                widget.a,
                style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;
  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56.w,
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5.sp, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

