import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/repository/admin_repository.dart';

class StaffEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const StaffEditorDialog({super.key, this.existing});

  @override
  State<StaffEditorDialog> createState() => _StaffEditorDialogState();
}

class _StaffEditorDialogState extends State<StaffEditorDialog> {
  final _repo = AdminRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _staffId;
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _confirm;

  String _role = 'counter_officer';
  String _status = 'active';
  String? _branchId;
  String? _serviceId;
  String? _assignedCounterId;

  List<Map<String, dynamic>> _branches = const [];
  List<Map<String, dynamic>> _services = const [];
  List<Map<String, dynamic>> _counters = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? const {};
    _staffId = TextEditingController(text: (e['staffId'] ?? '').toString());
    _name = TextEditingController(text: (e['name'] ?? '').toString());
    _email = TextEditingController(text: (e['email'] ?? '').toString());
    _role = (e['role'] ?? 'counter_officer').toString();
    _status = (e['status'] ?? 'active').toString();
    _assignedCounterId = (e['assignedCounterId'] ?? '').toString();
    if (_assignedCounterId != null && _assignedCounterId!.isEmpty) _assignedCounterId = null;
    _password = TextEditingController(text: '');
    _confirm = TextEditingController(text: '');
    _loadMaster();
  }

  @override
  void dispose() {
    _staffId.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _loadMaster() async {
    try {
      final branches = await _repo.listBranches();
      // Choose first branch by default for better UX.
      final defaultBranchId = branches.isEmpty ? null : (branches.first['branchId'] ?? '').toString();
      setState(() {
        _branches = branches;
        _branchId = _branchId ?? (defaultBranchId?.isEmpty == true ? null : defaultBranchId);
      });

      // If editing and counter already assigned, infer branch/service from that counter.
      final allCounters = await _repo.listCounters();
      String? inferredBranch;
      String? inferredService;
      if (_assignedCounterId != null) {
        final hit = allCounters.firstWhere(
          (c) => (c['counterId'] ?? '').toString() == _assignedCounterId,
          orElse: () => const <String, dynamic>{},
        );
        final b = (hit['branchId'] ?? '').toString();
        if (b.isNotEmpty) inferredBranch = b;
        final s = (hit['serviceId'] ?? '').toString();
        if (s.isNotEmpty) inferredService = s;
      }
      if (inferredBranch != null) {
        setState(() => _branchId = inferredBranch);
      }
      if (inferredService != null) {
        setState(() => _serviceId = inferredService);
      }

      await _loadServicesForBranch(_branchId);
      await _loadCounters(branchId: _branchId, serviceId: _serviceId);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadServicesForBranch(String? branchId) async {
    if (branchId == null || branchId.isEmpty) {
      setState(() {
        _services = const [];
        _serviceId = null;
      });
      return;
    }
    try {
      final services = await _repo.listServices(branchId: branchId);
      services.sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
      setState(() => _services = services);

      if (_serviceId == null || !_services.any((s) => (s['serviceId'] ?? '').toString() == _serviceId)) {
        final first = _services.isEmpty ? null : (_services.first['serviceId'] ?? '').toString();
        setState(() => _serviceId = (first != null && first.isNotEmpty) ? first : null);
      }
    } catch (_) {
      setState(() {
        _services = const [];
        _serviceId = null;
      });
    }
  }

  Future<void> _loadCounters({required String? branchId, required String? serviceId}) async {
    if (branchId == null || branchId.isEmpty || serviceId == null || serviceId.isEmpty) {
      setState(() {
        _counters = const [];
        _assignedCounterId = null;
      });
      return;
    }
    try {
      final data = await _repo.listCounters(branchId: branchId, serviceId: serviceId);
      setState(() => _counters = data);
      if (_assignedCounterId != null &&
          !_counters.any((c) => (c['counterId'] ?? '').toString() == _assignedCounterId)) {
        setState(() => _assignedCounterId = null);
      }
    } catch (_) {
      setState(() {
        _counters = const [];
        _assignedCounterId = null;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    final password = _password.text.trim();
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password is required (reset/set)')));
      return;
    }

    setState(() => _loading = true);
    try {
      await _repo.upsertStaff(
        staffId: _staffId.text.trim(),
        name: _name.text.trim(),
        email: _email.text.trim(),
        role: _role,
        status: _status,
        assignedCounterId: _assignedCounterId,
        password: password,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Staff' : 'Add Staff'),
      content: SizedBox(
        width: 560,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(18.0),
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _staffId,
                        enabled: !isEdit,
                        decoration: const InputDecoration(labelText: 'Staff ID (unique)'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Required';
                          if (!s.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(value: 'counter_officer', child: Text('Counter Officer')),
                          DropdownMenuItem(value: 'supervisor', child: Text('Supervisor')),
                        ],
                        onChanged: (v) => setState(() => _role = v ?? 'counter_officer'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'break', child: Text('On Break')),
                          DropdownMenuItem(value: 'inactive', child: Text('InActive')),
                        ],
                        onChanged: (v) => setState(() => _status = v ?? 'active'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _branchId,
                        decoration: const InputDecoration(labelText: 'Branch'),
                        items: _branches
                            .map((b) => DropdownMenuItem(
                                  value: (b['branchId'] ?? '').toString(),
                                  child: Text((b['name'] ?? b['branchId'] ?? '').toString()),
                                ))
                            .toList(),
                        onChanged: (v) async {
                          setState(() {
                            _branchId = v;
                            _serviceId = null;
                            _assignedCounterId = null;
                          });
                          await _loadServicesForBranch(v);
                          await _loadCounters(branchId: _branchId, serviceId: _serviceId);
                        },
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Select a branch' : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _serviceId,
                        decoration: const InputDecoration(labelText: 'Service'),
                        items: _services
                            .map((s) => DropdownMenuItem(
                                  value: (s['serviceId'] ?? '').toString(),
                                  child: Text((s['name'] ?? s['serviceId'] ?? '').toString()),
                                ))
                            .toList(),
                        onChanged: (v) async {
                          setState(() {
                            _serviceId = v;
                            _assignedCounterId = null;
                          });
                          await _loadCounters(branchId: _branchId, serviceId: v);
                        },
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Select a service' : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: _assignedCounterId,
                        decoration: const InputDecoration(labelText: 'Counter'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Unassigned')),
                          ..._counters.map(
                            (c) => DropdownMenuItem(
                              value: (c['counterId'] ?? '').toString(),
                              child: Text((c['counterName'] ?? c['counterId'] ?? '').toString()),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _assignedCounterId = v),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _password,
                        decoration: InputDecoration(
                          labelText: isEdit ? 'New Password (reset)' : 'Password',
                        ),
                        obscureText: true,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirm,
                        decoration: const InputDecoration(labelText: 'Confirm Password'),
                        obscureText: true,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _loading ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

