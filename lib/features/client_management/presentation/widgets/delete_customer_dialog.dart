import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DeleteCustomerDialog extends StatefulWidget {
  final String customerSno;
  final String customerName;

  const DeleteCustomerDialog({super.key, required this.customerSno, required this.customerName});

  @override
  State<DeleteCustomerDialog> createState() => _DeleteCustomerDialogState();
}

class _DeleteCustomerDialogState extends State<DeleteCustomerDialog> {
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _deleteCustomer() async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/DeleteCust'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          "ClientId": clientId,
          "Sno": int.parse(widget.customerSno),
          "DB": db
        }),
      );

      if (response.statusCode == 200) {
        final String result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result == '1') {
          if (!mounted) return;
          Navigator.pop(context, true);
        } else if (result == '2') {
          setState(() => _errorMessage = "This customer has existing call records and cannot be deleted.");
        } else {
          setState(() => _errorMessage = "Failed to delete customer. Please try again.");
        }
      } else {
        setState(() => _errorMessage = "Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _errorMessage = "Network error. Check your connection.");
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 28),
          const SizedBox(width: 8),
          const Text('Delete Customer', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Are you sure you want to delete ${widget.customerName}?'),
          const SizedBox(height: 8),
          const Text('This action cannot be undone.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ]
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        _isDeleting
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
            : ElevatedButton(
                onPressed: _deleteCustomer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
      ],
    );
  }
}
