import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/repository/staff_repository.dart';
import 'package:intelliqueue/portal/view/admin/widgets/portal_admin_table_chrome.dart';
import 'package:intelliqueue/portal/view/staff/widgets/token_details_dialog.dart';
import 'package:intelliqueue/portal/view/widgets/portal_shell.dart';

class TokenListPage extends StatefulWidget {
  final PortalSession session;
  const TokenListPage({super.key, required this.session});

  @override
  State<TokenListPage> createState() => _TokenListPageState();
}

class _TokenListPageState extends State<TokenListPage> {
  final _repo = StaffRepository();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

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
      final data = await _repo.tokenListByStaff(widget.session.staffId);
      setState(() => _rows = data);
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
      title: 'Token List',
      active: PortalNavItem.tokenList,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: Icon(Icons.refresh_rounded, color: Colors.grey.shade600),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _rows.isEmpty
                        ? Center(
                            child: Text(
                              'No tokens found',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          )
                        : _TokenListCard(rows: _rows),
          ),
        ],
      ),
    );
  }
}

class _TokenListCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;

  const _TokenListCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: PortalAdminTableChrome.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minW = PortalAdminTableChrome.tableMinWidth(constraints);
          final h = PortalAdminTableChrome.tableHeight(constraints);
          return PortalAdminTableChrome.boundedHorizontalTable(
            minTableWidth: minW,
            height: h,
            header: Container(
              color: PortalAdminTableChrome.headerBg,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(flex: 2, child: _h('Token No.')),
                  Expanded(flex: 2, child: _h('User')),
                  Expanded(flex: 2, child: _h('Type')),
                  Expanded(flex: 2, child: _h('Status')),
                  Expanded(flex: 2, child: _h('Time')),
                  SizedBox(width: 88, child: _h('Actions')),
                ],
              ),
            ),
            body: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final r = rows[index];
                final token = (r['tokenNumber'] ?? '').toString();
                final user = (r['userPhone'] ?? '').toString();
                final type = (r['tokenType'] ?? 'Normal').toString();
                final status = (r['status'] ?? 'active').toString();
                final time = (r['createdAt'] ?? '').toString();
                final timeShort = time.isEmpty ? '—' : time.split('T').last.replaceAll('Z', '');
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          token,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(user, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                      ),
                      Expanded(flex: 2, child: _TypeChip(type: type)),
                      Expanded(flex: 2, child: _StatusChip(status: status)),
                      Expanded(
                        flex: 2,
                        child: Text(
                          timeShort,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        child: TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => TokenDetailsDialog(token: r),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: PortalAdminTableChrome.actionRed,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          child: const Text('View', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  static Widget _h(String t) {
    return Text(
      t,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Color(0xFF374151),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final (Color bg, String label) = switch (type) {
      'VIP' => (const Color(0xFFFCE7F3), 'VIP'),
      'SeniorCitizen' => (const Color(0xFFDCFCE7), 'Senior'),
      _ => (const Color(0xFFE5E7EB), 'Normal'),
    };
    final fg = switch (type) {
      'VIP' => const Color(0xFFDB2777),
      'SeniorCitizen' => const Color(0xFF16A34A),
      _ => const Color(0xFF374151),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, String label) = switch (status) {
      'serving' => (const Color(0xFFDCFCE7), 'Serving'),
      'active' => (const Color(0xFFDBEAFE), 'Waiting'),
      'waiting' => (const Color(0xFFDBEAFE), 'Waiting'),
      'cancelled' => (const Color(0xFFFEE2E2), 'Cancelled'),
      'skipped' => (const Color(0xFFFEF3C7), 'Skipped'),
      'completed' => (const Color(0xFFE5E7EB), 'Completed'),
      _ => (const Color(0xFFE5E7EB), status),
    };
    final fg = switch (status) {
      'serving' => const Color(0xFF16A34A),
      'active' => const Color(0xFF2563EB),
      'waiting' => const Color(0xFF2563EB),
      'cancelled' => const Color(0xFFDC2626),
      'skipped' => const Color(0xFFD97706),
      _ => const Color(0xFF374151),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
      ),
    );
  }
}
