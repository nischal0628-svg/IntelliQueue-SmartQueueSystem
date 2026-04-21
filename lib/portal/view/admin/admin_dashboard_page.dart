import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/repository/admin_dashboard_repository.dart';
import 'package:intelliqueue/portal/view/widgets/portal_shell.dart';
import 'package:intelliqueue/ui/app_colors.dart';

class AdminDashboardPage extends StatefulWidget {
  final PortalSession session;
  const AdminDashboardPage({super.key, required this.session});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _repo = AdminDashboardRepository();
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
      final d = await _repo.overview();
      setState(() => _data = d);
    } catch (e) {
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
              : _DashboardBody(data: _data ?? const {}, onRefresh: _load),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onRefresh;

  const _DashboardBody({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final total = (data['totalDailyTokens'] ?? 0).toString();
    final activeQueues = (data['activeQueues'] ?? 0).toString();
    final totalStaff = (data['totalStaff'] ?? 0).toString();
    final avgWait = (data['avgWaitMinutes'] ?? 0);
    final avgWaitLabel = avgWait == 0 ? '-' : '${avgWait}m';
    final todayActivity = (data['todayActivity'] is List) ? (data['todayActivity'] as List) : const [];
    final serviceDist = (data['serviceDistribution'] is List)
        ? (data['serviceDistribution'] as List)
        : const [];
    final systemStatus = (data['systemStatus'] is Map)
        ? Map<String, dynamic>.from(data['systemStatus'] as Map)
        : const <String, dynamic>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: onRefresh,
            icon: Icon(Icons.refresh_rounded, color: Colors.grey.shade600),
            tooltip: 'Refresh',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.confirmation_number_outlined,
                iconBg: const Color(0xFFE8F1FF),
                iconColor: AppColors.primaryBlue,
                value: total,
                label: 'Total Daily Tokens',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricTile(
                icon: Icons.queue_play_next_outlined,
                iconBg: const Color(0xFFF3E8FF),
                iconColor: const Color(0xFF7C3AED),
                value: activeQueues,
                label: 'Active Queues',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricTile(
                icon: Icons.groups_outlined,
                iconBg: const Color(0xFFE8F8EF),
                iconColor: const Color(0xFF16A34A),
                value: totalStaff,
                label: 'Total Staff',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _MetricTile(
                icon: Icons.schedule_outlined,
                iconBg: const Color(0xFFFFF4E6),
                iconColor: const Color(0xFFEA580C),
                value: avgWaitLabel,
                label: 'Avg Wait Time',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _ActivityPanel(items: todayActivity)),
              const SizedBox(width: 16),
              Expanded(child: _DistributionPanel(items: serviceDist)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SystemStatusPanel(status: systemStatus),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;

  const _MetricTile({
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                ' · today',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  final List items;

  const _ActivityPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Text(
              "Today's Activity",
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
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
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
                      child: Icon(Icons.show_chart_rounded, size: iconSize, color: Colors.grey.shade300),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No activity today',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                      itemBuilder: (context, index) {
                        final m = Map<String, dynamic>.from(items[index] as Map);
                        final token = (m['tokenNumber'] ?? '').toString();
                        final service = (m['serviceName'] ?? '').toString();
                        final branch = (m['branchName'] ?? '').toString();
                        final status = (m['status'] ?? '').toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 64,
                                child: Text(
                                  token.isEmpty ? '-' : token,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  [service, branch].where((e) => e.trim().isNotEmpty).join(' · '),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusPill(status: status),
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

class _DistributionPanel extends StatelessWidget {
  final List items;

  const _DistributionPanel({required this.items});

  @override
  Widget build(BuildContext context) {
    final parsed = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final maxCount = parsed.isEmpty
        ? 0
        : parsed.map((e) => (e['count'] as num?) ?? 0).fold<num>(0, (a, b) => a > b ? a : b).toInt();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Text(
              'Service Distribution',
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
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
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
                      child: Icon(Icons.pie_chart_outline_rounded, size: iconSize, color: Colors.grey.shade300),
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: parsed.isEmpty
                  ? Center(
                      child: Text(
                        'No bookings today',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      itemCount: parsed.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final m = parsed[index];
                        final name = (m['serviceName'] ?? 'Unknown').toString();
                        final count = ((m['count'] as num?) ?? 0).toInt();
                        final v = maxCount <= 0 ? 0.0 : (count / maxCount);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                                  ),
                                ),
                                Text(
                                  count.toString(),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: v,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFE5E7EB),
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ],
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

class _SystemStatusPanel extends StatelessWidget {
  final Map<String, dynamic> status;

  const _SystemStatusPanel({required this.status});

  @override
  Widget build(BuildContext context) {
    final all = (status['allSystem'] ?? 'Unknown').toString();
    final db = (status['database'] ?? 'Unknown').toString();
    final api = (status['apiServices'] ?? 'Unknown').toString();
    final activeCounters = (status['activeCounters'] ?? 0).toString();
    final inactiveCounters = (status['inactiveCounters'] ?? 0).toString();
    final activeStaff = (status['activeStaff'] ?? 0).toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Status',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatusLane(title: 'All System', state: all)),
              const SizedBox(width: 12),
              Expanded(child: _StatusLane(title: 'Database', state: db)),
              const SizedBox(width: 12),
              Expanded(child: _StatusLane(title: 'API Services', state: api)),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Active counters', value: activeCounters)),
              Expanded(child: _MiniStat(label: 'Inactive counters', value: inactiveCounters)),
              Expanded(child: _MiniStat(label: 'Active staff', value: activeStaff)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusLane extends StatelessWidget {
  final String title;
  final String state;

  const _StatusLane({required this.title, required this.state});

  bool get _ok => state.toLowerCase().contains('operational');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _ok ? const Color(0xFFD1FAE5) : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              state.isEmpty ? '-' : state,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _ok ? const Color(0xFF047857) : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.trim().toLowerCase();
    final (bg, fg) = switch (s) {
      'completed' => (const Color(0xFFD4F6E6), const Color(0xFF2DBE78)),
      'cancelled' => (const Color(0xFFFFD7D7), const Color(0xFFE74C3C)),
      'serving' || 'active' || 'waiting' => (const Color(0xFFDCEBFF), const Color(0xFF2F80ED)),
      _ => (const Color(0xFFE5E7EB), const Color(0xFF6B7280)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.isEmpty ? '-' : status,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
