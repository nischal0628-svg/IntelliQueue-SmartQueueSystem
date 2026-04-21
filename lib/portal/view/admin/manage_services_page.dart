import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/repository/admin_repository.dart';
import 'package:intelliqueue/portal/view/admin/widgets/portal_admin_table_chrome.dart';
import 'package:intelliqueue/portal/view/admin/widgets/service_editor_dialog.dart';
import 'package:intelliqueue/portal/view/widgets/portal_shell.dart';

class ManageServicesPage extends StatefulWidget {
  final PortalSession session;
  const ManageServicesPage({super.key, required this.session});

  @override
  State<ManageServicesPage> createState() => _ManageServicesPageState();
}

class _ManageServicesPageState extends State<ManageServicesPage> {
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
      final data = await _repo.listServices();
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
      builder: (_) => ServiceEditorDialog(existing: existing),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(String serviceId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this service?'),
        content: const Text('This will remove it from the system.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _repo.deleteService(serviceId);
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
      title: 'Manage Service',
      active: PortalNavItem.manageServices,
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
                icon: const Icon(Icons.add, size: 20),
                label: const Text('+ Add Service', style: TextStyle(fontWeight: FontWeight.w600)),
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
                              'No services found',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                            ),
                          )
                        : _ServicesCard(
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

class _ServicesCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final void Function(Map<String, dynamic> row) onEdit;
  final void Function(String serviceId) onDelete;

  const _ServicesCard({
    required this.rows,
    required this.onEdit,
    required this.onDelete,
  });

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
                  Expanded(
                    flex: 3,
                    child: _h('Queue Name'),
                  ),
                  Expanded(
                    flex: 3,
                    child: _h('Category/Department'),
                  ),
                  Expanded(
                    flex: 2,
                    child: _h('Estimated time'),
                  ),
                  Expanded(
                    flex: 2,
                    child: _h('Status'),
                  ),
                  SizedBox(width: 100, child: _h('Actions')),
                ],
              ),
            ),
            body: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final r = rows[index];
                final serviceId = (r['serviceId'] ?? '').toString();
                final name = (r['name'] ?? '').toString();
                final category = (r['category'] ?? '').toString();
                final eta = '${(r['defaultEtaMinutes'] ?? 15)} mins';
                final isActive = (r['isActive'] == true);
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
                        flex: 3,
                        child: Text(
                          category.isEmpty ? '—' : category,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(eta, style: TextStyle(fontSize: 14, color: Colors.grey.shade800)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PortalAdminActivePill(active: isActive),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => onEdit(r),
                              icon: Icon(Icons.edit_outlined, color: PortalAdminTableChrome.actionRed, size: 22),
                              style: IconButton.styleFrom(
                                foregroundColor: PortalAdminTableChrome.actionRed,
                                hoverColor: PortalAdminTableChrome.actionRed.withValues(alpha: 0.08),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => onDelete(serviceId),
                              icon: Icon(Icons.delete_outline, color: PortalAdminTableChrome.actionRed, size: 22),
                              style: IconButton.styleFrom(
                                foregroundColor: PortalAdminTableChrome.actionRed,
                                hoverColor: PortalAdminTableChrome.actionRed.withValues(alpha: 0.08),
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
