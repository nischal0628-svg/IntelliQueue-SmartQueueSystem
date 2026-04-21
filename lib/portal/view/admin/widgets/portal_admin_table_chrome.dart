import 'package:flutter/material.dart';
import 'package:intelliqueue/ui/app_colors.dart';

/// Shared chrome for admin portal list pages (Manage Queues / Services / Staff / Customers).
class PortalAdminTableChrome {
  PortalAdminTableChrome._();

  static const Color actionRed = Color(0xFFE53935);
  static const Color headerBg = Color(0xFFF3F4F6);

  static BoxDecoration cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static ButtonStyle primaryButtonStyle() => FilledButton.styleFrom(
        backgroundColor: AppColors.headerBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      );

  /// Horizontal scroll + explicit height so inner [Column] + [Expanded] + [ListView] lay out.
  static Widget boundedHorizontalTable({
    required double minTableWidth,
    required double height,
    required Widget header,
    required Widget body,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: minTableWidth,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  static double tableMinWidth(BoxConstraints constraints) =>
      constraints.maxWidth < 720 ? 720.0 : constraints.maxWidth;

  static double tableHeight(BoxConstraints constraints) =>
      constraints.maxHeight.isFinite ? constraints.maxHeight : 400.0;
}

class PortalAdminActivePill extends StatelessWidget {
  final bool active;

  const PortalAdminActivePill({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final label = active ? 'Active' : 'InActive';
    if (active) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Active',
          style: TextStyle(
            color: Color(0xFF047857),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class PortalAdminStaffStatusPill extends StatelessWidget {
  final String status;

  const PortalAdminStaffStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.trim().toLowerCase();
    final (Color bg, Color fg, String label) = switch (s) {
      'active' => (const Color(0xFFD1FAE5), const Color(0xFF047857), 'Active'),
      'break' => (const Color(0xFFFEF3C7), const Color(0xFFB45309), 'On Break'),
      _ => (const Color(0xFFE5E7EB), Color(0xFF6B7280), 'InActive'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class PortalAdminCustomerStatusPill extends StatelessWidget {
  final String status;

  const PortalAdminCustomerStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.trim().toLowerCase();
    final active = s == 'active' || s.isEmpty;
    return PortalAdminActivePill(active: active);
  }
}
