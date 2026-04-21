import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/view/widgets/portal_shell.dart';

class PlaceholderAdminPage extends StatelessWidget {
  final PortalSession session;
  final String title;
  final PortalNavItem active;

  const PlaceholderAdminPage({
    super.key,
    required this.session,
    required this.title,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      session: session,
      title: title,
      active: active,
      child: Center(
        child: Text(
          '$title (will be implemented in next phases)',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

