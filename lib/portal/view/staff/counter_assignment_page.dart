import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/repository/admin_repository.dart';
import 'package:intelliqueue/portal/repository/staff_repository.dart';
import 'package:intelliqueue/portal/view/admin/widgets/portal_admin_table_chrome.dart';
import 'package:intelliqueue/portal/view/widgets/portal_shell.dart';

class CounterAssignmentPage extends StatefulWidget {
  final PortalSession session;
  const CounterAssignmentPage({super.key, required this.session});

  @override
  State<CounterAssignmentPage> createState() => _CounterAssignmentPageState();
}

class _CounterAssignmentPageState extends State<CounterAssignmentPage> {
  final _adminRepo = AdminRepository();
  final _staffRepo = StaffRepository();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _counters = const [];
  Map<String, dynamic>? _context;

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
      final ctx = await _staffRepo.getContext(widget.session.staffId);
      final branchId = (ctx['branchId'] ?? '').toString();
      final serviceId = (ctx['serviceId'] ?? '').toString();
      // Only counters for this staff member's service (three per service), not every counter in the branch.
      final data = await _adminRepo.listCounters(
        branchId: branchId.isEmpty ? null : branchId,
        serviceId: serviceId.isEmpty ? null : serviceId,
      );
      setState(() {
        _context = ctx;
        _counters = data;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign(String counterId) async {
    try {
      await _staffRepo.assignCounter(staffId: widget.session.staffId, counterId: counterId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Counter assigned')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchName = (_context?['branchName'] ?? '').toString();
    return PortalShell(
      session: widget.session,
      title: 'Counter Assignment',
      active: PortalNavItem.counterAssignment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (branchName.isNotEmpty)
                Expanded(
                  child: Text(
                    'Your branch: $branchName',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
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
                    : _counters.isEmpty
                        ? Center(
                            child: Text(
                              'No counters configured',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          )
                        : Container(
                            decoration: PortalAdminTableChrome.cardDecoration(),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  color: PortalAdminTableChrome.headerBg,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  child: Text(
                                    'Select a counter',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: GridView.builder(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                        childAspectRatio: 1.6,
                                      ),
                                      itemCount: _counters.length,
                                      itemBuilder: (context, index) {
                                        final c = _counters[index];
                                        final counterId = (c['counterId'] ?? '').toString();
                                        final counterName = (c['counterName'] ?? counterId).toString();
                                        final status = (c['status'] ?? 'active').toString();
                                        final assignedEmail = (c['assignedStaffEmail'] ?? '').toString();
                                        final isMine = widget.session.email == assignedEmail;
                                        return _CounterCard(
                                          counterName: counterName,
                                          status: status,
                                          assignedEmail: assignedEmail,
                                          isMine: isMine,
                                          onAssign: () => _assign(counterId),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String counterName;
  final String status;
  final String assignedEmail;
  final bool isMine;
  final VoidCallback onAssign;

  const _CounterCard({
    required this.counterName,
    required this.status,
    required this.assignedEmail,
    required this.isMine,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  counterName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              PortalAdminStaffStatusPill(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Text('Staff', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            assignedEmail.isEmpty ? '—' : assignedEmail,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isMine ? null : onAssign,
              style: isMine
                  ? FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE5E7EB),
                      foregroundColor: Colors.grey.shade700,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: Colors.grey.shade600,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    )
                  : PortalAdminTableChrome.primaryButtonStyle(),
              child: Text(isMine ? 'Assigned' : 'Assign to me', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
