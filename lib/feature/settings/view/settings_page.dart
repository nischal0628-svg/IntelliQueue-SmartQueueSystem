import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/local_auth/local_auth.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/ui/app_scaffold_actions.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Settings'),
        actions: AppScaffoldActions.actions(context),
      ),
      body: ValueListenableBuilder(
        valueListenable: LocalAuth.sessionListenable(),
        builder: (context, _, __) {
          final themeMode = LocalAuth.themeModePreference();
          final notificationsEnabled = LocalAuth.notificationsEnabled();
          final accent = LocalAuth.accentColorValue();
          final apiBaseUrl = LocalAuth.apiBaseUrlPreference() ?? '';

          return ListView(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
            children: [
              _SectionTitle(title: 'Appearance'),
              SizedBox(height: 10.h),
              _Card(
                child: Column(
                  children: [
                    _RadioRow(
                      title: 'System',
                      selected: themeMode == 'system',
                      onTap: () => LocalAuth.setThemeModePreference('system'),
                    ),
                    Divider(height: 1, color: cs.outlineVariant),
                    _RadioRow(
                      title: 'Light',
                      selected: themeMode == 'light',
                      onTap: () => LocalAuth.setThemeModePreference('light'),
                    ),
                    Divider(height: 1, color: cs.outlineVariant),
                    _RadioRow(
                      title: 'Dark',
                      selected: themeMode == 'dark',
                      onTap: () => LocalAuth.setThemeModePreference('dark'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              _SectionTitle(title: 'Accent color'),
              SizedBox(height: 10.h),
              _Card(
                child: Wrap(
                  spacing: 12.w,
                  runSpacing: 12.h,
                  children: _accentPresets().map((c) {
                    final selected = accent == c.toARGB32();
                    return _ColorDot(
                      color: c,
                      selected: selected,
                      onTap: () => LocalAuth.setAccentColorValue(c.toARGB32()),
                    );
                  }).toList()
                    ..add(
                      _ColorDot(
                        color: AppColors.headerBlue,
                        selected: accent == null,
                        label: 'Default',
                        onTap: () => LocalAuth.setAccentColorValue(null),
                      ),
                    ),
                ),
              ),
              SizedBox(height: 16.h),
              _SectionTitle(title: 'Notifications'),
              SizedBox(height: 10.h),
              _Card(
                child: _SwitchRow(
                  title: 'Enable notifications',
                  value: notificationsEnabled,
                  onChanged: (v) => LocalAuth.setNotificationsEnabled(v),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'This controls local in-app notifications (offline).',
                style: TextStyle(fontSize: 12.sp, color: cs.onSurfaceVariant),
              ),
              SizedBox(height: 18.h),
              _SectionTitle(title: 'Backend'),
              SizedBox(height: 10.h),
              _BackendUrlCard(initialValue: apiBaseUrl),
            ],
          );
        },
      ),
    );
  }

  List<Color> _accentPresets() {
    return const [
      Color(0xFF0088FF), // current header blue
      Color(0xFF2F80ED), // alternate blue
      Color(0xFF2DBE78), // green
      Color(0xFFFF8D28), // orange
      Color(0xFFE74C3C), // red
      Color(0xFF8E44AD), // purple
    ];
  }
}

class _BackendUrlCard extends StatefulWidget {
  final String initialValue;
  const _BackendUrlCard({required this.initialValue});

  @override
  State<_BackendUrlCard> createState() => _BackendUrlCardState();
}

class _BackendUrlCardState extends State<_BackendUrlCard> {
  late final TextEditingController _controller;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await LocalAuth.setApiBaseUrlPreference(_controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backend URL saved')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Backend URL', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'For real phone use your laptop IP (ex: http://192.168.x.x:8080).',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'http://192.168.x.x:8080',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: _busy ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.headerBlue, foregroundColor: Colors.white),
              child: Text(_busy ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

class _RadioRow extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _RadioRow({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.headerBlue : cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.headerBlue,
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? label;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 24.r,
            width: 24.r,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? cs.onSurface : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          if (label != null) ...[
            SizedBox(width: 8.w),
            Text(
              label!,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}
