import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/repository/staff_repository.dart';
import 'package:intelliqueue/portal/view/admin/widgets/portal_admin_table_chrome.dart';
import 'package:intelliqueue/portal/view/widgets/portal_shell.dart';

class SendNotificationPage extends StatefulWidget {
  final PortalSession session;
  const SendNotificationPage({super.key, required this.session});

  @override
  State<SendNotificationPage> createState() => _SendNotificationPageState();
}

class _SendNotificationPageState extends State<SendNotificationPage> {
  final _repo = StaffRepository();
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await _repo.sendNotification(
        staffId: widget.session.staffId,
        title: _title.text.trim(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      _title.clear();
      _message.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification sent')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PortalShell(
      session: widget.session,
      title: 'Send Notification',
      active: PortalNavItem.sendNotification,
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: PortalAdminTableChrome.cardDecoration(),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: PortalAdminTableChrome.headerBg,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Text(
                      'Compose message',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            enabled: false,
                            initialValue: widget.session.assignedServiceName ?? 'Queue Type',
                            decoration: InputDecoration(
                              labelText: 'Recipient (Queue Type)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: const Color(0xFFF9FAFB),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _title,
                            decoration: InputDecoration(
                              labelText: 'Message Title',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Title required';
                              if (s.length < 3) return 'Min 3 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _message,
                            decoration: InputDecoration(
                              labelText: 'Message',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              alignLabelWithHint: true,
                            ),
                            minLines: 4,
                            maxLines: 8,
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Message required';
                              if (s.length < 5) return 'Min 5 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: _sending ? null : _send,
                              style: PortalAdminTableChrome.primaryButtonStyle(),
                              child: _sending
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Send Notification',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
