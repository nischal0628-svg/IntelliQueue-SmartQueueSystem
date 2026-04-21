import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session_store.dart';
import 'package:intelliqueue/portal/view/portal_login_page.dart';
import 'package:intelliqueue/portal/view/admin/admin_dashboard_page.dart';
import 'package:intelliqueue/portal/view/staff/staff_dashboard_page.dart';

class PortalGate extends StatelessWidget {
  const PortalGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: PortalSessionStore.read(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data;
        if (session == null) return const PortalLoginPage();
        if (session.isAdmin) return AdminDashboardPage(session: session);
        return StaffDashboardPage(session: session);
      },
    );
  }
}

