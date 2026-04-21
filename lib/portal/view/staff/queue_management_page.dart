import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/portal/repository/staff_repository.dart';
import 'package:intelliqueue/portal/view/admin/widgets/portal_admin_table_chrome.dart';
import 'package:intelliqueue/portal/view/widgets/portal_shell.dart';
import 'package:intelliqueue/ui/app_colors.dart';

class QueueManagementPage extends StatefulWidget {
  final PortalSession session;
  const QueueManagementPage({super.key, required this.session});

  @override
  State<QueueManagementPage> createState() => _QueueManagementPageState();
}

class _QueueManagementPageState extends State<QueueManagementPage> {
  final _repo = StaffRepository();
  Timer? _timer;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _context;
  Map<String, dynamic>? _queue;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final ctx = await _repo.getContext(widget.session.staffId);
      final q = await _repo.getQueue(widget.session.staffId);
      if (!mounted) return;
      setState(() {
        _context = ctx;
        _queue = q;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (!silent && mounted) setState(() => _loading = false);
      if (silent && mounted && _loading) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? get _currentlyServing {
    final counterId = (_context?['counterId'] ?? '').toString();
    final nowServing = (_queue?['nowServing'] is List) ? (_queue!['nowServing'] as List) : const [];
    for (final item in nowServing) {
      final m = Map<String, dynamic>.from(item as Map);
      if ((m['servingCounterId'] ?? '').toString() == counterId) return m;
    }
    return null;
  }

  List<Map<String, dynamic>> get _upcoming {
    final waiting = (_queue?['waitingTokens'] is List) ? (_queue!['waitingTokens'] as List) : const [];
    return waiting.take(10).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _callNext() async {
    try {
      final msg = await _repo.callNextV2(widget.session.staffId);
      await _refresh(silent: true);
      if (!mounted) return;
      if (msg != null && msg.trim().isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _complete() async {
    final serving = _currentlyServing;
    if (serving == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete this token?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Complete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.complete(
        staffId: widget.session.staffId,
        counterId: (_context?['counterId'] ?? '').toString(),
        bookingId: (serving['bookingId'] ?? '').toString(),
      );
      await _refresh(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cancel() async {
    final serving = _currentlyServing;
    if (serving == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this token?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.cancel(
        staffId: widget.session.staffId,
        counterId: (_context?['counterId'] ?? '').toString(),
        bookingId: (serving['bookingId'] ?? '').toString(),
      );
      await _refresh(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _callNow(Map<String, dynamic> item) async {
    final serving = _currentlyServing;
    if (serving != null) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace current token?'),
          content: const Text('Choose what to do with the current token.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 'no'), child: const Text('Do not proceed')),
            TextButton(onPressed: () => Navigator.pop(context, 'complete'), child: const Text('Complete current')),
            FilledButton(onPressed: () => Navigator.pop(context, 'cancel'), child: const Text('Cancel current')),
          ],
        ),
      );
      if (action == 'no' || action == null) return;
      if (action == 'complete') {
        await _repo.complete(
          staffId: widget.session.staffId,
          counterId: (_context?['counterId'] ?? '').toString(),
          bookingId: (serving['bookingId'] ?? '').toString(),
        );
      }
      if (action == 'cancel') {
        await _repo.cancel(
          staffId: widget.session.staffId,
          counterId: (_context?['counterId'] ?? '').toString(),
          bookingId: (serving['bookingId'] ?? '').toString(),
        );
      }
    }
    try {
      await _repo.callNow(
        staffId: widget.session.staffId,
        counterId: (_context?['counterId'] ?? '').toString(),
        bookingId: (item['bookingId'] ?? '').toString(),
      );
      await _refresh(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContext = _context != null;
    final counterStatus = (_context?['counterStatus'] ?? '').toString();

    if (_loading && !hasContext) {
      return PortalShell(
        session: widget.session,
        title: 'Queue Management',
        active: PortalNavItem.queueManagement,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && !hasContext) {
      return PortalShell(
        session: widget.session,
        title: 'Queue Management',
        active: PortalNavItem.queueManagement,
        child: Center(child: Text(_error!)),
      );
    }

    // No counter assigned
    if ((_context?['counterId'] ?? '').toString().isEmpty) {
      return PortalShell(
        session: widget.session,
        title: 'Queue Management',
        active: PortalNavItem.queueManagement,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('No counter assigned', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              Text('Go to Counter Assignment to select a counter.'),
            ],
          ),
        ),
      );
    }

    final serving = _currentlyServing;
    final token = (serving?['tokenNumber'] ?? '—').toString();
    final serviceName = (_context?['serviceName'] ?? 'Service').toString();
    final counterName = (_context?['counterName'] ?? 'Counter').toString();

    final callNextEnabled = counterStatus == 'active';
    final canSkipCancel = serving != null;

    return PortalShell(
      session: widget.session,
      title: 'Queue Management',
      active: PortalNavItem.queueManagement,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Refresh',
              onPressed: () => _refresh(),
              icon: Icon(Icons.refresh_rounded, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 8),
          // Hero card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text('Currently Serving', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  token,
                  style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '$serviceName - $counterName',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: callNextEnabled ? _callNext : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Call Next', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    FilledButton.icon(
                      onPressed: (callNextEnabled && canSkipCancel) ? _complete : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Complete', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    FilledButton.icon(
                      onPressed: canSkipCancel ? _cancel : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                if (counterStatus == 'break') ...[
                  const SizedBox(height: 10),
                  const Text('Counter on break', style: TextStyle(color: Colors.white70)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // List card
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: PortalAdminTableChrome.cardDecoration(),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: PortalAdminTableChrome.headerBg,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Text(
                      'Waiting queue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _upcoming.isEmpty
                          ? Center(
                              child: Text(
                                'No tokens waiting',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _upcoming.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _upcoming[index];
                                final t = (item['tokenNumber'] ?? '').toString();
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          t,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                        ),
                                      ),
                                      FilledButton(
                                        onPressed: () => _callNow(item),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.headerBlue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text('Call Now', style: TextStyle(fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
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

