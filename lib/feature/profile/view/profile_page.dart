import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/feature/about/view/about_page.dart';
import 'package:intelliqueue/feature/help_support/view/help_support_page.dart';
import 'package:intelliqueue/feature/login/view/login_page.dart';
import 'package:intelliqueue/feature/profile/view/edit_profile_page.dart';
import 'package:intelliqueue/feature/settings/view/settings_page.dart';
import 'package:intelliqueue/feature/token_history/view/token_history_page.dart';
import 'package:intelliqueue/local_auth/local_auth.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/ui/app_scaffold_actions.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder(
      valueListenable: LocalAuth.usersListenable(),
      builder: (context, _, __) {
        final user = LocalAuth.currentUser();
        final name = (user?['name'] as String?)?.trim().isNotEmpty == true
            ? (user?['name'] as String)
            : 'User';
        final email = (user?['email'] as String?)?.trim().isNotEmpty == true
            ? (user?['email'] as String)
            : 'user@example.com';

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: AppColors.headerBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Profile'),
            actions: AppScaffoldActions.actions(context),
          ),
          body: ListView(
            padding: EdgeInsets.only(bottom: 18.h),
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 28.h),
                decoration: const BoxDecoration(color: AppColors.headerBlue),
                child: Column(
                  children: [
                    Container(
                      height: 90.r,
                      width: 90.r,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6E6E6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                child: Column(
                  children: [
                    _MenuCard(
                      title: 'Edit Profile',
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EditProfilePage()),
                        );
                      },
                    ),
                SizedBox(height: 12.h),
                _MenuCard(
                  title: 'My Token History',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TokenHistoryPage()),
                    );
                  },
                ),
                SizedBox(height: 12.h),
                _MenuCard(
                  title: 'Settings',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                ),
                SizedBox(height: 12.h),
                _MenuCard(
                  title: 'Help and Support',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpSupportPage()),
                    );
                  },
                ),
                SizedBox(height: 12.h),
                _MenuCard(
                  title: 'About',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutPage()),
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 18.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w),
            child: SizedBox(
              width: double.infinity,
              height: 54.h,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await LocalAuth.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (_) => false,
                    );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD7D7),
                  foregroundColor: const Color(0xFFE74C3C),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: Text(
                  'Logout',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
            ],
          ),
        );
      },
    );
  }

  // Placeholder navigation removed (unused).
}

class _MenuCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _MenuCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14.5.sp, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

