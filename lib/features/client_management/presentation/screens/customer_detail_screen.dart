// File: lib/features/client_management/presentation/screens/customer_detail_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/activity_model.dart';
import '../widgets/executive_task_entry_dialog.dart' show ExecutiveTaskEntryDialog;
import '../widgets/add_ticket_dialog.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class CustomerDetailScreen extends StatefulWidget {
  final String customerSno;
  final String contactName;
  final String orgName;
  final String status;
  final String mobileNo;

  const CustomerDetailScreen({
    super.key,
    required this.customerSno,
    required this.contactName,
    required this.orgName,
    required this.status,
    required this.mobileNo,
  });

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  String _displayName = '';
  String _products = '';
  String _mobileNo = '';
  String _prosCust = 'false';   // cols[12] from Customer_Detail fillList
  bool _isApprovalPending = false; // cols[32]
  String _custId11 = '';            // cols[18] — MDA customer ID
  List<ActivityLog> _logs = [];

  int _currentPage = 1;
  static const int _entriesPerPage = 10;

  List<ActivityLog> get _paginatedLogs {
    final start = (_currentPage - 1) * _entriesPerPage;
    final end = (start + _entriesPerPage).clamp(0, _logs.length);
    return _logs.sublist(start, end);
  }

  int get _totalPages => (_logs.length / _entriesPerPage).ceil().clamp(1, 9999);

  @override
  void initState() {
    super.initState();
    _displayName = widget.contactName;
    _mobileNo = widget.mobileNo;
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer_Detail.aspx/fillList'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "Type": "CD", "sno": widget.customerSno, "DB": db}),
      );

      if (response.statusCode == 200) {
        final String raw = jsonDecode(response.body)['d']?.toString() ?? '';
        if (raw.isNotEmpty && !raw.startsWith('Something')) {
          _parseAndSet(raw);
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() { _errorMessage = 'Server error ${response.statusCode}'; _isLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _errorMessage = 'Network error. Check your connection.'; _isLoading = false; });
    }
  }

  void _parseAndSet(String raw) {
    // Column layout from Customer_Detail.aspx fillList (Type="CD"):
    // [0]P_14.sno [1]P_14.custiD [2]u_id [3]Activity(StatName)
    // [4]CustName [5]UName(exec) [6]NdateOnly [7]Status(badge)
    // [8]Call_CL_PN [9]CDateOnly(remark date) [10]Remark1(remark text)
    // [11]Status15(remark status) [12]Pros_Cust [13]CustID_11
    // [14]Remarks_11 [15]MobileNo [16]UCode_13 [17]sno_11
    // [18]CustID11 [19]Product [20]Cata
    // Each # row = one P_15 remark for one P_14 call (LEFT JOIN).

    final Map<String, Map<String, dynamic>> callsMap = {};
    final List<String> callOrder = [];
    final Set<String> productsSet = {};
    bool headerExtracted = false;

    for (final row in raw.split('#')) {
      if (row.trim().isEmpty) continue;
      final cols = row.split('^');
      if (cols.length < 20) continue;

      final String callSno = cols[0].trim();
      if (callSno.isEmpty) continue;

      if (!headerExtracted) {
        final String custName = cols[4].trim();
        if (custName.isNotEmpty) _displayName = custName;
        final String mob = cols[15].trim();
        if (mob.isNotEmpty) _mobileNo = mob;
        _prosCust = cols[12].trim();
        _custId11 = cols[18].trim();
        _isApprovalPending = cols.length > 32 && cols[32].trim().toLowerCase() == 'true';
        headerExtracted = true;
      }

      final String product = cols[19].trim();
      if (product.isNotEmpty) {
        for (final p in product.split(',')) {
          final t = p.trim();
          if (t.isNotEmpty) productsSet.add(t);
        }
      }

      if (!callsMap.containsKey(callSno)) {
        callOrder.add(callSno);
        callsMap[callSno] = {
          'activity': cols[3].trim(),
          'executive': cols[5].trim(),
          'nextDate': cols[6].trim().isEmpty ? '--' : cols[6].trim(),
          'status': cols[7].trim(),
          'progress': cols[8].trim(),
          'uid': cols[2].trim(),
          'product': product,
          'remarks': <Map<String, String>>[],
        };
      }

      final String remarkDate = cols[9].trim();
      final String remarkText = cols[10].trim();
      final String remarkStatus = cols[11].trim();
      if (remarkDate.isNotEmpty || remarkText.isNotEmpty) {
        (callsMap[callSno]!['remarks'] as List<Map<String, String>>).add({
          'date': remarkDate,
          'text': remarkText,
          'status': remarkStatus,
        });
      }
    }

    final List<ActivityLog> logs = callOrder.map((sno) {
      final call = callsMap[sno]!;
      final remarks = (call['remarks'] as List<Map<String, String>>)
          .map((r) => ActivityRemark(date: r['date']!, remarkText: r['text']!, status: r['status']!))
          .toList();
      return ActivityLog(
        activityType: call['activity'] as String,
        executive: call['executive'] as String,
        nextDate: call['nextDate'] as String,
        statusBadge: call['status'] as String,
        progress: call['progress'] as String,
        remarks: remarks,
        sno: sno,
        uid: call['uid'] as String,
        product: call['product'] as String,
      );
    }).toList();

    if (mounted) {
      setState(() {
        _logs = logs;
        _products = productsSet.join(', ');
        _currentPage = 1;
        _isLoading = false;
      });
    }
  }

  void _showUpdateCallDialog(ActivityLog log) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExecutiveTaskEntryDialog(
        log: log,
        displayName: _displayName,
        mobileNo: _mobileNo,
        customerSno: widget.customerSno,
        custId11: _custId11,
        prosCust: _prosCust,
        onSaved: () {
          setState(() { _isLoading = true; _logs = []; });
          _fetchHistory();
        },
      ),
    );
  }

  Widget _buildPaginationFooter(ColorScheme cs) {
    final int totalEntries = _logs.length;
    final int start = (_currentPage - 1) * _entriesPerPage + 1;
    final int end = (start + _entriesPerPage - 1).clamp(1, totalEntries);
    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $start–$end of $totalEntries',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 22,
              ),
              const SizedBox(width: 4),
              Text('$_currentPage / $_totalPages', style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < _totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Detail', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AddTicketDialog(
                    customerSno: widget.customerSno,
                    customerName: _displayName.isNotEmpty ? _displayName : widget.contactName,
                    mobileNumber: _mobileNo.isNotEmpty ? _mobileNo : widget.mobileNo,
                    prosCust: _prosCust,
                  ),
                ).then((saved) {
                  if (saved == true && mounted) {
                    setState(() { _isLoading = true; _logs = []; });
                    _fetchHistory();
                  }
                });
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Ticket'),
              style: ElevatedButton.styleFrom(
                backgroundColor: mdaPrimaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: cs.surface,
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text('Viewing history for : $_displayName',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    if (widget.status.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.amber[400], borderRadius: BorderRadius.circular(6)),
                        child: Text(widget.status, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text('( ID : ${widget.customerSno} )', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                if (_products.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Products : $_products', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
                ],
                if (_isApprovalPending) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      border: Border.all(color: const Color(0xFFFF9800)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_filled, size: 14, color: Color(0xFFE65100)),
                        SizedBox(width: 5),
                        Text('Approval Pending', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: mdaPrimaryBlue))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: () { setState(() { _isLoading = true; _errorMessage = null; }); _fetchHistory(); },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _logs.isEmpty
                        ? Center(child: Text('No call history found.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)))
                        : Column(
                            children: [
                              Expanded(
                                child: RefreshIndicator(
                                  color: mdaPrimaryBlue,
                                  onRefresh: () async { setState(() { _isLoading = true; _logs = []; }); await _fetchHistory(); },
                                  child: ListView.builder(
                                    padding: const EdgeInsets.all(16.0),
                                    itemCount: _paginatedLogs.length,
                                    itemBuilder: (context, index) {
                                      final log = _paginatedLogs[index];
                                      return HistoryCard(
                                        log: log,
                                        onPhoneTap: () => _showUpdateCallDialog(log),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              _buildPaginationFooter(cs),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// HistoryCard
// ─────────────────────────────────────────────────────────

class HistoryCard extends StatefulWidget {
  final ActivityLog log;
  final VoidCallback? onPhoneTap;
  const HistoryCard({super.key, required this.log, this.onPhoneTap});

  @override
  State<HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<HistoryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool hasRemarks = widget.log.remarks.isNotEmpty;
    final bool isClose = widget.log.progress == 'Close';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: hasRemarks ? () => setState(() => _isExpanded = !_isExpanded) : null,
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
                                ? (_isExpanded ? Icons.arrow_drop_down : Icons.play_arrow)
                                : Icons.play_arrow_outlined,
                            color: hasRemarks
                                ? (_isExpanded ? Colors.red : cs.onSurfaceVariant)
                                : cs.outline,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.log.activityType.isNotEmpty ? widget.log.activityType : 'Activity',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      if (widget.log.statusBadge.isNotEmpty)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isClose ? Colors.green[100] : Colors.amber[400],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.log.statusBadge,
                              style: TextStyle(
                                color: isClose ? Colors.green[800] : Colors.black87,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(height: 1)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _iconText(context, Icons.person, 'Exec: ${widget.log.executive.isNotEmpty ? widget.log.executive : "—"}'),
                          const SizedBox(height: 6),
                          _iconText(context, Icons.calendar_today, 'Next Date: ${widget.log.nextDate}'),
                          const SizedBox(height: 6),
                          _iconText(context, Icons.sync, 'State: ${widget.log.progress.isNotEmpty ? widget.log.progress : "—"}'),
                          if (!isClose) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                border: Border.all(color: const Color(0xFFFF9800)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.access_time_filled, size: 12, color: Color(0xFFE65100)),
                                  SizedBox(width: 4),
                                  Text('Approval Pending',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (!isClose)
                        Container(
                          decoration: BoxDecoration(
                            color: mdaPrimaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: widget.onPhoneTap,
                            icon: const Icon(Icons.phone, color: mdaPrimaryBlue, size: 20),
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
          if (_isExpanded && hasRemarks)
            Container(
              color: cs.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outline.withValues(alpha: 0.45)),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Table(
                  border: TableBorder.symmetric(
                    inside: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(2.5),
                    1: FlexColumnWidth(4),
                    2: FlexColumnWidth(2),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: mdaPrimaryBlue.withValues(alpha: 0.08)),
                      children: [
                        _tableCell('Date', isHeader: true, cs: cs),
                        _tableCell('Remark', isHeader: true, cs: cs),
                        _tableCell('Status', isHeader: true, cs: cs, align: TextAlign.center),
                      ],
                    ),
                    ...widget.log.remarks.asMap().entries.map(
                      (entry) {
                        final remark = entry.value;
                        final bool isEven = entry.key.isEven;
                        return TableRow(
                          decoration: BoxDecoration(
                            color: isEven ? cs.surface : cs.surfaceContainerHighest,
                          ),
                          children: [
                            _tableCell(remark.date, cs: cs),
                            _tableCell(remark.remarkText, cs: cs),
                            _tableCell(remark.status, cs: cs, align: TextAlign.center),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconText(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
      ],
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, required ColorScheme cs, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
          color: isHeader ? cs.onSurface : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

