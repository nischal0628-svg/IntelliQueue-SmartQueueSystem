import 'package:flutter/material.dart';

class TokenDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> token;
  const TokenDetailsDialog({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    String v(String key) => (token[key] ?? '-').toString();

    return AlertDialog(
      title: Text('Token ${v('tokenNumber')}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row('User', v('userPhone')),
              _row('Type', v('tokenType')),
              _row('Status', v('status')),
              _row('Service', v('serviceName')),
              _row('Branch', v('branchName')),
              _row('Serving Counter', v('servingCounterId')),
              _row('Created', v('createdAt')),
              _row('Updated', v('updatedAt')),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _row('Booking ID', v('bookingId')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

