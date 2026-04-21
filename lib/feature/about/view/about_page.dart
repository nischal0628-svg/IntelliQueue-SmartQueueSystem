import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/ui/app_scaffold_actions.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  late Future<PackageInfo> _infoFuture;

  @override
  void initState() {
    super.initState();
    _infoFuture = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('About'),
        actions: AppScaffoldActions.actions(context),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IntelliQueue',
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Offline-first queue and token management app built for a smooth local-device experience.',
                  style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                ),
                SizedBox(height: 14.h),
                FutureBuilder<PackageInfo>(
                  future: _infoFuture,
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version ?? '-';
                    final build = snapshot.data?.buildNumber ?? '-';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoLine(label: 'Version', value: version),
                        SizedBox(height: 8.h),
                        _InfoLine(label: 'Build', value: build),
                      ],
                    );
                  },
                ),
                SizedBox(height: 14.h),
                Divider(height: 1, color: cs.outlineVariant),
                SizedBox(height: 14.h),
                _InfoLine(label: 'Storage', value: 'Local database (offline)'),
                SizedBox(height: 8.h),
                _InfoLine(label: 'Mode', value: 'Works offline (no cloud backend)'),
              ],
            ),
          ),
          SizedBox(height: 14.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Credits',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Final Year Project (AY 2025/2026).',
                  style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Designed and developed as an academic prototype.',
                  style: TextStyle(fontSize: 13.sp, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5.sp,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

