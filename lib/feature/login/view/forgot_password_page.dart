import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Option A: password reset is done by Admin (Admin Portal → Manage Customers → reset password).
/// This page explains the flow and lets the user note phone/email for the admin.
class ForgotPasswordPage extends StatefulWidget {
  final String? initialPhone;
  const ForgotPasswordPage({super.key, this.initialPhone});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final TextEditingController _phone;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: widget.initialPhone ?? '');
    _email = TextEditingController();
  }

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _copyDetails() async {
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    final text = [
      if (phone.isNotEmpty) 'Phone: $phone',
      if (email.isNotEmpty) 'Email: $email',
    ].join('\n');
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter phone or email to copy')),
        );
      }
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied — share this with your admin')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot password'),
        backgroundColor: const Color(0xFF0088FF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        children: [
          Text(
            'Reset via Admin',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10.h),
          Text(
            'Passwords are managed locally. To reset your password, contact an administrator. '
            'They will open the Admin Portal → Manage Customers, find your account, and set a new password for you.',
            style: TextStyle(fontSize: 14.sp, height: 1.45, color: Colors.grey.shade800),
          ),
          SizedBox(height: 20.h),
          Text(
            'Your details (optional)',
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          Text(
            'Enter the phone or email you used when registering so your admin can find you quickly.',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
          ),
          SizedBox(height: 14.h),
          Text('Phone number', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 6.h),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '10-digit phone',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SizedBox(height: 16.h),
          Text('Email (optional)', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
          SizedBox(height: 6.h),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'you@example.com',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            height: 48.h,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copyDetails,
              icon: const Icon(Icons.copy),
              label: const Text('Copy details for admin'),
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(
              'Admin: IntelliQueue Admin Portal → Manage Customers → Reset password → Save.',
              style: TextStyle(fontSize: 12.sp, color: Colors.blue.shade900, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
