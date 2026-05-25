import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mda_crm/shared/widgets/app_drawer.dart';
import 'package:mda_crm/shared/widgets/app_user_menu.dart';
import 'package:mda_crm/features/client_management/data/models/activity_model.dart';
import 'package:mda_crm/features/client_management/presentation/widgets/executive_task_entry_dialog.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);
const _wfHeaders = {
  'Content-Type': 'application/json; charset=utf-8',
  'X-Requested-With': 'XMLHttpRequest',
  'Referer': 'https://mdapulse.com/Workflows.aspx',
};

class WorkflowScreen extends StatefulWidget {
  const WorkflowScreen({super.key});
  @override
  State<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends State<WorkflowScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  int _selectedTab = 0;
  bool _isLoading = false;
  bool _hasFetched = false;
  String _error = '';
  List<_WfRow> _rows = [];
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _pageSize = 10;

  String _companyName = '';
  String _clientId = '';
  String _db = '';
  String _ucode = '';
  String _uname = '';

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAndFetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _companyName = prefs.getString('O_Name') ?? '';
      _clientId    = prefs.getString('CLIENTID') ?? '';
      _db          = prefs.getString('D_Database') ?? '';
      _ucode       = prefs.getString('UCode') ?? '';
      _uname       = prefs.getString('UName') ?? '';
    });
    await _fetchApproval();
  }

  Future<void> _fetchApproval() async {
    if (_clientId.isEmpty) return;
    setState(() { _isLoading = true; _hasFetched = false; _error = ''; _rows = []; });
    try {
      final resp = await http.post(
        Uri.parse('https://mdapulse.com/Workflows.aspx/fillList'),
        headers: _wfHeaders,
        body: jsonEncode({
          'ClientId': _clientId,
          'UCode': _ucode,
          'DB': _db,
          'type1': 'REQUIRED',
        }),
      );
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final raw = jsonDecode(resp.body)['d']?.toString() ?? '';
      final rows = raw.isEmpty || raw.startsWith('Something went wrong')
          ? <_WfRow>[]
          : raw.split('#').where((r) => r.trim().isNotEmpty).map(_parseRow).whereType<_WfRow>().toList();
      if (mounted) setState(() { _isLoading = false; _hasFetched = true; _rows = rows; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasFetched = true; _error = 'Error: $e'; });
    }
  }

  // Response fields (^-delimited) from Workflows.aspx/fillList:
  // [0]s_no [1]CustID [2]u_id [3]Remark [4]Cname [5]UName [6]Ndate
  // [7]status14 [8]stage14 [9]Activity [10]StatusE [11]ispros_cust
  // [12]NCallType [13]StatColor [14]sno_11 [15]CustID_11 [16]Remark11
  // [17]FirstDate [18]Product [19]Call_Cl_PN
  _WfRow? _parseRow(String chunk) {
    final p = chunk.split('^');
    if (p.length < 12) return null;
    return _WfRow(
      sno14:      p[0].trim(),
      custId:     p.length > 1  ? p[1].trim()  : '',
      uid:        p.length > 2  ? p[2].trim()  : '',
      remark:     p.length > 3  ? p[3].trim()  : '',
      custName:   p.length > 4  ? p[4].trim()  : '',
      execName:   p.length > 5  ? p[5].trim()  : '',
      dueDate:    p.length > 6  ? p[6].trim()  : '',
      status:     p.length > 7  ? p[7].trim()  : '',
      stage:      p.length > 8  ? p[8].trim()  : '',
      activity:   p.length > 9  ? p[9].trim()  : '',
      callType:   p.length > 12 ? p[12].trim() : '',
      sno11:      p.length > 14 ? p[14].trim() : '',
      custId11:   p.length > 15 ? p[15].trim() : '',
      product:    p.length > 18 ? p[18].trim() : '',
      callClPn:   p.length > 19 ? p[19].trim() : '',
      isCustomer: (p.length > 11 ? p[11].trim().toLowerCase() : '') == 'true',
    );
  }

  // ── Derived lists ──────────────────────────────────────────────────────────

  List<_WfRow> get _filtered {
    if (_searchQuery.isEmpty) return _rows;
    final q = _searchQuery.toLowerCase();
    return _rows.where((r) =>
      r.custName.toLowerCase().contains(q) ||
      r.execName.toLowerCase().contains(q) ||
      r.status.toLowerCase().contains(q) ||
      r.product.toLowerCase().contains(q)
    ).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Workflows', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        actions: const [AppUserMenu()],
      ),
      drawer: AppDrawer(currentRoute: 'Workflows', companyName: _companyName),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _buildTabBtn(0, 'Approval\nRequired', Icons.approval_outlined),
          ]),
          const SizedBox(height: 16),
          Expanded(child: _buildDataCard(cs)),
        ]),
      ),
    );
  }

  Widget _buildTabBtn(int index, String label, IconData icon) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() { _selectedTab = index; _currentPage = 1; });
        if (index == 0) _fetchApproval();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? mdaPrimaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? mdaPrimaryBlue : Colors.grey.shade300),
          boxShadow: isActive
              ? [BoxShadow(color: mdaPrimaryBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: isActive ? Colors.white : Colors.grey.shade600, size: 30),
          const SizedBox(height: 10),
          Text(label,
            style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildDataCard(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() { _searchQuery = v; _currentPage = 1; }),
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18),
                      onPressed: () { _searchCtrl.clear(); setState(() { _searchQuery = ''; _currentPage = 1; }); })
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outlineVariant)),
              filled: true, fillColor: cs.surfaceContainerLowest,
            ),
          ),
        ),
        Expanded(child: _buildBody(cs)),
        _buildFooter(cs),
      ]),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 40, color: cs.error),
          const SizedBox(height: 8),
          Text(_error, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchApproval, child: const Text('Retry')),
        ]),
      ));
    }
    if (_hasFetched && _filtered.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 48, color: Colors.green.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text('No approvals pending', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
      ]));
    }
    if (!_hasFetched) return const Center(child: CircularProgressIndicator());

    final all   = _filtered;
    final start = (_currentPage - 1) * _pageSize;
    final end   = (start + _pageSize).clamp(0, all.length);
    final page  = all.sublist(start, end);

    return RefreshIndicator(
      onRefresh: _fetchApproval,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: page.length,
        separatorBuilder: (_, i) => Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
        itemBuilder: (_, i) => _buildRow(page[i], start + i, cs),
      ),
    );
  }

  Widget _buildRow(_WfRow row, int idx, ColorScheme cs) {
    final prefix      = row.isCustomer ? 'C' : 'P';
    final prefixColor = row.isCustomer ? mdaPrimaryBlue : Colors.red;

    return InkWell(
      onTap: () => _showApproveDialog(row),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: idx.isOdd ? cs.surfaceContainerLowest : cs.surface,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.play_circle_outline, color: cs.onSurfaceVariant.withValues(alpha: 0.55), size: 22),
          ),
          const SizedBox(width: 10),

          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Client name
            RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(style: const TextStyle(fontSize: 14), children: [
                TextSpan(text: '$prefix - ', style: TextStyle(color: prefixColor, fontWeight: FontWeight.bold)),
                TextSpan(text: row.custName, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 6),

            // Executive + due date
            Row(children: [
              Icon(Icons.person_outline, size: 13, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(child: Text(row.execName, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 12),
              Icon(Icons.calendar_today_outlined, size: 12, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(child: Text(row.dueDate, style: TextStyle(fontSize: 12, color: cs.onSurface), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),

            // Status badge + product + phone icon
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Text(row.status,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                  overflow: TextOverflow.ellipsis),
              ),
              if (row.product.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(child: Text(row.product, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              ],
              const Spacer(),
              // Phone — open full call-entry dialog
              if (row.sno11.isNotEmpty && row.sno11 != '0')
                InkWell(
                  onTap: () => _openCallEntry(row),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.phone, color: mdaPrimaryBlue, size: 20),
                  ),
                ),
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _buildFooter(ColorScheme cs) {
    final total      = _filtered.length;
    final totalPages = (total / _pageSize).ceil().clamp(1, 9999);
    final start = total == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
    final end   = (_currentPage * _pageSize).clamp(0, total);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)))),
      child: Row(children: [
        Text('Showing $start to $end of $total entries', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const Spacer(),
        _pageBtn('Previous', _currentPage > 1 ? () => setState(() => _currentPage--) : null, cs),
        const SizedBox(width: 4),
        Container(
          width: 32, height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: mdaPrimaryBlue, borderRadius: BorderRadius.circular(4)),
          child: Text('$_currentPage', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 4),
        _pageBtn('Next', _currentPage < totalPages ? () => setState(() => _currentPage++) : null, cs),
      ]),
    );
  }

  Widget _pageBtn(String label, VoidCallback? onTap, ColorScheme cs) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        side: BorderSide(color: onTap != null ? cs.outlineVariant : cs.outlineVariant.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  // ── Accept / Reject dialog ────────────────────────────────────────────────

  void _showApproveDialog(_WfRow row) {
    showDialog(
      context: context,
      builder: (_) => _ApproveDialog(
        row: row,
        clientId: _clientId,
        db: _db,
        uname: _uname,
        onSubmit: (isAccept, remark, memberCode, memberName) async {
          final err = await _submitApproveReject(
              row, isAccept, remark, memberCode, memberName);
          if (err == null && mounted) _fetchApproval();
          return err;
        },
      ),
    );
  }

  // Server expects "hh:mm tt" (12-hour AM/PM) for DateTime.ParseExact.
  String _fmtApiTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  Future<String?> _submitApproveReject(
      _WfRow row, bool isAccept, String userRemark,
      String memberCode, String memberName) async {
    try {
      final now = DateTime.now();
      final datetxt = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final timetxt = _fmtApiTime(now); // "hh:mm AM/PM" — server requires this exact format

      // Tomorrow for rejected records
      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowTxt = '${tomorrow.day.toString().padLeft(2, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.year}';

      // Build remark string matching web spec
      final remarkSuffix = userRemark.isNotEmpty ? ' --- $userRemark' : '';
      final toTeamMember = (memberCode.isNotEmpty && memberCode != '0') ? ' to $memberName' : '';
      final String remark;
      if (isAccept) {
        remark = ('$datetxt --- ${row.status}$toTeamMember Approved By $_uname $remarkSuffix').trimRight();
      } else {
        remark = ('$datetxt --- ${row.status}  Rejected By $_uname $remarkSuffix').trimRight();
      }
      final oldRemark = row.remark.isNotEmpty ? '${row.remark}\r\n$remark' : remark;

      // Statustype: Close if Call_Cl_PN is Close, else Pending
      final statustype = row.callClPn.toLowerCase() == 'close' ? 'Close' : 'Pending';

      // NDate/NTime: tomorrow if rejected; existing due date if accepted Pending; empty if Close.
      // NTime must be non-empty for Pending — server calls DateTime.ParseExact on NDate+NTime.
      final ndate = !isAccept ? tomorrowTxt : (statustype == 'Close' ? '' : row.dueDate);
      final ntime = statustype == 'Close' ? '' : timetxt;

      final rdata = [
        row.sno14,    // sno
        row.custId,   // custID
        row.uid,      // Uid
        row.custName, // CustName
        row.callType, // Type (NCallType)
        datetxt,      // Datetxt
        timetxt,      // Timetxt1
        statustype,   // Statustype
        row.status,   // status
        '0',          // Product (0 for now)
        remark,       // Remark
        row.stage,    // Stage
        ndate,        // NDate
        ntime,        // NTime1
        oldRemark,    // OldRemark
        row.callType, // NType
        '0',          // CustIDProsTOCust
        memberCode,   // TeamMemberCode
        memberName,   // TeamMemberName
      ].join('^');

      final resp = await http.post(
        Uri.parse('https://mdapulse.com/Workflows.aspx/Update_Call'),
        headers: {..._wfHeaders, 'Accept-Language': 'en-US'},
        body: jsonEncode({
          'ClientId': _clientId,
          'Rdata': rdata,
          'ucode': _ucode,
          'DB': _db,
          'ProTOcust': 0,
          'sno_11': int.tryParse(row.sno11) ?? 0,
          'AcOrRej': isAccept ? 'Accept' : 'Reject',
        }),
      );
      if (resp.statusCode != 200) return 'Server error ${resp.statusCode}';
      final result = jsonDecode(resp.body)['d']?.toString() ?? '';
      if (result.toLowerCase().contains('error') || result.toLowerCase().contains('something went wrong')) {
        return result;
      }
      return null;
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<void> _openCallEntry(_WfRow row) async {
    String phone = '';
    if (row.sno11.isNotEmpty && row.sno11 != '0') {
      try {
        final resp = await http.post(
          Uri.parse('https://webservices.mdapulse.com/Customer.aspx/CustomerListBySno'),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'ClientId': _clientId, 'sno': int.tryParse(row.sno11) ?? 0, 'DB': _db}),
        );
        final rdata = jsonDecode(resp.body)['d']?.toString() ?? '';
        if (rdata.isNotEmpty && !rdata.contains('Something went wrong')) {
          final parts = rdata.split('^');
          phone = parts.length > 4 ? parts[4].trim() : '';
        }
      } catch (_) {}
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ExecutiveTaskEntryDialog(
        log: ActivityLog(
          sno: row.sno14, uid: row.uid,
          activityType: row.activity, executive: row.execName,
          nextDate: row.dueDate, statusBadge: row.status,
          progress: row.callClPn, product: row.product, remarks: [],
        ),
        displayName: row.custName,
        mobileNo: phone,
        customerSno: row.sno11,
        custId11: row.custId11,
        onSaved: _fetchApproval,
        isApprovalMode: true,
      ),
    );
  }
}

// ─── Approve / Reject dialog ──────────────────────────────────────────────────

class _ApproveDialog extends StatefulWidget {
  final _WfRow row;
  final String clientId, db, uname;
  /// isAccept=true → Accept, isAccept=false → Reject. Returns null on success.
  final Future<String?> Function(bool isAccept, String remark, String memberCode, String memberName) onSubmit;

  const _ApproveDialog({
    required this.row,
    required this.clientId,
    required this.db,
    required this.uname,
    required this.onSubmit,
  });

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  final _remarkCtrl = TextEditingController();
  bool _isSaving = false;
  String? _error;
  bool _isLoadingMembers = false;
  List<Map<String, String>> _members = [];
  String? _selectedMember;

  @override
  void initState() {
    super.initState();
    _fetchMembers(); // always fetch — needed if user chooses Accept
  }

  @override
  void dispose() {
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoadingMembers = true);
    try {
      final resp = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Calling.aspx/chkAtPendingTime'),
        headers: const {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': widget.clientId,
          'val': widget.row.status,
          'DB': widget.db,
        }),
      );
      if (!mounted) return;
      final result = jsonDecode(resp.body)['d']?.toString() ?? '';
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
          _members = members;
          _selectedMember = members.isNotEmpty ? members[0]['val'] : null;
          _isLoadingMembers = false;
        });
      } else {
        setState(() => _isLoadingMembers = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _submit(bool isAccept) async {
    setState(() { _isSaving = true; _error = null; });
    // Reject never assigns a team member
    final memberCode = isAccept ? (_selectedMember ?? '0') : '0';
    final memberName = isAccept
        ? (_members.firstWhere(
              (m) => m['val'] == _selectedMember,
              orElse: () => {'text': ''},
            )['text'] ?? '')
        : '';
    final err = await widget.onSubmit(isAccept, _remarkCtrl.text.trim(), memberCode, memberName);
    if (!mounted) return;
    if (err != null) {
      setState(() { _isSaving = false; _error = err; });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Row(children: [
        const Icon(Icons.approval_outlined, color: mdaPrimaryBlue, size: 22),
        const SizedBox(width: 8),
        const Text('Workflow Approval',
            style: TextStyle(color: mdaPrimaryBlue, fontWeight: FontWeight.bold)),
      ]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.row.custName, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(widget.row.status, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _remarkCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Remark (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
          if (_isLoadingMembers) ...[
            const SizedBox(height: 12),
            const Center(child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: mdaPrimaryBlue))),
          ],
          if (!_isLoadingMembers && _members.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Assign Team Member',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
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
                  value: _selectedMember,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  items: _members
                      .map((m) => DropdownMenuItem(value: m['val'], child: Text(m['text']!)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedMember = v),
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : () => _submit(false),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: _isSaving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Reject'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : () => _submit(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: _isSaving
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Accept'),
        ),
      ],
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────


class _WfRow {
  final String sno14, custId, uid, remark, custName, execName, dueDate;
  final String status, stage, activity, callType, sno11, custId11, product, callClPn;
  final bool isCustomer;
  const _WfRow({
    required this.sno14, required this.custId, required this.uid,
    required this.remark, required this.custName, required this.execName,
    required this.dueDate, required this.status, required this.stage,
    required this.activity, required this.callType, required this.sno11,
    required this.custId11, required this.product, required this.callClPn,
    required this.isCustomer,
  });
}
