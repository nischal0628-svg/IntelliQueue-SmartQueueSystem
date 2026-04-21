import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/feature/my_token/view/my_token_page.dart';
import 'package:intelliqueue/local_auth/local_auth.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/ui/app_scaffold_actions.dart';

class BookTokenPage extends StatefulWidget {
  const BookTokenPage({super.key});

  @override
  State<BookTokenPage> createState() => _BookTokenPageState();
}

class _BookTokenPageState extends State<BookTokenPage> {
  String? _selectedBranchId;
  String? _selectedServiceId;
  String _tokenType = 'Normal';

  late Future<List<Map>> _branchesFuture;
  Future<List<Map>>? _servicesFuture;

  bool get _canConfirm => _selectedBranchId != null && _selectedServiceId != null;

  @override
  void initState() {
    super.initState();
    _branchesFuture = LocalAuth.listBranches();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Book Token'),
        actions: AppScaffoldActions.actions(context),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
                children: [
                  Text(
                    'Token Type',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18.r),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        _TypeRow(
                          title: 'Normal',
                          subtitle: 'Standard token',
                          selected: _tokenType == 'Normal',
                          onTap: () => setState(() => _tokenType = 'Normal'),
                        ),
                        Divider(height: 1, color: Colors.grey.shade200),
                        _TypeRow(
                          title: 'VIP',
                          subtitle: 'Priority service',
                          selected: _tokenType == 'VIP',
                          onTap: () => setState(() => _tokenType = 'VIP'),
                        ),
                        Divider(height: 1, color: Colors.grey.shade200),
                        _TypeRow(
                          title: 'Senior Citizen',
                          subtitle: 'Highest priority',
                          selected: _tokenType == 'SeniorCitizen',
                          onTap: () => setState(() => _tokenType = 'SeniorCitizen'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'Select Branch',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  FutureBuilder<List<Map>>(
                    future: _branchesFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 18.h),
                          child: const Center(child: CircularProgressIndicator()),
                        );
                      }
                      final branches = snapshot.data!;
                      if (branches.isEmpty) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 18.h),
                          child: Center(
                            child: Text(
                              'No branches found',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...branches.map((b) {
                            final branchId = (b['branchId'] ?? '').toString();
                            final name = (b['name'] ?? '').toString();
                            final area = (b['area'] ?? '').toString();
                            final distanceKm = b['distanceKm'];
                            final distanceText =
                                distanceKm == null ? '' : '${distanceKm.toString()} km away';
                            final selected = _selectedBranchId == branchId;

                            return Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: _BranchCard(
                                title: name,
                                area: area,
                                distance: distanceText,
                                selected: selected,
                                onTap: () {
                                  setState(() {
                                    _selectedBranchId = branchId;
                                    _selectedServiceId = null;
                                    _servicesFuture =
                                        LocalAuth.listServicesForBranch(branchId);
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Select Service',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  if (_servicesFuture == null)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 18.h),
                      child: Center(
                        child: Text(
                          'Select a branch first',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    )
                  else
                    FutureBuilder<List<Map>>(
                      future: _servicesFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 18.h),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }
                        final services = snapshot.data!;
                        if (services.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 18.h),
                            child: Center(
                              child: Text(
                                'No services found',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: [
                            ...services.map((s) {
                              final serviceId = (s['serviceId'] ?? '').toString();
                              final name = (s['name'] ?? '').toString();
                              final isActive = s['isActive'] == true;
                              final disabledMessage =
                                  (s['isDisabledMessage'] ?? '').toString();
                              final etaMinutes = s['defaultEtaMinutes'];
                              final subtitle = isActive
                                  ? '~${etaMinutes.toString()} mins'
                                  : (disabledMessage.isNotEmpty
                                      ? disabledMessage
                                      : 'Unavailable');
                              final selected = _selectedServiceId == serviceId;

                              return Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: _ServiceCard(
                                  title: name,
                                  subtitle: subtitle,
                                  enabled: isActive,
                                  selected: selected,
                                  onTap: isActive
                                      ? () {
                                          setState(() {
                                            _selectedServiceId = serviceId;
                                          });
                                        }
                                      : null,
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 16.h),
                child: SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: _canConfirm
                        ? () {
                            _confirmBooking();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.headerBlue,
                      disabledBackgroundColor: AppColors.headerBlue.withValues(alpha: 0.35),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Confirm Booking',
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    final branchId = _selectedBranchId;
    final serviceId = _selectedServiceId;
    if (branchId == null || serviceId == null) return;

    final result = await LocalAuth.createBookingForCurrentUser(
      branchId: branchId,
      serviceId: serviceId,
      tokenType: _tokenType,
    );

    if (!mounted) return;

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Booking failed')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking confirmed!')),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MyTokenPage()),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final String title;
  final String area;
  final String distance;
  final bool selected;
  final VoidCallback onTap;

  const _BranchCard({
    required this.title,
    required this.area,
    required this.distance,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? Border.all(color: AppColors.headerBlue, width: 1.4) : null;
    final bg = selected ? AppColors.headerBlue.withValues(alpha: 0.06) : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(18.r),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18.r),
          border: border,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6.h),
            Text(area, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
            SizedBox(height: 3.h),
            Text(distance, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final bool selected;
  final VoidCallback? onTap;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseTextColor = enabled ? Colors.grey.shade900 : Colors.grey.shade400;
    final subTextColor = enabled ? Colors.grey.shade600 : Colors.grey.shade400;
    final border = selected ? Border.all(color: AppColors.headerBlue, width: 1.2) : null;
    final bg = selected ? AppColors.headerBlue.withValues(alpha: 0.06) : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(18.r),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18.r),
          border: border,
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: baseTextColor),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.sp, color: subTextColor),
                  ),
                ],
              ),
            ),
            if (enabled)
              Icon(Icons.chevron_right, color: Colors.grey.shade500)
            else
              const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TypeRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = selected ? AppColors.headerBlue : Colors.grey.shade900;
    final subColor = Colors.grey.shade600;

    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.headerBlue : Colors.grey.shade400,
              size: 20.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: titleColor)),
                  SizedBox(height: 2.h),
                  Text(subtitle, style: TextStyle(fontSize: 12.sp, color: subColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

