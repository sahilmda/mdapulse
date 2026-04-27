// File: lib/features/client_management/presentation/screens/customer_detail_screen.dart

import 'package:flutter/material.dart';
import '../../data/models/activity_model.dart'; // Imports pure data structures

// Custom brand color
const Color mdaPrimaryBlue = Color(0xFF0257E6);

class CustomerDetailScreen extends StatelessWidget {
  final String contactName;
  final String orgName;
  final String status;

  CustomerDetailScreen({
    super.key,
    required this.contactName,
    required this.orgName,
    required this.status,
  });

  // Mock data mapping (Later, this will come from your Repository/Web Services)
  final List<ActivityLog> _logs = [
    ActivityLog(
      activityType: 'Complaint',
      executive: 'Faizi',
      nextDate: '10-04-2026',
      statusBadge: 'Inquiry',
      progress: 'Ongoing',
      remarks: [
        ActivityRemark(
          date: '09-04-2026',
          remarkText: 'new remark add',
          status: 'Inquiry',
        ),
        ActivityRemark(
          date: '09-04-2026',
          remarkText: '09-04-2026 --- remark add succesfully',
          status: 'Inquiry',
        ),
      ],
    ),
    ActivityLog(
      activityType: 'Sale',
      executive: 'Admin',
      nextDate: '--',
      statusBadge: 'Work Done',
      progress: 'Close',
      remarks: [],
    ),
    ActivityLog(
      activityType: 'Complaint',
      executive: 'Mudit',
      nextDate: '09-04-2026',
      statusBadge: 'Inquiry',
      progress: 'Ongoing',
      remarks: [],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Customer Detail',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 16.0,
            ),
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Ticket'),
              style: ElevatedButton.styleFrom(
                backgroundColor: mdaPrimaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Static Header Information
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Viewing history for : $contactName',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber[400],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '( ID : 24 )',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Products : product2, floated veneer, Audit tool, Producta',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.black12),

          // 2. Scrollable Expandable Activity Feed
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return HistoryCard(log: _logs[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CUSTOM EXPANDABLE CARD WIDGET
// ==========================================
class HistoryCard extends StatefulWidget {
  final ActivityLog log;

  const HistoryCard({super.key, required this.log});

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bool hasRemarks = widget.log.remarks.isNotEmpty;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // MAIN ROW (Always visible, tap to expand)
          InkWell(
            onTap: hasRemarks
                ? () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasRemarks
                                ? (_isExpanded
                                      ? Icons.arrow_drop_down
                                      : Icons.play_arrow)
                                : Icons.play_arrow_outlined,
                            color: hasRemarks
                                ? (_isExpanded ? Colors.red : Colors.grey[700])
                                : Colors.grey[300],
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.log.activityType,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.log.statusBadge == 'Work Done'
                              ? Colors.green[100]
                              : Colors.amber[400],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.log.statusBadge,
                          style: TextStyle(
                            color: widget.log.statusBadge == 'Work Done'
                                ? Colors.green[800]
                                : Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _iconText(
                            Icons.person,
                            'Exec: ${widget.log.executive}',
                          ),
                          const SizedBox(height: 6),
                          _iconText(
                            Icons.calendar_today,
                            'Next Date: ${widget.log.nextDate}',
                          ),
                          const SizedBox(height: 6),
                          _iconText(
                            Icons.sync,
                            'State: ${widget.log.progress}',
                          ),
                        ],
                      ),
                      if (widget.log.progress == 'Ongoing')
                        Container(
                          decoration: BoxDecoration(
                            color: mdaPrimaryBlue.withOpacity(
                              0.1,
                            ), // Custom branded faint background
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.phone,
                              color: mdaPrimaryBlue,
                              size: 20,
                            ), // Branded icon color
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // NESTED REMARKS TABLE (Visible only when expanded)
          if (_isExpanded && hasRemarks)
            Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.only(
                left: 48.0,
                right: 16.0,
                top: 16.0,
                bottom: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Date',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          'Remark',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Status',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  ...widget.log.remarks.map(
                    (remark) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              remark.date,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Text(
                              remark.remarkText,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              remark.status,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 13,
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
        ],
      ),
    );
  }

  Widget _iconText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: Colors.grey[800], fontSize: 14)),
      ],
    );
  }
}
