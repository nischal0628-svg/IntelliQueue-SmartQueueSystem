import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/repository/admin_dashboard_repository.dart';
import 'package:intelliqueue/portal/view/widgets/portal_shell.dart';

class AnalyticsPage extends StatefulWidget {
  final PortalSession session;
  const AnalyticsPage({super.key, required this.session});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
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
      final d = await _repo.analytics();
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
      title: 'Analytics',
      active: PortalNavItem.analytics,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _AnalyticsBody(data: _data ?? const {}),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AnalyticsBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = (data['totalDailyTokens'] ?? 0).toString();
    final activeQueues = (data['activeQueues'] ?? 0).toString();
    final totalStaff = (data['totalStaff'] ?? 0).toString();
    final last7Days =
        (data['last7Days'] is List) ? (data['last7Days'] as List) : const [];
    final serviceDist =
        (data['serviceDistribution'] is List) ? (data['serviceDistribution'] as List) : const [];
    final counterPerf =
        (data['counterPerformance'] is List) ? (data['counterPerformance'] as List) : const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _metric('Total Daily Tokens', total),
            _metric('Active Queues', activeQueues),
            _metric('Total Staff', totalStaff),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              _TrendCard(items: last7Days),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _DistributionCard(title: 'Service Distribution (Today)', items: serviceDist, labelKey: 'serviceName', valueKey: 'count')),
                  const SizedBox(width: 16),
                  Expanded(child: _DistributionCard(title: 'Counter Performance (Today)', items: counterPerf, labelKey: 'counterName', valueKey: 'served')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metric(String title, String value) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(title, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final List items;
  const _TrendCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final parsed = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final maxTokens = parsed.isEmpty
        ? 0
        : parsed.map((e) => (e['tokens'] as num?) ?? 0).fold<num>(0, (a, b) => a > b ? a : b).toInt();

    return Container(
      height: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Token Trend (Last 7 days)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(
            child: parsed.isEmpty
                ? Center(child: Text('No data', style: TextStyle(color: Colors.grey.shade700)))
                : ListView.separated(
                    itemCount: parsed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final m = parsed[index];
                      final day = (m['day'] ?? '').toString();
                      final tokens = ((m['tokens'] as num?) ?? 0).toInt();
                      final v = maxTokens <= 0 ? 0.0 : (tokens / maxTokens);
                      return Row(
                        children: [
                          SizedBox(width: 92, child: Text(day, style: const TextStyle(fontWeight: FontWeight.w700))),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(99),
                              child: LinearProgressIndicator(
                                value: v,
                                minHeight: 10,
                                backgroundColor: const Color(0xFFE5E7EB),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(width: 36, child: Text(tokens.toString(), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  final String title;
  final List items;
  final String labelKey;
  final String valueKey;
  const _DistributionCard({
    required this.title,
    required this.items,
    required this.labelKey,
    required this.valueKey,
  });

  @override
  Widget build(BuildContext context) {
    final parsed = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final maxValue = parsed.isEmpty
        ? 0
        : parsed
            .map((e) => (e[valueKey] as num?) ?? 0)
            .fold<num>(0, (a, b) => a > b ? a : b)
            .toInt();

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(
            child: parsed.isEmpty
                ? Center(child: Text('No data', style: TextStyle(color: Colors.grey.shade700)))
                : ListView.separated(
                    itemCount: parsed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final m = parsed[index];
                      final label = (m[labelKey] ?? 'Unknown').toString();
                      final value = ((m[valueKey] as num?) ?? 0).toInt();
                      final v = maxValue <= 0 ? 0.0 : (value / maxValue);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 12),
                              Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: v,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE5E7EB),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

