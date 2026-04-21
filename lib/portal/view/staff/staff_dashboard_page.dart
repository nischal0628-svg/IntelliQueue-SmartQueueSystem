import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/repository/staff_repository.dart';
import 'package:intelliqueue/portal/view/admin/widgets/portal_admin_table_chrome.dart';
import 'package:intelliqueue/portal/view/widgets/portal_shell.dart';

class StaffDashboardPage extends StatefulWidget {
  final PortalSession session;
  const StaffDashboardPage({super.key, required this.session});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  final _repo = StaffRepository();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _repo.getOverview(widget.session.staffId);
      if (!mounted) return;
      setState(() => _data = d);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      session: widget.session,
      title: 'Dashboard Overview',
      active: PortalNavItem.dashboard,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _StaffDashboardBody(data: _data ?? const {}, onRefresh: _load),
    );
  }
}

class _StaffDashboardBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;

  const _StaffDashboardBody({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final branchName = (data['branchName'] ?? '').toString();
    final serviceName = (data['serviceName'] ?? '').toString();
    final activeCounters = (data['activeCounters'] ?? 0).toString();
    final todaysTokens = (data['todaysTokens'] ?? 0).toString();
    final currentWaiting = (data['currentWaiting'] ?? 0).toString();
    final nowServing = (data['nowServing'] is List) ? (data['nowServing'] as List) : const [];
    final todaySummary = (data['todaySummary'] is Map)
        ? Map<String, dynamic>.from(data['todaySummary'] as Map)
        : const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                [branchName, serviceName].where((e) => e.trim().isNotEmpty).join(' · '),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Colors.grey.shade800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              icon: Icon(Icons.refresh_rounded, color: Colors.grey.shade600),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StaffMetricTile(
                icon: Icons.grid_view_outlined,
                iconBg: const Color(0xFFE8F1FF),
                iconColor: const Color(0xFF2F80ED),
                value: activeCounters,
                label: 'Active Counters',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StaffMetricTile(
                icon: Icons.confirmation_number_outlined,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF7C3AED),
                value: todaysTokens,
                label: "Today's Tokens",
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StaffMetricTile(
                icon: Icons.hourglass_empty_outlined,
                iconBg: const Color(0xFFE8F8EF),
                iconColor: const Color(0xFF16A34A),
                value: currentWaiting,
                label: 'Current Waiting',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _StaffMetricTile(
                icon: Icons.support_agent_outlined,
                iconBg: const Color(0xFFFFF4E6),
                iconColor: const Color(0xFFEA580C),
                value: nowServing.length.toString(),
                label: 'Now Serving',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _StaffServingPanel(items: nowServing)),
              const SizedBox(width: 16),
              Expanded(child: _StaffSummaryPanel(summary: todaySummary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StaffMetricTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;

  const _StaffMetricTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: PortalAdminTableChrome.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.trending_flat, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 4),
              Text(
                'Live',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
              Text(
                ' · branch',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffServingPanel extends StatelessWidget {
  final List items;

  const _StaffServingPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PortalAdminTableChrome.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: PortalAdminTableChrome.headerBg,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Text(
              'Currently Serving',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: LayoutBuilder(
                builder: (context, c) {
                  final iconSize = (c.maxHeight * 0.45).clamp(24.0, 48.0);
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Center(
                      child: Icon(Icons.groups_outlined, size: iconSize, color: Colors.grey.shade300),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No tokens serving',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final m = Map<String, dynamic>.from(items[index] as Map);
                        final token = (m['tokenNumber'] ?? '').toString();
                        final counter = (m['counterName'] ?? m['servingCounterId'] ?? '').toString();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  token.isEmpty ? '-' : token,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ),
                              Text(
                                counter.isEmpty ? '-' : counter,
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffSummaryPanel extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _StaffSummaryPanel({required this.summary});

  int _get(String k) => ((summary[k] as num?) ?? 0).toInt();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PortalAdminTableChrome.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: PortalAdminTableChrome.headerBg,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Text(
              'Customer Summary (Today)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              children: [
                _SummaryRow(label: 'Waiting', value: _get('active') + _get('waiting')),
                Divider(height: 1, color: Colors.grey.shade200),
                _SummaryRow(label: 'Serving', value: _get('serving')),
                Divider(height: 1, color: Colors.grey.shade200),
                _SummaryRow(label: 'Completed', value: _get('completed')),
                Divider(height: 1, color: Colors.grey.shade200),
                _SummaryRow(label: 'Cancelled', value: _get('cancelled')),
                Divider(height: 1, color: Colors.grey.shade200),
                _SummaryRow(label: 'Skipped', value: _get('skipped')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final int value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 14))),
          Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }
}
