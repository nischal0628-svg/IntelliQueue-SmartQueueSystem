import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/repository/admin_repository.dart';
import 'package:intelliqueue/portal/view/admin/widgets/portal_admin_table_chrome.dart';
import 'package:intelliqueue/portal/view/admin/widgets/staff_editor_dialog.dart';
import 'package:intelliqueue/portal/view/widgets/portal_shell.dart';

class ManageStaffPage extends StatefulWidget {
  final PortalSession session;
  const ManageStaffPage({super.key, required this.session});

  @override
  State<ManageStaffPage> createState() => _ManageStaffPageState();
}

class _ManageStaffPageState extends State<ManageStaffPage> {
  final _repo = AdminRepository();
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
      final data = await _repo.listStaff();
      setState(() => _rows = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addOrEdit(Map<String, dynamic>? existing) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StaffEditorDialog(existing: existing),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(String staffId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this staff member?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _repo.deleteStaff(staffId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      session: widget.session,
      title: 'Manage Staff',
      active: PortalNavItem.manageStaff,
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
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _loading ? null : () => _addOrEdit(null),
                style: PortalAdminTableChrome.primaryButtonStyle(),
                icon: const Icon(Icons.person_add_alt_1, size: 20),
                label: const Text('+ Add Staff', style: TextStyle(fontWeight: FontWeight.w600)),
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
                              'No staff found',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          )
                        : _StaffCard(
                            rows: _rows,
                            onEdit: _addOrEdit,
                            onDelete: _delete,
                          ),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final void Function(Map<String, dynamic> row) onEdit;
  final void Function(String staffId) onDelete;

  const _StaffCard({
    required this.rows,
    required this.onEdit,
    required this.onDelete,
  });

  static String _prettyRole(String role) {
    return switch (role) {
      'counter_officer' => 'Counter Officer',
      'supervisor' => 'Supervisor',
      'admin' => 'Admin',
      _ => role,
    };
  }

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
                  Expanded(flex: 3, child: _h('Name')),
                  Expanded(flex: 2, child: _h('Role')),
                  Expanded(flex: 2, child: _h('Counter')),
                  Expanded(flex: 2, child: _h('Status')),
                  SizedBox(width: 100, child: _h('Actions')),
                ],
              ),
            ),
            body: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final r = rows[index];
                final staffId = (r['staffId'] ?? '').toString();
                final name = (r['name'] ?? '').toString();
                final role = (r['role'] ?? '').toString();
                final counterName = (r['assignedCounterName'] ?? '-').toString();
                final status = (r['status'] ?? 'active').toString();
                final isAdmin = role == 'admin';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          name.isEmpty ? '—' : name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF111827)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          _prettyRole(role),
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          counterName.isEmpty ? '—' : counterName,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PortalAdminStaffStatusPill(status: status),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Edit / Reset Password',
                              onPressed: isAdmin ? null : () => onEdit(r),
                              icon: Icon(
                                Icons.edit_outlined,
                                color: isAdmin ? Colors.grey.shade400 : PortalAdminTableChrome.actionRed,
                                size: 22,
                              ),
                              style: IconButton.styleFrom(
                                foregroundColor: isAdmin ? Colors.grey.shade400 : PortalAdminTableChrome.actionRed,
                                hoverColor: isAdmin ? null : PortalAdminTableChrome.actionRed.withValues(alpha: 0.08),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: isAdmin ? null : () => onDelete(staffId),
                              icon: Icon(
                                Icons.delete_outline,
                                color: isAdmin ? Colors.grey.shade400 : PortalAdminTableChrome.actionRed,
                                size: 22,
                              ),
                              style: IconButton.styleFrom(
                                foregroundColor: isAdmin ? Colors.grey.shade400 : PortalAdminTableChrome.actionRed,
                                hoverColor: isAdmin ? null : PortalAdminTableChrome.actionRed.withValues(alpha: 0.08),
                              ),
                            ),
                          ],
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
