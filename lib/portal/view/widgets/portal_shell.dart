import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/data/portal_session_store.dart';
import 'package:intelliqueue/portal/view/portal_gate.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/portal/view/admin/admin_dashboard_page.dart';
import 'package:intelliqueue/portal/view/admin/manage_queues_page.dart';
import 'package:intelliqueue/portal/view/admin/manage_services_page.dart';
import 'package:intelliqueue/portal/view/admin/manage_staff_page.dart';
import 'package:intelliqueue/portal/view/admin/analytics_page.dart';
import 'package:intelliqueue/portal/view/admin/manage_customers_page.dart';
import 'package:intelliqueue/portal/view/staff/staff_dashboard_page.dart';
import 'package:intelliqueue/portal/view/staff/queue_management_page.dart';
import 'package:intelliqueue/portal/view/staff/counter_assignment_page.dart';
import 'package:intelliqueue/portal/view/staff/token_list_page.dart';
import 'package:intelliqueue/portal/view/staff/send_notification_page.dart';

enum PortalNavItem {
  dashboard('Dashboard', Icons.dashboard_outlined),
  // Staff items
  queueManagement('Queue Management', Icons.queue_outlined),
  tokenList('Token list', Icons.list_alt_outlined),
  counterAssignment('Counter Assignment', Icons.grid_view_outlined),
  sendNotification('Send Notification', Icons.notifications_active_outlined),

  // Admin items
  manageQueues('Manage Queues', Icons.table_chart_outlined),
  manageServices('Manage Services', Icons.design_services_outlined),
  manageStaff('Manage Staff', Icons.people_alt_outlined),
  manageCustomers('Manage Customers', Icons.person_outline),
  analytics('Analytics', Icons.insights_outlined);

  final String label;
  final IconData icon;
  const PortalNavItem(this.label, this.icon);
}

class PortalShell extends StatelessWidget {
  final PortalSession session;
  final String title;
  final PortalNavItem active;
  final Widget child;

  const PortalShell({
    super.key,
    required this.session,
    required this.title,
    required this.active,
    required this.child,
  });

  Future<void> _logout(BuildContext context) async {
    await PortalSessionStore.clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PortalGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = session.isAdmin
        ? const [
            PortalNavItem.dashboard,
            PortalNavItem.manageQueues,
            PortalNavItem.manageServices,
            PortalNavItem.manageStaff,
            PortalNavItem.manageCustomers,
            PortalNavItem.analytics,
          ]
        : const [
            PortalNavItem.dashboard,
            PortalNavItem.queueManagement,
            PortalNavItem.tokenList,
            PortalNavItem.counterAssignment,
            PortalNavItem.sendNotification,
          ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 270,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('IQ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('IntelliQueue', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            session.isAdmin ? 'admin panel' : 'staff portal',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      for (final item in navItems)
                        _NavButton(
                          item: item,
                          active: item == active,
                          onTap: () {
                            if (item == active) return;
                            final Widget target;

                            if (session.isAdmin) {
                              target = switch (item) {
                                PortalNavItem.dashboard => AdminDashboardPage(session: session),
                                PortalNavItem.manageQueues => ManageQueuesPage(session: session),
                                PortalNavItem.manageServices => ManageServicesPage(session: session),
                                PortalNavItem.manageStaff => ManageStaffPage(session: session),
                                PortalNavItem.manageCustomers => ManageCustomersPage(session: session),
                                PortalNavItem.analytics => AnalyticsPage(session: session),
                                _ => AdminDashboardPage(session: session),
                              };
                            } else {
                              target = switch (item) {
                                PortalNavItem.dashboard => StaffDashboardPage(session: session),
                                PortalNavItem.queueManagement => QueueManagementPage(session: session),
                                PortalNavItem.tokenList => TokenListPage(session: session),
                                PortalNavItem.counterAssignment => CounterAssignmentPage(session: session),
                                PortalNavItem.sendNotification => SendNotificationPage(session: session),
                                _ => StaffDashboardPage(session: session),
                              };
                            }

                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => target),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFFE5E5),
                        foregroundColor: const Color(0xFFE74C3C),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _logout(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content area
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 70,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            session.isAdmin
                                ? 'Admin'
                                : ((session.assignedCounterName?.isNotEmpty ?? false)
                                    ? session.assignedCounterName!
                                    : 'Staff'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            session.isAdmin
                                ? session.email
                                : ('Staff: ${session.name}${(session.assignedServiceName?.isNotEmpty ?? false) ? ' • ${session.assignedServiceName}' : ''}'),
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final PortalNavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.primaryBlue : const Color(0xFFF1F2F4);
    final fg = active ? Colors.white : const Color(0xFF111827);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(item.icon, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

