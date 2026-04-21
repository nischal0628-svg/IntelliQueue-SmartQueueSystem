import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intelliqueue/local_auth/local_auth.dart';
import 'package:intelliqueue/ui/app_colors.dart';
import 'package:intelliqueue/ui/app_scaffold_actions.dart';

class SendFeedbackPage extends StatefulWidget {
  const SendFeedbackPage({super.key});

  @override
  State<SendFeedbackPage> createState() => _SendFeedbackPageState();
}

class _SendFeedbackPageState extends State<SendFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _category = 'suggestion';
  int? _rating;
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String? _validateMessage(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Message is required';
    if (value.length < 5) return 'Please write a bit more';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final result = await LocalAuth.submitFeedback(
      category: _category,
      message: _messageController.text,
      rating: _rating,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Failed to send feedback')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feedback saved. Thank you!')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Send Feedback'),
        actions: AppScaffoldActions.actions(context),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8.h),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    items: const [
                      DropdownMenuItem(value: 'bug', child: Text('Bug')),
                      DropdownMenuItem(value: 'suggestion', child: Text('Suggestion')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? 'suggestion'),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'Message',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: _messageController,
                    validator: _validateMessage,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write your feedback here...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                    ),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'Rating (optional)',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      final selected = (_rating ?? 0) >= star;
                      return IconButton(
                        onPressed: () => setState(() => _rating = star),
                        icon: Icon(
                          selected ? Icons.star : Icons.star_border,
                          color: selected ? Colors.amber.shade700 : Colors.grey.shade500,
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Feedback is stored locally on this device.',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.headerBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Submit',
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
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

