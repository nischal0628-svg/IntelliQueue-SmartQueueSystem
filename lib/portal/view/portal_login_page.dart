import 'package:flutter/material.dart';
import 'package:intelliqueue/portal/data/portal_session_store.dart';
import 'package:intelliqueue/portal/repository/portal_auth_repository.dart';
import 'package:intelliqueue/portal/view/admin/admin_dashboard_page.dart';
import 'package:intelliqueue/portal/view/staff/staff_dashboard_page.dart';
import 'package:intelliqueue/ui/app_colors.dart';

class PortalLoginPage extends StatefulWidget {
  const PortalLoginPage({super.key});

  @override
  State<PortalLoginPage> createState() => _PortalLoginPageState();
}

class _PortalLoginPageState extends State<PortalLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController(text: 'admin@gmail.com');
  final _password = TextEditingController(text: 'Admin@123');
  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final repo = PortalAuthRepository();
      final session = await repo.login(email: _email.text.trim(), password: _password.text);
      await PortalSessionStore.write(session);

      if (!mounted) return;
      final target = session.isAdmin
          ? AdminDashboardPage(session: session)
          : StaffDashboardPage(session: session);
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => target));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left brand panel
          Expanded(
            child: Container(
              color: AppColors.headerBlue,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'IQ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 26,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Welcome to IntelliQueue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Sign in to access the staff/admin portal.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Right form panel
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sign In',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Please sign in to access your account and manage your IntelliQueue.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 22),

                          Text('Email', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _email,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Email is required';
                              if (!s.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          Text('Password', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _password,
                            obscureText: !_showPassword,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _showPassword = !_showPassword),
                                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Offline demo: ask Admin to reset password.')),
                                );
                              },
                              child: const Text('Forgot Password ?'),
                            ),
                          ),
                          const SizedBox(height: 14),

                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8A1F),
                                foregroundColor: Colors.white,
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Sign In'),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              const Text("Don’t have an account? "),
                              TextButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('For thesis demo: staff accounts are created by Admin.'),
                                    ),
                                  );
                                },
                                child: const Text('Create account'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

