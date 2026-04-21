import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/repository/admin_repository.dart';

class ServiceEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const ServiceEditorDialog({super.key, this.existing});

  @override
  State<ServiceEditorDialog> createState() => _ServiceEditorDialogState();
}

class _ServiceEditorDialogState extends State<ServiceEditorDialog> {
  final _repo = AdminRepository();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _id;
  late final TextEditingController _name;
  late final TextEditingController _category;
  late final TextEditingController _eta;
  bool _active = true;

  String? _branchId;
  List<Map<String, dynamic>> _branches = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? const {};
    _id = TextEditingController(text: (e['serviceId'] ?? '').toString());
    _name = TextEditingController(text: (e['name'] ?? e['queueName'] ?? '').toString());
    _category = TextEditingController(text: (e['category'] ?? '').toString());
    _eta = TextEditingController(text: (e['defaultEtaMinutes'] ?? 15).toString());
    _active = (e['isActive'] == null) ? true : (e['isActive'] == true);
    _branchId = (e['branchId'] ?? '').toString();
    _loadBranches();
  }

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _category.dispose();
    _eta.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final b = await _repo.listBranches();
      setState(() {
        _branches = b;
        _branchId = (_branchId != null && _branchId!.isNotEmpty)
            ? _branchId
            : (b.isNotEmpty ? (b.first['branchId'] ?? '').toString() : null);
      });
    } catch (_) {
      // ignore - UI will show empty dropdown
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final branchId = _branchId;
    if (branchId == null || branchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No branch found')));
      return;
    }

    setState(() => _loading = true);
    try {
      await _repo.upsertService(
        serviceId: _id.text.trim(),
        branchId: branchId,
        name: _name.text.trim(),
        category: _category.text.trim(),
        defaultEtaMinutes: int.tryParse(_eta.text.trim()) ?? 15,
        isActive: _active,
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
      title: Text(isEdit ? 'Edit Service' : 'Add Service'),
      content: SizedBox(
        width: 520,
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
                        controller: _id,
                        enabled: !isEdit,
                        decoration: const InputDecoration(labelText: 'Service ID (unique)'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _branchId,
                        items: _branches
                            .map(
                              (b) => DropdownMenuItem(
                                value: (b['branchId'] ?? '').toString(),
                                child: Text((b['name'] ?? b['branchId'] ?? '').toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _branchId = v),
                        decoration: const InputDecoration(labelText: 'Branch'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Queue/Service Name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _category,
                        decoration: const InputDecoration(labelText: 'Category/Department'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _eta,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Default ETA minutes'),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          if (n == null) return 'Enter a number';
                          if (n < 1) return 'Must be >= 1';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _active,
                        onChanged: (v) => setState(() => _active = v),
                        title: const Text('Active'),
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

