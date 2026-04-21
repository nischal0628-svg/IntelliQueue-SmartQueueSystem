import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/feature/book_token/view/book_token_page.dart';
import 'package:intelliqueue/feature/login/view/login_page.dart'; // Adjust path if needed
import 'package:intelliqueue/feature/my_token/view/my_token_page.dart';
import 'package:intelliqueue/feature/track_queue/view/track_queue_page.dart';
import 'package:intelliqueue/local_auth/local_auth.dart';
import 'package:intelliqueue/ui/app_nav.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Best-effort: keep token status synced with backend (so completed tokens disappear).
    LocalAuth.refreshActiveBookingFromBackend();
  }

  Future<void> _logout() async {
    await LocalAuth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ================= HEADER =================
            Container(
              width: double.infinity,
              height: 260.h,
              decoration: const BoxDecoration(
                color: Color(0xFF2F80ED), // Blue header
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 50.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row (time icons skipped, notification at right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: () => AppNav.openNotifications(context),
                          icon: Icon(
                            Icons.notifications_none,
                            color: Colors.white,
                            size: 28.sp,
                          ),
                        ),
                        IconButton(
                          onPressed: () => AppNav.openProfile(context),
                          icon: Icon(
                            Icons.person_outline,
                            color: Colors.white,
                            size: 28.sp,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      "Hello, Welcome!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20.h),

            // ================= CURRENT TOKEN CARD =================
            ValueListenableBuilder(
              valueListenable: LocalAuth.bookingsListenable(),
              builder: (context, _, __) {
                final booking = LocalAuth.getActiveBookingForCurrentUserSync();
                final tokenNumber = (booking?['tokenNumber'] ?? '-').toString();
                final serviceName = (booking?['serviceName'] ?? 'No active token').toString();
                final branchName = (booking?['branchName'] ?? '').toString();
                final status = (booking?['status'] ?? '').toString();
                final isActive = booking != null && status == 'active';
                final peopleAhead = (booking?['peopleAhead'] as int?) ?? 0;
                final etaMinutes = (booking?['estimatedWaitMinutes'] as int?) ?? 0;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22.w),
                  child: Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Current Token",
                              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFFD4F6E6) : const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Text(
                                isActive ? "active" : "none",
                                style: TextStyle(
                                  color: isActive ? const Color(0xFF2DBE78) : const Color(0xFF6B7280),
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          isActive ? tokenNumber : "--",
                          style: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          isActive
                              ? "$serviceName${branchName.isEmpty ? '' : ' - $branchName'}"
                              : "You don’t have an active token",
                          style: TextStyle(fontSize: 15.sp, color: Colors.grey[700]),
                        ),
                        SizedBox(height: 12.h),
                        Divider(color: Colors.grey[300]),
                        SizedBox(height: 12.h),
                        if (isActive)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "People ahead",
                                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                                  ),
                                  SizedBox(height: 5.h),
                                  Text(
                                    "$peopleAhead",
                                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Est. wait time",
                                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                                  ),
                                  SizedBox(height: 5.h),
                                  Text(
                                    "$etaMinutes min",
                                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 44.h,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const BookTokenPage()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2F80ED),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                              ),
                              child: Text(
                                "Book Token",
                                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 25.h),

            // ================= MENU CARDS =================
            _buildMenuCard(
              title: "Book Token",
              subtitle: "Join a queue",
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BookTokenPage()),
                );
              },
            ),

            _buildMenuCard(
              title: "My Token",
              subtitle: "View active tokens",
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyTokenPage()),
                );
              },
            ),

            _buildMenuCard(
              title: "Track Queue",
              subtitle: "Real-time status",
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TrackQueuePage()),
                );
              },
            ),

            SizedBox(height: 30.h),

            // ================= LOGOUT BUTTON =================
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 22.w),
              child: SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE74C3C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15.r),
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    "Logout",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 30.h),
          ],
        ),
      ),
    );
  }

  // ============ MENU CARD WIDGET ============
  Widget _buildMenuCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(20.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[600],
                size: 18.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
