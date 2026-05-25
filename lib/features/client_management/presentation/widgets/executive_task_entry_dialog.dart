// File: lib/features/client_management/presentation/widgets/executive_task_entry_dialog.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/activity_model.dart';

const Color _blue = Color(0xFF0257E6);
const Color _cream = Color(0xFFFFF9EE);

// Wide layout threshold: >= 640 logical pixels in the dialog body
const double _wideBreakpoint = 640;

class ExecutiveTaskEntryDialog extends StatefulWidget {
  final ActivityLog log;
  final String displayName;
  final String mobileNo;
  final String customerSno;
  final VoidCallback onSaved;
  final String prosCust;
  /// When true the footer shows green Accept + red Reject instead of Cancel + Update.
  final bool isApprovalMode;
  /// When true the task is awaiting admin approval — hide the Team Member section.
  final bool isApprovalPending;
  /// MDA customer ID (CustID11) — used only when ClientId == 'MDA' to load firm detail.
  final String custId11;

  const ExecutiveTaskEntryDialog({
    super.key,
    required this.log,
    required this.displayName,
    required this.mobileNo,
    required this.customerSno,
    required this.onSaved,
    this.prosCust = 'false',
    this.isApprovalMode = false,
    this.isApprovalPending = false,
    this.custId11 = '',
  });

  @override
  State<ExecutiveTaskEntryDialog> createState() => _ExecutiveTaskEntryDialogState();
}

class _ExecutiveTaskEntryDialogState extends State<ExecutiveTaskEntryDialog> {
  final TextEditingController _remarkCtrl = TextEditingController();
  final TextEditingController _afterDaysCtrl = TextEditingController(text: '1');
  final TextEditingController _customerRemarkCtrl = TextEditingController();
  final TextEditingController _callRemarkHistoryCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  String _callType = 'Call';
  String _callPending = 'Pending';
  DateTime _currentDate = DateTime.now();
  TimeOfDay _currentTime = TimeOfDay.now();
  String? _selectedStatus;
  List<String> _originalProducts = [];
  List<String> _additionalProducts = [];

  String _nextCallType = 'Call';
  DateTime _nextDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _nextTime = const TimeOfDay(hour: 10, minute: 0);
  int _afterDays = 1;

  String _city = '';
  List<String> _pendingStatuses = [];
  List<String> _closeStatuses = [];
  List<String> _products = [];

  List<Map<String, String>> _teamMembers = [];
  String? _selectedTeamMember;
  bool _showTeamMember = false;
  bool _isLoadingTeamMembers = false;
  int _proToCust = 0;
  bool _showCustomerId = false;
  final TextEditingController _customerIdController = TextEditingController();

  bool _isMdaClient = false;
  String _clientId = '';
  String _db = '';

  // ── Lifecycle ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _callPending = widget.log.progress == 'Close' ? 'Close' : 'Pending';
    _selectedStatus = widget.log.statusBadge.isNotEmpty ? widget.log.statusBadge : null;
    _nextDate = _parseDate(widget.log.nextDate);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _afterDays = _nextDate.difference(today).inDays.clamp(0, 9999);
    _afterDaysCtrl.text = _afterDays.toString();
    // Default next time to current time so it feels natural
    _nextTime = _currentTime;
    _fetchData();
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    _afterDaysCtrl.dispose();
    _customerRemarkCtrl.dispose();
    _callRemarkHistoryCtrl.dispose();
    _customerIdController.dispose();
    super.dispose();
  }

  // ── API ──────────────────────────────────────────────────────────────

  DateTime _parseDate(String s) {
    if (s == '--' || s.isEmpty) return DateTime.now().add(const Duration(days: 1));
    try {
      // Match DD-MM-YYYY anywhere in the string (handles suffixes like " - C")
      final m = RegExp(r'(\d{2})-(\d{2})-(\d{4})').firstMatch(s);
      if (m != null) {
        return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!));
      }
    } catch (_) {}
    return DateTime.now().add(const Duration(days: 1));
  }

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      final String sno7 = prefs.getString('sno') ?? '0';
      final String ucode7 = prefs.getString('UCode') ?? '0';
      final int custId = int.tryParse(widget.customerSno) ?? 0;
      if (mounted) setState(() { _clientId = clientId; _db = db; _isMdaClient = clientId.toUpperCase() == 'MDA'; });

      final responses = await Future.wait([
        http.post(
          Uri.parse('https://webservices.mdapulse.com/Calling.aspx/FillEditModal'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            "ClientId": clientId,
            "sno_14": int.tryParse(widget.log.sno) ?? 0,
            "CustID": widget.customerSno,
            "u_id": widget.log.uid,
            "DB": db,
            "sno_7": sno7,
            "UCode_7": ucode7,
          }),
        ),
        http.post(
          Uri.parse('https://webservices.mdapulse.com/Calling.aspx/Fill_DropDown'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({"ClientId": clientId, "Type": "Pending", "CustID": custId, "DB": db}),
        ),
        http.post(
          Uri.parse('https://webservices.mdapulse.com/Calling.aspx/Fill_DropDown'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({"ClientId": clientId, "Type": "Close", "CustID": custId, "DB": db}),
        ),
        http.post(
          Uri.parse('https://webservices.mdapulse.com/Calling.aspx/Fill_DropDown'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({"ClientId": clientId, "Type": "Product", "CustID": custId, "DB": db}),
        ),
      ]);

      if (!mounted) return;

      debugPrint('[FillEditModal] status=${responses[0].statusCode} body=${responses[0].body}');

      final String modalRaw = jsonDecode(responses[0].body)['d']?.toString() ?? '';
      // Temporary locals so all state is applied in one setState call
      String city = '';
      String callType = 'Call';
      String remarkHistory = '';
      List<String> origProducts = [];
      String? status;
      String callPending = 'Pending';
      String nextCallType = 'Call';
      String? teamMember;
      String custRemark = '';
      String nextDateStr = '';

      if (modalRaw.isNotEmpty && !modalRaw.startsWith('Something')) {
        final parts = modalRaw.split('#')[0].split('^');
        // Debug: log all parts to identify correct indices
        for (int i = 0; i < parts.length; i++) {
          debugPrint('[FillEditModal] parts[$i] = "${parts[i].trim()}"');
        }

        if (parts.length > 16) {
          city      = parts[4].trim();
          callType  = parts[7].trim() == 'Visit' ? 'Visit' : 'Call';
          remarkHistory = parts[8].trim();
          if (parts[9].trim().isNotEmpty) {
            origProducts = parts[9].trim().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          }
          if (parts[10].trim().isNotEmpty) status = parts[10].trim();
          callPending   = parts[12].trim() == 'Close' ? 'Close' : 'Pending';
          if (parts.length > 13) nextDateStr = parts[13].trim();
          nextCallType  = parts[14].trim() == 'Visit' ? 'Visit' : 'Call';
          if (parts[15].trim().isNotEmpty) teamMember = parts[15].trim();
          custRemark    = parts[16].trim();

          // _currentDate stays as DateTime.now() — the Date field records today's call.
        }
      }

      // _nextDate and _afterDays come from initState (widget.log.nextDate) — not overridden here

      List<String> parseDropdown(http.Response r) {
        final raw = jsonDecode(r.body)['d']?.toString() ?? '';
        if (raw.isEmpty || raw.startsWith('Something')) return [];
        return raw
            .split('#')
            .where((row) => row.contains('~'))
            .map((row) => row.split('~')[0].trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }

      final pendingSt = parseDropdown(responses[1]);
      final closeSt = parseDropdown(responses[2]);
      final prods = parseDropdown(responses[3]);

      setState(() {
        // Modal fields
        _city            = city;
        _callType        = callType;
        _originalProducts = origProducts;
        _additionalProducts = [];
        if (status != null) _selectedStatus = status;
        _callPending     = callPending;
        _nextCallType    = nextCallType;
        if (teamMember != null) _selectedTeamMember = teamMember;
        _customerRemarkCtrl.text = custRemark;
        _callRemarkHistoryCtrl.text = remarkHistory;

        // Next visit date: override from FillEditModal parts[13] if available
        if (nextDateStr.isNotEmpty && nextDateStr != '--') {
          final nd = _parseDate(nextDateStr);
          if (nd.year > 2000) {
            _nextDate = nd;
            final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            _afterDays = _nextDate.difference(today).inDays.clamp(0, 9999);
            _afterDaysCtrl.text = _afterDays.toString();
          }
        }

        // Dropdowns
        _pendingStatuses = pendingSt;
        _closeStatuses   = closeSt;
        _products        = prods;

        final currentList = _callPending == 'Pending' ? _pendingStatuses : _closeStatuses;
        if (_selectedStatus == null || !currentList.contains(_selectedStatus)) {
          _selectedStatus = currentList.isNotEmpty ? currentList[0] : null;
        }
        _additionalProducts = _additionalProducts.where((p) => _products.contains(p)).toList();
        _isLoading = false;
      });

      if (_selectedStatus != null) {
        if (_callPending == 'Pending') {
          _fetchTeamMembers(_selectedStatus!);
        } else {
          _fetchCloseTimeCheck(_selectedStatus!);
        }
      }
    } catch (e) {
      debugPrint('[ExecutiveDialog._fetchData] error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Pending / Close web-service helpers ─────────────────────────────

  Future<void> _fetchTeamMembers(String statusVal) async {
    // Team member assignment only happens after admin approval — never for pending-approval tasks.
    if (widget.isApprovalPending) return;
    setState(() { _isLoadingTeamMembers = true; _showTeamMember = false; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Calling.aspx/chkAtPendingTime'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': prefs.getString('CLIENTID') ?? 'Demo',
          'val': statusVal,
          'DB': prefs.getString('D_Database') ?? 'mdapulse',
        }),
      );
      if (!mounted) return;
      final result = jsonDecode(response.body)['d']?.toString() ?? '';
      if (result.contains('~')) {
        final members = result
            .split('#')
            .where((s) => s.contains('~'))
            .map((s) {
              final p = s.split('~');
              return {'val': p[0].trim(), 'text': p.length > 1 ? p[1].trim() : p[0].trim()};
            })
            .where((m) => m['val']!.isNotEmpty)
            .toList();
        setState(() {
          _teamMembers = members;
          // Keep existing SubExCode if valid, otherwise default to first member
          final existingValid = members.any((m) => m['val'] == _selectedTeamMember);
          if (!existingValid) _selectedTeamMember = members.isNotEmpty ? members[0]['val'] : null;
          _showTeamMember = true;
          _isLoadingTeamMembers = false;
        });
      } else {
        setState(() {
          _teamMembers = [];
          _selectedTeamMember = null;
          _showTeamMember = false;
          _isLoadingTeamMembers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTeamMembers = false);
    }
  }

  void _clearTeamMembers() {
    _teamMembers = [];
    _selectedTeamMember = null;
    _showTeamMember = false;
    _isLoadingTeamMembers = false;
  }

  Future<void> _fetchCloseTimeCheck(String statusVal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Calling.aspx/chkAtCloseTime'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': prefs.getString('CLIENTID') ?? 'Demo',
          'val': statusVal,
          'DB': prefs.getString('D_Database') ?? 'mdapulse',
        }),
      );
      if (!mounted) return;
      final result = jsonDecode(response.body)['d']?.toString() ?? '';
      final saleReject = result.split('#').first.split('~').elementAtOrNull(1)?.trim() ?? '';
      if (saleReject == 'Sale') {
        final alreadyCustomer = widget.prosCust.toLowerCase() == 'true';
        setState(() {
          _proToCust      = alreadyCustomer ? 0 : 1;
          _showCustomerId = !alreadyCustomer;
          if (alreadyCustomer) _customerIdController.clear();
        });
      } else {
        setState(() { _proToCust = 0; _showCustomerId = false; _customerIdController.clear(); });
      }
    } catch (_) {
      if (mounted) setState(() { _proToCust = 0; _showCustomerId = false; _customerIdController.clear(); });
    }
  }

  void _clearCloseFields() {
    _proToCust = 0;
    _showCustomerId = false;
    _customerIdController.clear();
  }

  // ── Formatting ───────────────────────────────────────────────────────

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';

  String _fmtAMPM(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} $period';
  }

  String _apiTime(TimeOfDay t) {
    final period = t.hour >= 12 ? 'PM' : 'AM';
    int h = t.hour % 12;
    if (h == 0) h = 12;
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
  }

  void _recalcNextDate() =>
      setState(() => _nextDate = DateTime.now().add(Duration(days: _afterDays)));

  List<String> get _currentStatuses =>
      _callPending == 'Pending' ? _pendingStatuses : _closeStatuses;

  // ── Save ─────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final String rawRemark = _remarkCtrl.text.trim();
    if (rawRemark.isEmpty) {
      setState(() => _errorMessage = 'Please enter a remark.');
      return;
    }
    if (_selectedStatus == null) {
      setState(() => _errorMessage = 'Please select a status.');
      return;
    }
    setState(() { _isSaving = true; _errorMessage = null; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      final String ucode = prefs.getString('UCode') ?? '1';

      final String datetxt = _formatDate(_currentDate);
      final String timetxt = _apiTime(_currentTime);
      final String ndate = _callPending == 'Pending' ? _formatDate(_nextDate) : '';
      final String ntime = _callPending == 'Pending' ? _apiTime(_nextTime) : '';

      final String newRemark = '$datetxt --- $rawRemark';
      final String oldRemark = _callRemarkHistoryCtrl.text.trim();
      final String combinedOldRemark = oldRemark.isNotEmpty
          ? '$oldRemark\r\n$newRemark'
          : newRemark;

      final String rdata = [
        widget.log.sno,
        widget.customerSno,
        widget.log.uid,
        widget.displayName,
        _callType,
        datetxt,
        timetxt,
        _callPending,
        _selectedStatus!,
        [
          ..._originalProducts,
          ..._additionalProducts.where((p) =>
              !_originalProducts.map((o) => o.toLowerCase()).contains(p.toLowerCase())),
        ].join(','),
        newRemark,
        '',
        ndate,
        ntime,
        combinedOldRemark,
        _nextCallType,
        _customerIdController.text.trim(),   // [16] CustIDProsTOCust
        _selectedTeamMember ?? '0',          // [17] TeamMemberCode
        _teamMembers.firstWhere((m) => m['val'] == _selectedTeamMember, orElse: () => {'text': ''})['text'] ?? '',  // [18] TeamMemberName
      ].join('^');

      debugPrint('[Update_Call] rdata=$rdata');

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Calling.aspx/Update_Call'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          // Force English culture on the server so DateTime.ParseExact("hh:mm tt")
          // correctly recognises "AM"/"PM" regardless of the server's default locale.
          'Accept-Language': 'en-US',
        },
        body: jsonEncode({
          'ClientId': clientId,
          'Rdata': rdata,
          'ucode': ucode,
          'DB': db,
          'ProTOcust': _proToCust,
          'sno_11': int.tryParse(widget.customerSno) ?? 0,
        }),
      );

      debugPrint('[Update_Call] status=${response.statusCode} body=${response.body}');

      if (response.statusCode == 200) {
        final String result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result == '1') {
          if (mounted) Navigator.pop(context);
          widget.onSaved();
        } else {
          setState(() {
            _isSaving = false;
            _errorMessage = 'Save failed: $result'
                '\nDate: $datetxt  Time: $timetxt'
                '\nSno: ${widget.log.sno}  CustSno: ${widget.customerSno}'
                '\nStatus: ${_selectedStatus ?? "-"}';
          });
        }
      } else {
        setState(() { _isSaving = false; _errorMessage = 'Server error ${response.statusCode}'; });
      }
    } catch (e) {
      debugPrint('[Update_Call] dart error: $e');
      setState(() { _isSaving = false; _errorMessage = 'Network error. Check your connection.'; });
    }
  }

  // ── Root build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final String initial =
        widget.displayName.isNotEmpty ? widget.displayName[0].toUpperCase() : '?';

    return Dialog(
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1100,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildSubHeader(initial),
            const Divider(height: 1, thickness: 1),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator(color: _blue)),
              )
            else
              Expanded(
                // LayoutBuilder decides between 3-column and 1-column layout
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= _wideBreakpoint) {
                      return _wideBody();
                    } else {
                      return _narrowBody();
                    }
                  },
                ),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Wide layout (>= 640px): 3 equal columns ──────────────────────────

  Widget _wideBody() => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _callDetailsCard()),
            const SizedBox(width: 12),
            Expanded(child: _nextVisitCard()),
            const SizedBox(width: 12),
            Expanded(child: _remarksCard()),
          ],
        ),
      );

  // ── Narrow layout (< 640px): single scrollable column ────────────────

  Widget _narrowBody() => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionCard(
              icon: Icons.phone_outlined,
              title: 'Call Details',
              child: _callDetailsContent(),
            ),
            const SizedBox(height: 12),
            if (_callPending == 'Pending') ...[
              _sectionCard(
                icon: Icons.calendar_today_outlined,
                title: 'Next Visit',
                child: _nextVisitContent(),
              ),
              const SizedBox(height: 12),
            ],
            _sectionCard(
              icon: Icons.person_outline,
              title: 'Customer Remarks',
              child: _remarksContent(narrow: true),
            ),
          ],
        ),
      );

  // ── Call Details (shared content) ────────────────────────────────────

  // Wraps a widget as read-only in approval mode: absorbs taps and dims it.
  Widget _maybeReadOnly(Widget child) => widget.isApprovalMode
      ? Opacity(opacity: 0.55, child: AbsorbPointer(child: child))
      : child;

  Widget _callDetailsContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lbl('Call Type'),
          const SizedBox(height: 8),
          _maybeReadOnly(
            _toggle(['Call', 'Visit'], _callType, (v) => setState(() => _callType = v),
                icons: [Icons.phone_outlined, Icons.location_on_outlined]),
          ),
          const SizedBox(height: 14),
          _maybeReadOnly(
            Row(children: [
              Expanded(child: _dateTile('Date', _formatDate(_currentDate), _pickCurrentDate)),
              const SizedBox(width: 8),
              Expanded(child: _timeTile('Time', _fmtAMPM(_currentTime), _pickCurrentTime)),
            ]),
          ),
          const SizedBox(height: 14),
          _lbl('Close / Ongoing'),
          const SizedBox(height: 8),
          _maybeReadOnly(
            _toggle(
              ['Closed', 'Ongoing'],
              _callPending == 'Pending' ? 'Ongoing' : 'Closed',
              (v) {
                final np = v == 'Ongoing' ? 'Pending' : 'Close';
                setState(() {
                  _callPending = np;
                  final list = np == 'Pending' ? _pendingStatuses : _closeStatuses;
                  if (_selectedStatus == null || !list.contains(_selectedStatus)) {
                    _selectedStatus = list.isNotEmpty ? list[0] : null;
                  }
                });
                if (_selectedStatus != null) {
                  if (np == 'Pending') {
                    setState(_clearCloseFields);
                    _fetchTeamMembers(_selectedStatus!);
                  } else {
                    setState(_clearTeamMembers);
                    _fetchCloseTimeCheck(_selectedStatus!);
                  }
                } else {
                  setState(() { _clearTeamMembers(); _clearCloseFields(); });
                }
              },
              icons: [Icons.check_circle_outline, Icons.access_time],
            ),
          ),
          const SizedBox(height: 14),
          _lbl('Status'),
          const SizedBox(height: 8),
          _maybeReadOnly(
            _dropdown(_currentStatuses, _selectedStatus, 'Select status', (v) {
              setState(() => _selectedStatus = v);
              if (v == null) {
                setState(() { _clearTeamMembers(); _clearCloseFields(); });
                return;
              }
              if (_callPending == 'Pending') {
                setState(_clearCloseFields);
                _fetchTeamMembers(v);
              } else {
                setState(_clearTeamMembers);
                _fetchCloseTimeCheck(v);
              }
            }),
          ),
          if (_isLoadingTeamMembers) ...[
            const SizedBox(height: 14),
            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _blue))),
          ],
          if (_showTeamMember && _teamMembers.isNotEmpty) ...[
            const SizedBox(height: 14),
            _lbl('Team Member'),
            const SizedBox(height: 8),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                _teamMembers.firstWhere(
                  (m) => m['val'] == _selectedTeamMember,
                  orElse: () => _teamMembers.first,
                )['text'] ?? '',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ),
          ],
          if (_showCustomerId) ...[
            const SizedBox(height: 14),
            _lbl('Customer ID'),
            const SizedBox(height: 8),
            TextField(
              controller: _customerIdController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDec('Enter Customer ID'),
            ),
          ],
          if (!widget.isApprovalMode) ...[
            const SizedBox(height: 14),
            _buildMultiSelectProduct(),
          ],
          const SizedBox(height: 14),
          _lbl('Remark'),
          const SizedBox(height: 8),
          TextField(
            controller: _remarkCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 13),
            decoration: _inputDec('Enter Your Remark...'),
          ),
        ],
      );

  Widget _buildMultiSelectProduct() {
    final originalLower = _originalProducts.map((p) => p.toLowerCase()).toSet();
    final availableNew = _products.where((p) => !originalLower.contains(p.toLowerCase())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Additional products — user can add/remove (existing products are not shown separately)
        _lbl('Additional Products'),
        const SizedBox(height: 8),
        InkWell(
          onTap: availableNew.isEmpty ? null : _showProductPicker,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _additionalProducts.isEmpty
                      ? Text(
                          'Products',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _additionalProducts.map((name) => Chip(
                            label: Text(name, style: const TextStyle(fontSize: 12, color: _blue)),
                            deleteIcon: const Icon(Icons.close, size: 14, color: _blue),
                            onDeleted: () => setState(() => _additionalProducts.remove(name)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: _blue.withValues(alpha: 0.1),
                            side: BorderSide.none,
                          )).toList(),
                        ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showProductPicker() async {
    final originalLower = _originalProducts.map((p) => p.toLowerCase()).toSet();
    final availableNew = _products.where((p) => !originalLower.contains(p.toLowerCase())).toList();
    final temp = List<String>.from(_additionalProducts);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Select Additional Products',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: availableNew.map((name) {
                final isSelected = temp.contains(name);
                return CheckboxListTile(
                  title: Text(name, style: const TextStyle(fontSize: 14)),
                  value: isSelected,
                  activeColor: _blue,
                  checkColor: Colors.white,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  onChanged: (v) => setDialog(() {
                    if (v == true) { temp.add(name); } else { temp.remove(name); }
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); setState(() => _additionalProducts = temp); },
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _callDetailsCard() => _scrollCard(
        icon: Icons.phone_outlined,
        title: 'Call Details',
        child: _callDetailsContent(),
      );

  Future<void> _pickCurrentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => _blueTheme(ctx, child!),
    );
    if (picked != null) setState(() => _currentDate = picked);
  }

  Future<void> _pickCurrentTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _currentTime,
      builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) setState(() => _currentTime = picked);
  }

  // ── Next Visit (shared content) ──────────────────────────────────────

  Widget _nextVisitContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lbl('Next Call Type'),
          const SizedBox(height: 8),
          _toggle(['Call', 'Visit'], _nextCallType, (v) => setState(() => _nextCallType = v),
              icons: [Icons.phone_outlined, Icons.location_on_outlined]),
          const SizedBox(height: 14),
          _lbl('After No. of Days'),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: TextField(
              controller: _afterDaysCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDec('1'),
              onChanged: (val) {
                final n = int.tryParse(val);
                if (n != null && n >= 0) { _afterDays = n; _recalcNextDate(); }
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _dateTile('Next Date', _formatDate(_nextDate), _pickNextDate)),
            const SizedBox(width: 8),
            Expanded(child: _timeTile('Next Time', _fmtAMPM(_nextTime), _pickNextTime)),
          ]),
        ],
      );

  Widget _nextVisitCard() {
    if (_callPending != 'Pending') {
      return _scrollCard(
        icon: Icons.calendar_today_outlined,
        title: 'Next Visit',
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Not required for closed calls.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ),
      );
    }
    return _scrollCard(
      icon: Icons.calendar_today_outlined,
      title: 'Next Visit',
      child: _nextVisitContent(),
    );
  }

  Future<void> _pickNextDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (ctx, child) => _blueTheme(ctx, child!),
    );
    if (picked != null) {
      setState(() {
        _nextDate = picked;
        _afterDays = _nextDate.difference(DateTime.now()).inDays + 1;
        _afterDaysCtrl.text = _afterDays.toString();
      });
    }
  }

  Future<void> _pickNextTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _nextTime,
      builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) setState(() => _nextTime = picked);
  }

  // ── Remarks (shared content) ─────────────────────────────────────────

  /// [narrow] = true → fixed-height text area; false → Expanded to fill card height
  Widget _remarksContent({bool narrow = false}) {
    final historyField = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: _callRemarkHistoryCtrl,
        readOnly: true,
        maxLines: narrow ? 6 : null,
        expands: !narrow,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(fontSize: 13, height: 1.5),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Call remark history...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          contentPadding: EdgeInsets.zero,
          isCollapsed: true,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Icon(Icons.person, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          const Text('Customer Remark',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _customerRemarkCtrl,
          readOnly: true,
          maxLines: 3,
          style: const TextStyle(fontSize: 13),
          decoration: _inputDecFilled('Customer remark...'),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Icon(Icons.phone_in_talk, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          const Text('Call Remark History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        if (narrow)
          historyField
        else
          Expanded(child: historyField),
      ],
    );
  }

  Widget _remarksCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: _remarksContent(narrow: false),
      );

  // ── MDA firm detail ─────────────────────────────────────────────────

  String _mdaFiscalYear() {
    final now = DateTime.now();
    final y = now.month >= 4 ? now.year : now.year - 1;
    return '${(y % 100).toString().padLeft(2, '0')}${((y + 1) % 100).toString().padLeft(2, '0')}';
  }

  Future<void> _showMdaFirmDetail() async {
    final custId11Int = int.tryParse(widget.custId11) ?? 0;
    final fiscalYear = _mdaFiscalYear();

    showDialog(
      context: context,
      builder: (ctx) => _MdaFirmDetailDialog(
        clientId: _clientId,
        db: _db,
        custId11: custId11Int,
        fiscalYear: fiscalYear,
      ),
    );
  }

  // ── Header / sub-header / footer ─────────────────────────────────────

  Widget _buildHeader() => Container(
        color: _blue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.headset_mic, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Executive Task Entry',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            if (_isMdaClient && widget.custId11.isNotEmpty) ...[
              InkWell(
                onTap: _showMdaFirmDetail,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.4))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.business, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('MDA', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
            ],
            InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      );

  Widget _buildSubHeader(String initial) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.displayName + (_city.isNotEmpty ? ' - $_city' : ''),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.phone, size: 13, color: Colors.grey),
                    if (widget.mobileNo.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(widget.mobileNo,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    if (widget.log.product.isNotEmpty) ...[
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text('|',
                              style: TextStyle(color: Colors.grey.shade400))),
                      const Icon(Icons.shopping_cart, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(widget.log.product,
                            style:
                                TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _actionBtn(
                label: 'H',
                color: const Color(0xFF17A2B8),
                onTap: _showHistoryDialog,
              ),
              const SizedBox(width: 6),
              _actionBtn(
                icon: Icons.phone,
                color: _blue,
                onTap: _launchPhone,
              ),
              const SizedBox(width: 6),
              _actionBtn(
                icon: Icons.chat,
                color: Colors.green.shade600,
                onTap: _launchWhatsApp,
              ),
            ]),
          ],
        ),
      );

  Widget _buildFooter() => Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: widget.isApprovalMode
              ? _approvalButtons()
              : _defaultButtons(),
        ),
      );

  List<Widget> _defaultButtons() => [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        _isSaving
            ? const SizedBox(
                width: 80, height: 36,
                child: Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2)))
            : ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Update',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
      ];

  List<Widget> _approvalButtons() => [
        ElevatedButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        const SizedBox(width: 12),
        _isSaving
            ? const SizedBox(
                width: 80, height: 36,
                child: Center(child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2)))
            : ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Accept',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
      ];

  // ── Card wrappers ─────────────────────────────────────────────────────

  /// Wide-layout card: content scrolls vertically inside bounded height.
  Widget _scrollCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: _blue, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: child,
              ),
            ),
          ],
        ),
      );

  /// Narrow-layout card: plain container, content determines height.
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: _blue, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );

  // ── Sub-header action buttons ─────────────────────────────────────────

  Widget _actionBtn({String? label, IconData? icon, required Color color, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: label != null
              ? Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))
              : Icon(icon, color: Colors.white, size: 18),
        ),
      );

  Future<void> _showHistoryDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString('CLIENTID') ?? '';
    final db       = prefs.getString('D_Database') ?? '';
    final callSno  = int.tryParse(widget.log.sno) ?? 0;
    final custId   = int.tryParse(widget.customerSno) ?? 0;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Container(
            color: const Color(0xFF17A2B8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              const Expanded(child: Text('Customer Call History',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ]),
          ),
          // Body
          Flexible(
            child: FutureBuilder<List<List<String>>>(
              future: _fetchHistory(clientId, db, callSno, custId),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
                }
                final rows = snap.data ?? [];
                if (rows.isEmpty) {
                  return const Padding(padding: EdgeInsets.all(32),
                      child: Center(child: Text('No history found.', style: TextStyle(color: Colors.grey))));
                }
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = rows[i];
                    final startDate  = r.isNotEmpty     ? r[0] : '';
                    final activity   = r.length > 1 ? r[1] : '';
                    final executive  = r.length > 2 ? r[2] : '';
                    final lastDate   = r.length > 3 ? r[3] : '';
                    final remark     = r.length > 4 ? r[4] : '';
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9EE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Row(children: [
                                const Icon(Icons.calendar_today, size: 13, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(startDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                if (lastDate.isNotEmpty) ...[
                                  const Text('  →  ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(lastDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ]),
                            ),
                            if (activity.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF17A2B8).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(activity,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF17A2B8), fontWeight: FontWeight.w600)),
                              ),
                          ]),
                          if (executive.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.person_outline, size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(child: Text(executive,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87))),
                            ]),
                          ],
                          if (remark.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.notes, size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(child: Text(remark,
                                  style: const TextStyle(fontSize: 12, color: Colors.black54))),
                            ]),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600], foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Close'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<List<List<String>>> _fetchHistory(String clientId, String db, int sno, int custId) async {
    try {
      final resp = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Calling.aspx/fillCustCallHistory'),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': clientId, 'DB': db, 'sno': sno, 'custID': custId}),
      );
      if (resp.statusCode != 200) return [];
      final raw = jsonDecode(resp.body)['d']?.toString() ?? '';
      if (raw.isEmpty || raw == '0' || raw.startsWith('Something')) return [];
      return raw.split('#')
          .where((r) => r.trim().isNotEmpty)
          .map((r) => r.split('^').map((f) => f.trim()).toList())
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _launchPhone() async {
    final number = widget.mobileNo.replaceAll(RegExp(r'\s+'), '');
    if (number.isEmpty) return;
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp() async {
    final number = widget.mobileNo.replaceAll(RegExp(r'[^\d]'), '');
    if (number.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── Shared helpers ────────────────────────────────────────────────────

  Widget _lbl(String text) =>
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold));

  Widget _toggle(
    List<String> options,
    String selected,
    ValueChanged<String> onChanged, {
    List<IconData>? icons,
  }) =>
      Row(
        children: options.asMap().entries.map((e) {
          final opt = e.value;
          final isLast = e.key == options.length - 1;
          final isActive = opt == selected;
          final icon = (icons != null && e.key < icons.length) ? icons[e.key] : null;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 8),
              child: InkWell(
                onTap: () => onChanged(opt),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isActive ? _blue : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isActive ? _blue : Colors.grey.shade300),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 15, color: isActive ? Colors.white : Colors.black87),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          opt,
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );

  Widget _dropdown(List<String> items, String? value, String hint,
      ValueChanged<String?>? onChanged) {
    final effective =
        items.contains(value) ? value : (items.isNotEmpty ? items[0] : null);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: effective,
          hint: Text(hint, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _dateTile(String label, String text, VoidCallback onTap) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.centerLeft,
              child: Text(text, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      );

  Widget _timeTile(String label, String text, VoidCallback onTap) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(children: [
                Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
              ]),
            ),
          ),
        ],
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _blue)),
      );

  InputDecoration _inputDecFilled(String hint) =>
      _inputDec(hint).copyWith(filled: true, fillColor: Colors.white);

  Widget _blueTheme(BuildContext ctx, Widget child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _blue)),
        child: child,
      );
}

// ─── MDA Firm Detail Dialog ───────────────────────────────────────────────────

class _MdaFirmDetailDialog extends StatefulWidget {
  final String clientId;
  final String db;
  final int custId11;
  final String fiscalYear;

  const _MdaFirmDetailDialog({
    required this.clientId,
    required this.db,
    required this.custId11,
    required this.fiscalYear,
  });

  @override
  State<_MdaFirmDetailDialog> createState() => _MdaFirmDetailDialogState();
}

class _MdaFirmDetailDialogState extends State<_MdaFirmDetailDialog>
    with SingleTickerProviderStateMixin {
  static const _headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'X-Requested-With': 'XMLHttpRequest',
    'Referer': 'https://mdapulse.com/Calling.aspx',
  };

  late final TabController _tabCtrl;
  bool _isLoading = true;
  String _error = '';

  // Firm info
  String _firmName = '', _firmCity = '', _contactPerson = '', _contactMobile = '', _executive = '';

  // Sections (raw rows)
  List<List<String>> _complaints = [];
  List<List<String>> _references = [];
  List<List<String>> _usage = [];
  List<List<String>> _software = [];

  // Billing
  bool _isBillingLoading = false;
  List<List<String>> _billing = [];
  late String _selectedBillingYear;

  @override
  void initState() {
    super.initState();
    _selectedBillingYear = widget.fiscalYear;
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.index == 4 && _billing.isEmpty && !_isBillingLoading) {
        _fetchBilling(_selectedBillingYear);
      }
    });
    _fetchFirmDetail();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchFirmDetail() async {
    try {
      final resp = await http.post(
        Uri.parse('https://mdapulse.com/Calling.aspx/fillMDACustFirmDetail'),
        headers: _headers,
        body: jsonEncode({'ClientId': widget.clientId, 'DB': widget.db, 'CustID11': widget.custId11}),
      );
      if (!mounted) return;
      final raw = jsonDecode(resp.body)['d']?.toString() ?? '';
      if (raw.isEmpty || !raw.contains('^')) {
        setState(() { _isLoading = false; _error = 'No data found for this customer.'; });
        return;
      }
      final sections = raw.split('~');
      // Section 0: FirmInfo — F_Name^F_City^C_Person^C_Mobile^ExecutiveName
      if (sections.isNotEmpty) {
        final f = sections[0].split('^');
        _firmName       = f.isNotEmpty ? f[0].trim() : '';
        _firmCity       = f.length > 1 ? f[1].trim() : '';
        _contactPerson  = f.length > 2 ? f[2].trim() : '';
        _contactMobile  = f.length > 3 ? f[3].trim() : '';
        _executive      = f.length > 4 ? f[4].trim() : '';
      }
      // Section 1: Complaints — Cpl_ID^CplDateT^Remark^SolveDateT^SolvBy#
      if (sections.length > 1) _complaints = _parseRows(sections[1], 5);
      // Section 2: References — u_id^package^year#
      if (sections.length > 2) _references = _parseRows(sections[2], 3);
      // Section 3: Usage — UID^clientname^City^Package^release^assessee^updated^Timestamp^ip#
      if (sections.length > 3) _usage = _parseRows(sections[3], 9);
      // Section 4: Software — Package^Year^#  (show "Year - Year+1")
      if (sections.length > 4) _software = _parseRows(sections[4], 2);

      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = 'Error: $e'; });
    }
  }

  Future<void> _fetchBilling(String year) async {
    setState(() { _isBillingLoading = true; _billing = []; });
    try {
      final resp = await http.post(
        Uri.parse('https://mdapulse.com/Calling.aspx/fillBillingDetail'),
        headers: _headers,
        body: jsonEncode({
          'ClientId': widget.clientId,
          'DB': widget.db,
          'CustID11': widget.custId11,
          'ddlMDAYr': year,
        }),
      );
      if (!mounted) return;
      final raw = jsonDecode(resp.body)['d']?.toString() ?? '';
      if (raw.isNotEmpty && raw != '0') {
        _billing = _parseRows(raw, 3);
      }
      setState(() => _isBillingLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isBillingLoading = false);
    }
  }

  /// Returns fiscal year keys for the last 5 years, most recent first.
  /// Format: "YYZZ" e.g. "2526" for 2025-26.
  List<String> _billingYears() {
    final now = DateTime.now();
    final currentStartYear = now.month >= 4 ? now.year : now.year - 1;
    return List.generate(5, (i) {
      final y = currentStartYear - i;
      return '${(y % 100).toString().padLeft(2, '0')}${((y + 1) % 100).toString().padLeft(2, '0')}';
    });
  }

  /// Display label for a fiscal year key, e.g. "2526" → "2025-26".
  String _fyLabel(String fy) {
    if (fy.length != 4) return fy;
    final start = int.tryParse(fy.substring(0, 2));
    final end   = int.tryParse(fy.substring(2, 4));
    if (start == null || end == null) return fy;
    final startFull = start >= 0 && start <= 30 ? 2000 + start : 1900 + start;
    return '$startFull-${end.toString().padLeft(2, '0')}';
  }

  List<List<String>> _parseRows(String raw, int minCols) => raw
      .split('#')
      .where((r) => r.trim().isNotEmpty)
      .map((r) => r.split('^').map((c) => c.trim()).toList())
      .where((r) => r.length >= minCols)
      .toList();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85, maxWidth: 600),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Container(
            color: _blue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(Icons.business, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _firmName.isNotEmpty ? _firmName : 'MDA Firm Detail',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              )),
              InkWell(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ]),
          ),
          // Firm info strip
          if (!_isLoading && _error.isEmpty)
            Container(
              color: Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(spacing: 16, runSpacing: 4, children: [
                if (_firmCity.isNotEmpty) _chip(Icons.location_on, _firmCity),
                if (_contactPerson.isNotEmpty) _chip(Icons.person, _contactPerson),
                if (_contactMobile.isNotEmpty) _chip(Icons.phone, _contactMobile),
                if (_executive.isNotEmpty) _chip(Icons.badge, _executive),
              ]),
            ),
          // Tab bar
          if (!_isLoading && _error.isEmpty)
            TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              labelColor: _blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _blue,
              tabs: const [
                Tab(text: 'Complaints'),
                Tab(text: 'References'),
                Tab(text: 'Usage'),
                Tab(text: 'Software'),
                Tab(text: 'Billing'),
              ],
            ),
          // Body
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: _blue));
    if (_error.isNotEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error, style: const TextStyle(color: Colors.red))));
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _tableTab(['ID', 'Date', 'Remark', 'Solved On', 'Solved By'], _complaints),
        _tableTab(['UID', 'Package', 'Year'], _references),
        _tableTab(['UID', 'Client', 'City', 'Package', 'Release', 'Assessee', 'Updated', 'Time', 'IP'], _usage),
        _softwareTab(),
        _billingTab(),
      ],
    );
  }

  Widget _tableTab(List<String> headers, List<List<String>> rows) {
    if (rows.isEmpty) {
      return const Center(child: Text('No data found.', style: TextStyle(color: Colors.grey)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Table(
          border: TableBorder.all(color: Colors.grey.shade300, width: 0.8),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: headers.map((h) => _cell(h, isHeader: true)).toList(),
            ),
            ...rows.map((row) => TableRow(
              children: List.generate(headers.length, (i) => _cell(i < row.length ? row[i] : '')),
            )),
          ],
        ),
      ),
    );
  }

  Widget _softwareTab() {
    if (_software.isEmpty) return const Center(child: Text('No data found.', style: TextStyle(color: Colors.grey)));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _software.length,
      separatorBuilder: (_, i) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final row = _software[i];
        final pkg = row.isNotEmpty ? row[0] : '';
        final yr = row.length > 1 ? row[1] : '';
        final yrInt = int.tryParse(yr);
        final yrLabel = yrInt != null ? '$yrInt - ${yrInt + 1}' : yr;
        return ListTile(
          leading: const Icon(Icons.computer, color: _blue),
          title: Text(pkg, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Text(yrLabel, style: const TextStyle(color: Colors.grey)),
          dense: true,
        );
      },
    );
  }

  Widget _billingTab() {
    final years = _billingYears();
    final yearPicker = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: [
        const Text('Financial Year:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(width: 10),
        DropdownButton<String>(
          value: _selectedBillingYear,
          isDense: true,
          underline: const SizedBox(),
          items: years.map((y) => DropdownMenuItem(value: y, child: Text(_fyLabel(y), style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (y) {
            if (y != null && y != _selectedBillingYear) {
              setState(() => _selectedBillingYear = y);
              _fetchBilling(y);
            }
          },
        ),
      ]),
    );

    if (_isBillingLoading) {
      return Column(children: [yearPicker, const Expanded(child: Center(child: CircularProgressIndicator(color: _blue)))]);
    }
    if (_billing.isEmpty) {
      return Column(children: [yearPicker, const Expanded(child: Center(child: Text('No billing records found.', style: TextStyle(color: Colors.grey))))]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      yearPicker,
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 0.8),
            columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1.5)},
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: [_cell('Invoice No', isHeader: true), _cell('Date', isHeader: true), _cell('Amount', isHeader: true)],
              ),
              ..._billing.map((row) => TableRow(children: [
                _cell(row.isNotEmpty ? row[0] : ''),
                _cell(row.length > 1 ? row[1] : ''),
                _cell(row.length > 2 ? row[2] : ''),
              ])),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _chip(IconData icon, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: Colors.blue.shade700),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 12, color: Colors.blue.shade900)),
  ]);

  Widget _cell(String text, {bool isHeader = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: isHeader ? FontWeight.bold : FontWeight.normal)),
  );
}
