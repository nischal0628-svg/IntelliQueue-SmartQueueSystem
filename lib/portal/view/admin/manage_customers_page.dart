import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/repository/admin_repository.dart';
import 'package:intelliqueue/portal/view/admin/widgets/portal_admin_table_chrome.dart';
import 'package:intelliqueue/portal/view/widgets/portal_shell.dart';

class ManageCustomersPage extends StatefulWidget {
  final PortalSession session;
  const ManageCustomersPage({super.key, required this.session});

  @override
  State<ManageCustomersPage> createState() => _ManageCustomersPageState();
}

class _ManageCustomersPageState extends State<ManageCustomersPage> {
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
      final data = await _repo.listCustomers();
      setState(() => _rows = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword(Map<String, dynamic> customer) async {
    final phone = (customer['userPhone'] ?? '').toString();
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset customer password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Phone: $phone'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Password is required';
                    if (s.length < 4) return 'Min 4 characters';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(context).pop(true);
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    try {
      await _repo.resetCustomerPassword(userPhone: phone, newPassword: controller.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset')));
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
      title: 'Manage Customers',
      active: PortalNavItem.manageCustomers,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                style: PortalAdminTableChrome.primaryButtonStyle(),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Failed to load customers: $_error'),
                            const SizedBox(height: 10),
                            FilledButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _rows.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'No customers yet.',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                                ),
                                const SizedBox(height: 10),
                                FilledButton(
                                  onPressed: _load,
                                  style: PortalAdminTableChrome.primaryButtonStyle(),
                                  child: const Text('Refresh'),
                                ),
                              ],
                            ),
                          )
                        : _CustomersCard(
                            rows: _rows,
                            onResetPassword: _resetPassword,
                          ),
          ),
        ],
      ),
    );
  }
}

class _CustomersCard extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final void Function(Map<String, dynamic> row) onResetPassword;

  const _CustomersCard({
    required this.rows,
    required this.onResetPassword,
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
                  Expanded(flex: 2, child: _h('Phone')),
                  Expanded(flex: 2, child: _h('Name')),
                  Expanded(flex: 3, child: _h('Email')),
                  Expanded(flex: 2, child: _h('Status')),
                  SizedBox(width: 140, child: _h('Actions')),
                ],
              ),
            ),
            body: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final c = rows[index];
                final phone = (c['userPhone'] ?? '').toString();
                final name = (c['name'] ?? '').toString();
                final email = (c['email'] ?? '').toString();
                final status = (c['status'] ?? 'active').toString();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          phone.isEmpty ? '—' : phone,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF111827)),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          name.isEmpty ? '—' : name,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          email.isEmpty ? '—' : email,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: PortalAdminCustomerStatusPill(status: status),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => onResetPassword(c),
                            style: TextButton.styleFrom(
                              foregroundColor: PortalAdminTableChrome.actionRed,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            child: const Text('Reset password', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
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
