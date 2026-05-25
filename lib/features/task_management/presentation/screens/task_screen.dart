import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/widgets/app_drawer.dart';
import 'package:mda_crm/shared/widgets/app_user_menu.dart';
import 'package:mda_crm/features/task_management/data/models/task_model.dart';
import 'package:mda_crm/features/client_management/data/models/activity_model.dart';
import 'package:mda_crm/features/client_management/presentation/widgets/executive_task_entry_dialog.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

const _callingHeaders = {
  'Content-Type': 'application/json; charset=utf-8',
  'X-Requested-With': 'XMLHttpRequest',
  'Referer': 'https://mdapulse.com/Calling.aspx',
};

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  int _selectedFilterIndex = 0;
  String _selectedSubFilter = 'All';
  int _currentPage = 1;
  final int _entriesPerPage = 10;
  String _searchQuery = '';
  String _workViewType = 'My'; // 'My' or 'Team'

  List<TaskModel> _tasks = [];
  bool _isLoading = false;

  String _companyName = '';
  String _clientId = '';
  String _db = '';
  String _sno = '0';
  String _showAllC = '0';
  String _ucode = '';

  // Columns keyed by server name; visibility + display name configurable via fillSettcolumns / save_Columns.
  // Default: 5 columns visible (as per spec). fillSettcolumns overrides this on load.
  Map<String, bool> _columnVisibility = {
    'Client': true, 'Activity': true, 'Executive': true,
    'First Date': false, 'Due Date': true, 'Due Date Time': false, 'Status': true,
    'Product': false, 'Remark': false,
  };
  Map<String, String> _columnDisplayNames = {
    'Client': 'Client', 'Activity': 'Activity', 'Executive': 'Executive',
    'First Date': 'First Date', 'Due Date': 'Due Date', 'Due Date Time': 'Due Date Time', 'Status': 'Status',
    'Product': 'Product', 'Remark': 'Remark',
  };

  final List<Map<String, dynamic>> _filters = [
    {'title': 'Overdue',   'icon': Icons.error_outline,  'type': 'OD'},
    {'title': 'Due Today', 'icon': Icons.sensors,         'type': 'DU'},
    {'title': 'Due later', 'icon': Icons.calendar_today,  'type': 'DL'},
    {'title': 'All tasks', 'icon': Icons.check_circle,    'type': 'OP'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPrefsAndFetch();
  }

  Future<void> _loadPrefsAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _companyName = prefs.getString('O_Name') ?? '';
      _clientId    = prefs.getString('CLIENTID') ?? '';
      _db          = prefs.getString('D_Database') ?? '';
      _sno         = prefs.getString('sno') ?? '0';
      _showAllC    = prefs.getString('showAllCustomer') ?? '0';
      _ucode       = prefs.getString('UCode') ?? '';
    });
    await _fetchSettColumns(); // applies server-saved column config, then calls _fetchTasks
  }

  // ─── fillSettcolumns ────────────────────────────────────────────────────────

  Future<void> _fetchSettColumns() async {
    try {
      final res = await http.post(
        Uri.parse('https://mdapulse.com/Calling.aspx/fillSettcolumns'),
        headers: _callingHeaders,
        body: jsonEncode({'ClientId': _clientId, 'DB': _db}),
      );
      if (res.statusCode == 200) {
        final raw = (jsonDecode(res.body)['d']?.toString() ?? '').trim();
        // Non-empty response overrides the 5-column default
        if (raw.isNotEmpty) _applyColumnConfig(raw);
        // Empty → keep the 5-column defaults already set in _columnVisibility
      }
    } catch (_) {}
    await _fetchTasks();
  }

  void _applyColumnConfig(String raw) {
    // Format: "Client$CustomerName^Activity^Executive^Due Date$DueDate^Status"
    final parts = raw.split('^').where((p) => p.trim().isNotEmpty).toList();
    final newVis  = <String, bool>{for (final k in _columnVisibility.keys) k: false};
    final newNames = Map<String, String>.from(_columnDisplayNames);
    for (final part in parts) {
      if (part.contains('\$')) {
        final sub = part.split('\$');
        final col = sub[0].trim();
        if (newVis.containsKey(col)) {
          newVis[col] = true;
          newNames[col] = sub[1].trim();
        }
      } else {
        final col = part.trim();
        if (newVis.containsKey(col)) newVis[col] = true;
      }
    }
    if (mounted) setState(() { _columnVisibility = newVis; _columnDisplayNames = newNames; });
  }

  // ─── save_Columns ───────────────────────────────────────────────────────────

  Future<void> _saveColumns() async {
    String colStr(String col) {
      final name = _columnDisplayNames[col] ?? col;
      return name != col ? '$col\$$name^' : '$col^';
    }
    final text1 = [for (final c in ['Client', 'Activity', 'Executive'])
        if (_columnVisibility[c] == true) colStr(c)].join();
    final text2 = [for (final c in ['First Date', 'Due Date', 'Due Date Time', 'Status'])
        if (_columnVisibility[c] == true) colStr(c)].join();
    final text3 = [for (final c in ['Product', 'Remark'])
        if (_columnVisibility[c] == true) colStr(c)].join();
    if (text1.isEmpty && text2.isEmpty && text3.isEmpty) return;
    try {
      await http.post(
        Uri.parse('https://mdapulse.com/Calling.aspx/save_Columns'),
        headers: _callingHeaders,
        body: jsonEncode({
          'ClientId': _clientId, 'DB': _db, 'ucode': _ucode,
          'Text1': text1, 'Text2': text2, 'Text3': text3,
        }),
      );
    } catch (_) {}
  }

  // ─── fillList ───────────────────────────────────────────────────────────────

  Future<void> _fetchTasks() async {
    if (_clientId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      if (_selectedFilterIndex == 3 && _selectedSubFilter == 'All') {
        final results = await Future.wait([
          _fetchTasksForType('Pending'),
          _fetchTasksForType('Close'),
        ]);
        if (mounted) setState(() { _tasks = [...results[0], ...results[1]]; _isLoading = false; });
      } else {
        final tasks = await _fetchTasksForType(_getApiType());
        if (mounted) setState(() { _tasks = tasks; _isLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _tasks = []; _isLoading = false; });
    }
  }

  String _getApiType() {
    switch (_selectedFilterIndex) {
      case 0: return 'OD';
      case 1: return 'DU';
      case 2: return 'DL';
      case 3:
        if (_selectedSubFilter == 'Ongoing') return 'Pending';
        if (_selectedSubFilter == 'Closed')  return 'Close';
        return 'Pending';
      default: return 'OD';
    }
  }

  Future<List<TaskModel>> _fetchTasksForType(String type) async {
    final payload = jsonEncode({
      'ClientId': _clientId,
      'Type': type,
      'sno': _sno,
      'DB': _db,
      'showAllC': int.tryParse(_showAllC) ?? 0,
      'WorkViewType': _workViewType,
    });
    final response = await http.post(
      Uri.parse('https://mdapulse.com/Calling.aspx/fillList'),
      headers: _callingHeaders,
      body: payload,
    );
    if (response.statusCode != 200) return [];
    final String raw = jsonDecode(response.body)['d']?.toString() ?? '';
    if (raw.isEmpty || raw.startsWith('Something went wrong')) return [];
    return raw.split('#').where((r) => r.trim().isNotEmpty).map(_parseTask).whereType<TaskModel>().toList();
  }

  // Response: [0]sno14 ^ [1]custID ^ [2]uid ^ [3]remark ^ [4]CustName ^ [5]UName ^
  //           [6]ndate ^ [7]status ^ [8]stage ^ [9]TypeOfCall ^ [10]StateName ^
  //           [11]Pros_Cust ^ [12]NCallType ^ [13]StatColur ^ [14]sno11 ^ [15]CustID11 ^
  //           [16]Remarks11 ^ [17]FirstDate ^ [18]Product ^ [19]Call_CL_PN
  TaskModel? _parseTask(String row) {
    final p = row.split('^');
    if (p.length < 11) return null;

    final sno14    = p[0].trim();
    final uid      = p.length > 2  ? p[2].trim()  : '';
    final remarkRaw= p.length > 3  ? p[3].trim()  : '';
    final custName = p.length > 4  ? p[4].trim()  : '';
    final uname    = p.length > 5  ? p[5].trim()  : '';
    final ndate    = p.length > 6  ? p[6].trim()  : '';
    final status   = p.length > 7  ? p[7].trim()  : '';
    final typeOfCall = p.length > 9  ? p[9].trim()  : '';
    final stateName  = p.length > 10 ? p[10].trim() : '';
    final prosCust   = p.length > 11 ? p[11].trim() : '';
    final sno11            = p.length > 14 ? p[14].trim() : '';
    final custId11         = p.length > 15 ? p[15].trim() : '';
    final product          = p.length > 18 ? p[18].trim() : '';
    final callStatus       = p.length > 19 ? p[19].trim() : '';
    final isApprovalPending = (p.length > 20 ? p[20].trim().toLowerCase() : '') == 'true';
    final nDateTime        = p.length > 21 ? p[21].trim() : '';

    // Extract first date from remark prefix "dd-mm-yyyy --- actual remark"
    String firstDate = '';
    String cleanRemark = remarkRaw;
    final sepIdx = remarkRaw.indexOf(' --- ');
    if (sepIdx > 0) {
      final datePart = remarkRaw.substring(0, sepIdx).trim();
      if (datePart.length == 10 && datePart[2] == '-' && datePart[5] == '-') {
        firstDate  = datePart;
        cleanRemark = remarkRaw.substring(sepIdx + 5).trim();
      }
    }

    final isCustomer = prosCust.toLowerCase() == 'true';
    final activity   = stateName.isNotEmpty ? stateName : typeOfCall;

    return TaskModel(
      sno: uid, sno14: sno14, sno11: sno11, custId11: custId11,
      clientPrefix: isCustomer ? 'C - ' : 'P - ',
      clientName: custName,
      activity: activity,
      executive: uname,
      firstDate: firstDate,
      nextDate: ndate,
      status: status,
      callStatus: callStatus,
      product: product,
      remark: cleanRemark,
      isApprovalPending: isApprovalPending,
      nDateTime: nDateTime,
    );
  }

  // ─── fillCallDetail ─────────────────────────────────────────────────────────

  Future<List<CallDetail>> _fetchCallDetails(String uid) async {
    final response = await http.post(
      Uri.parse('https://mdapulse.com/Calling.aspx/fillCallDetail'),
      headers: _callingHeaders,
      body: jsonEncode({'ClientId': _clientId, 'uid': uid, 'DB': _db}),
    );
    if (response.statusCode != 200) return [];
    final String raw = jsonDecode(response.body)['d']?.toString() ?? '';
    if (raw.isEmpty) return [];
    return raw.split('#').where((r) => r.trim().isNotEmpty).map((row) {
      final parts = row.split('^');
      if (parts.length < 3) return null;
      return CallDetail(date: parts[0].trim(), remark: parts[1].trim(), status: parts[2].trim());
    }).whereType<CallDetail>().toList();
  }

  // ─── Filtered / paginated lists ─────────────────────────────────────────────

  List<TaskModel> get _filteredTasks {
    if (_searchQuery.isEmpty) return _tasks;
    final q = _searchQuery.toLowerCase();
    return _tasks.where((t) =>
      t.clientName.toLowerCase().contains(q) ||
      t.activity.toLowerCase().contains(q) ||
      t.executive.toLowerCase().contains(q) ||
      t.status.toLowerCase().contains(q) ||
      t.product.toLowerCase().contains(q)
    ).toList();
  }

  List<TaskModel> get _paginatedTasks {
    final all   = _filteredTasks;
    final start = (_currentPage - 1) * _entriesPerPage;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _entriesPerPage).clamp(0, all.length));
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Task Management', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        actions: const [AppUserMenu()],
      ),
      drawer: AppDrawer(currentRoute: 'Tasks', companyName: _companyName),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Add Ticket'),
        backgroundColor: mdaPrimaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Filter cards ──
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2,
              ),
              itemCount: _filters.length,
              itemBuilder: (context, index) => _buildFilterCard(context, index),
            ),
            const SizedBox(height: 12),

            // ── My Work / Team toggle ──
            Row(
              children: [
                Text('View: ', style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, fontSize: 13)),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: mdaPrimaryBlue),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _buildToggleBtn(context, 'My Work', _workViewType == 'My', () {
                      setState(() { _workViewType = 'My'; _currentPage = 1; });
                      _fetchTasks();
                    }, isFirst: true),
                    _buildToggleBtn(context, 'Team', _workViewType == 'Team', () {
                      setState(() { _workViewType = 'Team'; _currentPage = 1; });
                      _fetchTasks();
                    }, isLast: true),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── All Tasks sub-filter ──
            if (_selectedFilterIndex == 3) ...[
              Center(child: _buildSubFilters(context)),
              const SizedBox(height: 12),
            ],

            // ── Search + Columns ──
            Row(children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() { _searchQuery = v; _currentPage = 1; }),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline)),
                    filled: true,
                    fillColor: cs.surface,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => _showChangeColumnsModal(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  side: const BorderSide(color: mdaPrimaryBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Icon(Icons.view_column, color: mdaPrimaryBlue),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Task list ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(children: [
                        if (_columnVisibility.values.every((v) => v == false))
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(child: Text('No columns selected. Please select at least one column to display tasks.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15), textAlign: TextAlign.center)),
                          )
                        else if (_filteredTasks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(child: Text('No tasks found.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15))),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _paginatedTasks.length,
                            itemBuilder: (context, index) => _buildTaskCard(context, _paginatedTasks[index]),
                          ),
                        _buildPaginationFooter(context),
                        const SizedBox(height: 80),
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Filter card ────────────────────────────────────────────────────────────

  Widget _buildFilterCard(BuildContext context, int index) {
    final cs = Theme.of(context).colorScheme;
    final bool isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilterIndex = index;
          _selectedSubFilter = 'All';
          _workViewType = 'My'; // reset to My Work on filter change (per spec)
          _currentPage = 1;
          _searchQuery = '';
        });
        _fetchTasks();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? mdaPrimaryBlue : cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? mdaPrimaryBlue : cs.outline.withValues(alpha: 0.5)),
          boxShadow: isSelected
              ? [BoxShadow(color: mdaPrimaryBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_filters[index]['icon'], color: isSelected ? Colors.white : cs.onSurface, size: 24),
          const SizedBox(height: 6),
          Text(
            _filters[index]['title'],
            style: TextStyle(color: isSelected ? Colors.white : cs.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  // ─── Sub-filters (All / Ongoing / Closed) ───────────────────────────────────

  Widget _buildSubFilters(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: mdaPrimaryBlue), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _buildToggleBtn(context, 'All', _selectedSubFilter == 'All', () {
          setState(() { _selectedSubFilter = 'All'; _currentPage = 1; });
          _fetchTasks();
        }, isFirst: true),
        _buildToggleBtn(context, 'Ongoing', _selectedSubFilter == 'Ongoing', () {
          setState(() { _selectedSubFilter = 'Ongoing'; _currentPage = 1; });
          _fetchTasks();
        }),
        _buildToggleBtn(context, 'Closed', _selectedSubFilter == 'Closed', () {
          setState(() { _selectedSubFilter = 'Closed'; _currentPage = 1; });
          _fetchTasks();
        }, isLast: true),
      ]),
    );
  }

  Widget _buildToggleBtn(BuildContext context, String text, bool isActive, VoidCallback onTap,
      {bool isFirst = false, bool isLast = false}) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? mdaPrimaryBlue : cs.surface,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(5) : Radius.zero,
            right: isLast ? const Radius.circular(5) : Radius.zero,
          ),
        ),
        child: Text(text,
          style: TextStyle(color: isActive ? Colors.white : mdaPrimaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  // ─── Task card ──────────────────────────────────────────────────────────────

  Widget _buildTaskCard(BuildContext context, TaskModel task) {
    final cs = Theme.of(context).colorScheme;
    final isClosed = task.displayCallStatus == 'Closed';
    final dn = _columnDisplayNames;
    final vis = _columnVisibility;

    // Build left / right / extra field lists based on column visibility
    final leftFields  = <Widget>[];
    final rightFields = <Widget>[];
    final extraFields = <Widget>[];

    if (vis['Activity'] == true) { leftFields.add(_buildDetailRow(context, Icons.assignment, dn['Activity']!, task.activity)); }
    if (vis['Executive'] == true) { leftFields.add(_buildDetailRow(context, Icons.person, dn['Executive']!, task.executive)); }

    if (vis['Due Date'] == true) { rightFields.add(_buildDetailRow(context, Icons.event_available, dn['Due Date']!, task.nDateTime.isNotEmpty ? task.nDateTime : task.nextDate)); }
    if (vis['Due Date Time'] == true && task.nDateTime.isNotEmpty) { rightFields.add(_buildDetailRow(context, Icons.access_time, dn['Due Date Time']!, task.nDateTime)); }
    if (vis['Status'] == true) { rightFields.add(_buildDetailRow(context, Icons.info_outline, dn['Status']!, task.status)); }

    if (vis['First Date'] == true && task.firstDate.isNotEmpty) { extraFields.add(_buildDetailRow(context, Icons.date_range, dn['First Date']!, task.firstDate)); }
    if (vis['Product'] == true && task.product.isNotEmpty) { extraFields.add(_buildDetailRow(context, Icons.inventory_2_outlined, dn['Product']!, task.product)); }
    if (vis['Remark'] == true && task.remark.isNotEmpty) { extraFields.add(_buildDetailRow(context, Icons.notes, dn['Remark']!, task.remark, maxLines: 2)); }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showCallDetailsDialog(context, task),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header: client name + status badge + call button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vis['Client'] != false)
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(task.clientPrefix,
                          style: TextStyle(color: task.isProspect ? Colors.red : mdaPrimaryBlue, fontWeight: FontWeight.w900, fontSize: 16)),
                        Expanded(child: Text(task.clientName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                      if (task.isApprovalPending)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: const Text('Approval Pending',
                              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  )),
                const SizedBox(width: 8),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isClosed ? cs.surfaceContainerHighest : mdaPrimaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isClosed ? 'Closed' : (task.product.isNotEmpty ? task.product : 'Ongoing'),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                          color: isClosed ? cs.onSurfaceVariant : mdaPrimaryBlue),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (task.sno14.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _openTaskEntry(task),
                      borderRadius: BorderRadius.circular(16),
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.phone, color: mdaPrimaryBlue, size: 18)),
                    ),
                  ],
                ]),
              ],
            ),

            if (leftFields.isNotEmpty || rightFields.isNotEmpty || extraFields.isNotEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(height: 1)),

            // Main 2-column detail grid
            if (leftFields.isNotEmpty || rightFields.isNotEmpty)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (leftFields.isNotEmpty)
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: leftFields.expand((w) => [w, const SizedBox(height: 12)]).toList()..removeLast())),
                if (leftFields.isNotEmpty && rightFields.isNotEmpty) const SizedBox(width: 8),
                if (rightFields.isNotEmpty)
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: rightFields.expand((w) => [w, const SizedBox(height: 12)]).toList()..removeLast())),
              ]),

            // Extra fields (First Date, Product, Remark) below
            if (extraFields.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...extraFields.expand((w) => [w, const SizedBox(height: 8)]).toList()..removeLast(),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, {int maxLines = 1}) {
    final cs = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: cs.outline),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: maxLines, overflow: TextOverflow.ellipsis),
      ])),
    ]);
  }

  // ─── Pagination ─────────────────────────────────────────────────────────────

  Widget _buildPaginationFooter(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _filteredTasks.length;
    final start = total == 0 ? 0 : ((_currentPage - 1) * _entriesPerPage) + 1;
    final end   = (_currentPage * _entriesPerPage).clamp(0, total);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Text('Showing $start to $end of $total entries',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton(
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20), minimumSize: const Size(0, 36),
              side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Prev'),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: mdaPrimaryBlue, borderRadius: BorderRadius.circular(8)),
            child: Text('$_currentPage', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _currentPage < (total / _entriesPerPage).ceil() ? () => setState(() => _currentPage++) : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20), minimumSize: const Size(0, 36),
              side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Next'),
          ),
        ]),
      ]),
    );
  }

  // ─── Task entry (call dialog) ────────────────────────────────────────────────

  Future<void> _openTaskEntry(TaskModel task) async {
    String phone = '';
    if (task.sno11.isNotEmpty && task.sno11 != '0') {
      try {
        final resp = await http.post(
          Uri.parse('https://webservices.mdapulse.com/Customer.aspx/CustomerListBySno'),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'ClientId': _clientId, 'sno': int.tryParse(task.sno11) ?? 0, 'DB': _db}),
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
          sno: task.sno14,
          uid: task.sno,
          activityType: task.activity,
          executive: task.executive,
          nextDate: task.nextDate,
          statusBadge: task.status,
          progress: task.callStatus,
          product: task.product,
          remarks: [],
        ),
        displayName: task.clientName,
        mobileNo: phone,
        customerSno: task.sno11,
        custId11: task.custId11,
        isApprovalPending: task.isApprovalPending,
        onSaved: () {
          setState(() { _tasks = []; _isLoading = true; });
          _fetchTasks();
        },
      ),
    );
  }

  // ─── Call details dialog ─────────────────────────────────────────────────────

  void _showCallDetailsDialog(BuildContext context, TaskModel task) {
    final detailsFuture = _fetchCallDetails(task.sno);
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: mdaPrimaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Call Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              InkWell(onTap: () => Navigator.pop(dialogContext), child: const Icon(Icons.close, color: Colors.white, size: 20)),
            ]),
          ),
          FutureBuilder<List<CallDetail>>(
            future: detailsFuture,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(32.0), child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('No call details found.', style: TextStyle(color: Colors.grey))));
              }
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  itemBuilder: (ctx, i) {
                    final detail = snapshot.data![i];
                    final cs = Theme.of(ctx).colorScheme;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text(detail.date, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
                          ),
                          child: Text(detail.status, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(detail.remark, style: const TextStyle(fontSize: 14)),
                    ]);
                  },
                ),
              );
            },
          ),
          Builder(builder: (ctx) {
            final cs = Theme.of(ctx).colorScheme;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.3)))),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600], foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            );
          }),
        ]),
      ),
    );
  }

  // ─── Change columns modal ────────────────────────────────────────────────────

  void _showChangeColumnsModal(BuildContext context) {
    final controllers = {
      for (final col in _columnVisibility.keys)
        col: TextEditingController(
          text: (_columnDisplayNames[col] != col) ? (_columnDisplayNames[col] ?? '') : '',
        )
    };
    final localVisibility = Map<String, bool>.from(_columnVisibility);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Change Columns', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () { for (final c in controllers.values) { c.dispose(); } Navigator.pop(ctx); },
                  icon: const Icon(Icons.close),
                ),
              ]),
              const Divider(),
              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(children: [
                  const SizedBox(width: 44, child: Text('Show', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const SizedBox(width: 8),
                  const SizedBox(width: 90, child: Text('Column', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Rename', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600))),
                ]),
              ),
              const Divider(height: 8),
              Expanded(
                child: ListView(
                  children: localVisibility.keys.map((col) => Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(children: [
                      SizedBox(width: 44, child: Checkbox(
                        value: localVisibility[col] ?? true,
                        activeColor: mdaPrimaryBlue,
                        onChanged: (val) => setModalState(() => localVisibility[col] = val ?? true),
                      )),
                      const SizedBox(width: 8),
                      SizedBox(width: 90, child: Text(_columnDisplayNames[col] ?? col, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(
                        controller: controllers[col],
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Rename...',
                          hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      )),
                    ]),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    setState(() {
                      _columnVisibility = Map.from(localVisibility);
                      for (final col in controllers.keys) {
                        final custom = controllers[col]!.text.trim();
                        _columnDisplayNames[col] = custom.isNotEmpty ? custom : col;
                      }
                    });
                    for (final c in controllers.values) { c.dispose(); }
                    Navigator.pop(ctx);
                    await _saveColumns();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Save Columns', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
