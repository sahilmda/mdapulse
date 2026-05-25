import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/widgets/app_drawer.dart';
import 'package:mda_crm/shared/widgets/app_user_menu.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);
const String _baseUrl = 'https://webservices.mdapulse.com/Employee.aspx/';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  int _selectedTabIndex = 0;
  String _companyName = '';
  String _searchQuery = '';

  bool _isLoading = false;
  String _errorMessage = '';

  List<_Employee> _activeEmployees = [];
  List<_Employee> _inactiveEmployees = [];
  List<_Team> _teams = [];

  // Dropdowns
  List<Map<String, String>> _grades = [];
  List<Map<String, String>> _departments = [];
  List<Map<String, String>> _reporters = [];
  List<Map<String, String>> _statuses = [];

  // Pagination
  int _currentPage = 1;
  static const int _pageSize = 10;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _companyName = prefs.getString('O_Name') ?? '');
    await Future.wait([
      _fetchEmployees(active: true),
      _fetchEmployees(active: false),
      _fetchDropdowns(),
    ]);
  }

  Future<void> _fetchEmployees({required bool active}) async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final resp = await http.post(
        Uri.parse('${_baseUrl}fillEmployeeList'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': prefs.getString('CLIENTID') ?? '', 'Active': active ? '1' : '0', 'DB': prefs.getString('D_Database') ?? ''}),
      );
      if (resp.statusCode == 200) {
        final raw = (jsonDecode(resp.body)['d'] ?? '').toString().trim();
        final list = <_Employee>[];
        if (raw.contains('^')) {
          for (final chunk in raw.split('#')) {
            final p = chunk.split('^');
            if (p.length > 7) {
              list.add(_Employee(
                sno: p[0], name: p[2], email: p.length > 5 ? p[5] : '',
                grade: p.length > 6 ? p[6] : '', mobile: p.length > 7 ? p[7] : '',
                gradeName: p.length > 13 ? p[13] : '',
                initials: p.length > 14 ? p[14] : (p[2].isNotEmpty ? p[2][0].toUpperCase() : '?'),
                autoAllot: p.length > 12 ? p[12] : '0',
                heir: p.length > 8 ? p[8] : '', parentId: p.length > 9 ? p[9] : '',
                deptId: p.length > 10 ? p[10] : '', pass: p.length > 3 ? p[3] : '',
                uCode: p.length > 4 ? p[4] : '', rawData: chunk,
              ));
            }
          }
        }
        if (mounted) {
          setState(() {
            if (active) { _activeEmployees = list; } else { _inactiveEmployees = list; }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { _isLoading = false; _errorMessage = 'Error ${resp.statusCode}'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Connection error: $e'; });
    }
  }

  Future<void> _fetchTeams() async {
    setState(() { _isLoading = true; _errorMessage = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final resp = await http.post(
        Uri.parse('${_baseUrl}fillTeams'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': prefs.getString('CLIENTID') ?? '', 'UCode': prefs.getString('UCode') ?? '', 'DB': prefs.getString('D_Database') ?? ''}),
      );
      if (resp.statusCode == 200) {
        final raw = (jsonDecode(resp.body)['d'] ?? '').toString().trim();
        final list = <_Team>[];
        if (raw.contains('^')) {
          for (final chunk in raw.split('#')) {
            final p = chunk.split('^');
            if (p.length > 5) {
              list.add(_Team(name: p[0], tsno: p[1], members: p[2], empSno: p[3], teamId: p[4], status: p[5], nextStatus: p.length > 6 ? p[6] : ''));
            }
          }
        }
        if (mounted) setState(() { _teams = list; _isLoading = false; });
      } else {
        if (mounted) setState(() { _isLoading = false; _errorMessage = 'Error ${resp.statusCode}'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Connection error: $e'; });
    }
  }

  Future<void> _fetchDropdowns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? '';
      final db = prefs.getString('D_Database') ?? '';

      List<Map<String, String>> parseDropdown(String raw) {
        final list = <Map<String, String>>[];
        for (final chunk in raw.split('#')) {
          final p = chunk.split('~');
          if (p.length >= 2) list.add({'text': p[0].trim(), 'value': p[1].trim()});
        }
        return list;
      }

      final results = await Future.wait([
        http.post(Uri.parse('${_baseUrl}Fill_DropDown'), headers: {'Content-Type': 'application/json; charset=utf-8'}, body: jsonEncode({'ClientId': clientId, 'Type': 'Grade', 'DB': db})),
        http.post(Uri.parse('${_baseUrl}Fill_DropDown'), headers: {'Content-Type': 'application/json; charset=utf-8'}, body: jsonEncode({'ClientId': clientId, 'Type': 'Dept', 'DB': db})),
        http.post(Uri.parse('${_baseUrl}Fill_DropDown'), headers: {'Content-Type': 'application/json; charset=utf-8'}, body: jsonEncode({'ClientId': clientId, 'Type': 'Rep', 'DB': db})),
        http.post(Uri.parse('${_baseUrl}Fill_DropDown'), headers: {'Content-Type': 'application/json; charset=utf-8'}, body: jsonEncode({'ClientId': clientId, 'Type': 'DStatus', 'DB': db})),
      ]);

      if (mounted) setState(() {
        _grades      = parseDropdown((jsonDecode(results[0].body)['d'] ?? '').toString());
        _departments = parseDropdown((jsonDecode(results[1].body)['d'] ?? '').toString());
        _reporters   = [{'text': '-- None --', 'value': '0'}, ...parseDropdown((jsonDecode(results[2].body)['d'] ?? '').toString())];
        _statuses    = parseDropdown((jsonDecode(results[3].body)['d'] ?? '').toString());
      });
    } catch (_) {}
  }

  // ─── Employee save/toggle ──────────────────────────────────────────────────

  Future<void> _saveEmployee({
    required String name, required String pass, required String mobile,
    required String email, required String gradeVal, required String depVal,
    required String reportVal, required String initials, required int autoAllot,
    required int sno, required String oldMobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final resp = await http.post(
      Uri.parse('${_baseUrl}Save_Employee'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'ClientId': prefs.getString('CLIENTID') ?? '', 'username': name, 'pass': pass,
        'mobile': mobile, 'email': email, 'gradeVal': gradeVal, 'depVal': depVal,
        'reportVal': reportVal, 'Sno': sno, 'AutoAllot': autoAllot, 'Initials': initials,
        'DB': prefs.getString('D_Database') ?? '', 'OldMobile': oldMobile,
      }),
    );
    final raw = (jsonDecode(resp.body)['d'] ?? '').toString();
    final parts = raw.split('#');
    final ok = parts[0] == '1';
    final msg = parts.length > 1 ? parts[1] : raw;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));
      if (ok) { await _fetchEmployees(active: true); await _fetchEmployees(active: false); }
    }
  }

  Future<void> _toggleEmployeeActive(_Employee emp) async {
    final isActive = _selectedTabIndex == 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isActive ? 'Deactivate Employee' : 'Activate Employee'),
        content: Text(isActive ? 'Remove ${emp.name} from active employees?' : 'Activate ${emp.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isActive ? Colors.red : Colors.green, foregroundColor: Colors.white),
            child: Text(isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final endpoint = isActive ? 'InActiveEmp' : 'ActiveEmp';
      final resp = await http.post(
        Uri.parse('$_baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': prefs.getString('CLIENTID') ?? '', 'Sno': int.tryParse(emp.sno) ?? 0, 'DB': prefs.getString('D_Database') ?? ''}),
      );
      final msg = (jsonDecode(resp.body)['d'] ?? '').toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
        await _fetchEmployees(active: true);
        await _fetchEmployees(active: false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ─── Team save/delete ──────────────────────────────────────────────────────

  Future<void> _saveTeam({required String teamName, required String status, required String nextStatus, required String empSno, _Team? existing}) async {
    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString('CLIENTID') ?? '';
    final db = prefs.getString('D_Database') ?? '';

    http.Response resp;
    if (existing == null) {
      resp = await http.post(Uri.parse('${_baseUrl}Save_Team'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': clientId, 'TeamName': teamName, 'Status': status, 'NextStatus': nextStatus, 'sno_Emp': empSno, 'DB': db}));
    } else {
      resp = await http.post(Uri.parse('${_baseUrl}Update_Team'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': clientId, 'TeamName': teamName, 'Status': status, 'NextStatus': nextStatus, 'sno_Emp': empSno, 'Tsno': int.tryParse(existing.tsno) ?? 0, 'OldStatus': existing.status, 'DB': db}));
    }

    final raw = (jsonDecode(resp.body)['d'] ?? '').toString().trim();
    final ok = raw == '1';
    final msg = ok ? (existing == null ? 'Team added successfully.' : 'Team updated successfully.') : (raw == '2' ? 'Team name already exists.' : 'Failed to save team.');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: ok ? Colors.green : Colors.red));
      if (ok) _fetchTeams();
    }
  }

  Future<void> _deleteTeam(_Team team) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text('Remove team "${team.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final resp = await http.post(Uri.parse('${_baseUrl}Delete_Team'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': prefs.getString('CLIENTID') ?? '', 'Tsno': int.tryParse(team.tsno) ?? 0, 'Status': team.status, 'DB': prefs.getString('D_Database') ?? ''}));
      final raw = (jsonDecode(resp.body)['d'] ?? '').toString().trim();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(raw == '1' ? 'Team deleted.' : 'Failed to delete team.'), backgroundColor: raw == '1' ? Colors.green : Colors.red));
        if (raw == '1') _fetchTeams();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ─── Filtered / paged lists ───────────────────────────────────────────────

  List<_Employee> get _filteredEmployees {
    final list = _selectedTabIndex == 0 ? _activeEmployees : _inactiveEmployees;
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((e) => e.name.toLowerCase().contains(q) || e.mobile.toLowerCase().contains(q) || e.email.toLowerCase().contains(q) || e.gradeName.toLowerCase().contains(q)).toList();
  }

  List<_Team> get _filteredTeams {
    if (_searchQuery.isEmpty) return _teams;
    final q = _searchQuery.toLowerCase();
    return _teams.where((t) => t.name.toLowerCase().contains(q) || t.members.toLowerCase().contains(q) || t.status.toLowerCase().contains(q)).toList();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Employee Management', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        actions: const [AppUserMenu()],
      ),
      drawer: AppDrawer(currentRoute: 'Employee', companyName: _companyName),
      floatingActionButton: _buildFAB(cs),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildTopTabs(cs),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() { _searchQuery = v; _currentPage = 1; }),
            decoration: InputDecoration(
              hintText: _selectedTabIndex == 2 ? 'Search Teams...' : 'Search Employees...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(() { _searchQuery = ''; _currentPage = 1; }); })
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true, fillColor: cs.surface,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildContent(cs)),
        ]),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage.isNotEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_errorMessage, style: TextStyle(color: cs.error)),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: () => _selectedTabIndex == 2 ? _fetchTeams() : _fetchEmployees(active: _selectedTabIndex == 0), child: const Text('Retry')),
      ]));
    }

    if (_selectedTabIndex == 2) {
      final teams = _filteredTeams;
      if (teams.isEmpty) return Center(child: Text('No teams found.', style: TextStyle(color: cs.onSurfaceVariant)));
      return RefreshIndicator(onRefresh: _fetchTeams,
        child: ListView.builder(itemCount: teams.length, padding: const EdgeInsets.only(bottom: 80), itemBuilder: (_, i) => _buildTeamCard(teams[i], cs)));
    }

    final all = _filteredEmployees;
    final totalPages = (all.length / _pageSize).ceil().clamp(1, 9999);
    final page = _currentPage.clamp(1, totalPages);
    final start = (page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, all.length);
    final pageItems = all.sublist(start, end);

    if (all.isEmpty) return Center(child: Text('No employees found.', style: TextStyle(color: cs.onSurfaceVariant)));

    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _fetchEmployees(active: _selectedTabIndex == 0),
          child: ListView.builder(
            itemCount: pageItems.length,
            padding: const EdgeInsets.only(bottom: 8),
            itemBuilder: (_, i) => _buildEmployeeCard(pageItems[i], cs),
          ),
        ),
      ),
      _buildPagination(all.length, totalPages, page, cs),
    ]);
  }

  Widget _buildPagination(int total, int totalPages, int page, ColorScheme cs) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.only(top: 8, bottom: 8 + MediaQuery.of(context).padding.bottom + 64),
      decoration: BoxDecoration(color: cs.surface, border: Border(top: BorderSide(color: cs.outlineVariant))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${(page - 1) * _pageSize + 1}–${((page) * _pageSize).clamp(0, total)} of $total',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(width: 16),
        IconButton(icon: const Icon(Icons.chevron_left), iconSize: 20, padding: EdgeInsets.zero,
            onPressed: page > 1 ? () => setState(() => _currentPage = page - 1) : null),
        ...List.generate(totalPages, (i) {
          final p = i + 1;
          if (totalPages <= 5 || p == 1 || p == totalPages || (p - page).abs() <= 1) {
            return GestureDetector(
              onTap: () => setState(() => _currentPage = p),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 30, height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p == page ? mdaPrimaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: p == page ? mdaPrimaryBlue : cs.outlineVariant),
                ),
                child: Text('$p', style: TextStyle(fontSize: 12, color: p == page ? Colors.white : cs.onSurface, fontWeight: p == page ? FontWeight.bold : FontWeight.normal)),
              ),
            );
          }
          if ((p == 2 && page > 3) || (p == totalPages - 1 && page < totalPages - 2)) {
            return Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Text('...', style: TextStyle(color: cs.onSurfaceVariant)));
          }
          return const SizedBox.shrink();
        }),
        IconButton(icon: const Icon(Icons.chevron_right), iconSize: 20, padding: EdgeInsets.zero,
            onPressed: page < totalPages ? () => setState(() => _currentPage = page + 1) : null),
      ]),
    );
  }

  // ─── Avatar helpers ─────────────────────────────────────────────────────────

  // Generates initials from all words in the name ("TEST EMP New" → "TEN")
  String _getInitials(_Employee emp) {
    if (emp.initials.isNotEmpty) return emp.initials.toUpperCase();
    final parts = emp.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.map((p) => p[0]).join().toUpperCase();
    return '?';
  }

  // Deterministic color per employee so the same person always gets the same color
  Color _avatarColor(String initials) {
    const palette = [
      Color(0xFF0257E6), Color(0xFF00897B), Color(0xFF7B1FA2),
      Color(0xFFE64A19), Color(0xFF1976D2), Color(0xFF388E3C),
      Color(0xFFF57C00), Color(0xFF5D4037),
    ];
    if (initials.isEmpty) return palette[0];
    return palette[initials.codeUnitAt(0) % palette.length];
  }

  // ─── Cards ─────────────────────────────────────────────────────────────────

  Widget _buildEmployeeCard(_Employee emp, ColorScheme cs) {
    final initials = _getInitials(emp);
    final color    = _avatarColor(initials);
    final isActive = _selectedTabIndex == 0;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(side: BorderSide(color: cs.outlineVariant), borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showEmployeeDialog(emp: emp),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Avatar — FittedBox prevents long initials from overflowing
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.13),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(initials,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(width: 14),
            // Name + contact info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (emp.mobile.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.phone_outlined, size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(emp.mobile, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ]),
              ],
              if (emp.email.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.email_outlined, size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(child: Text(emp.email,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ])),
            const SizedBox(width: 8),
            // Grade badge + overflow menu stacked vertically
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              if (emp.gradeName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Text(emp.gradeName,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                )
              else
                const SizedBox.shrink(),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: ListTile(
                    leading: Icon(Icons.edit_outlined, color: mdaPrimaryBlue, size: 20),
                    title: Text('Edit'), contentPadding: EdgeInsets.zero, dense: true)),
                  PopupMenuItem(value: 'toggle', child: ListTile(
                    leading: Icon(isActive ? Icons.person_off_outlined : Icons.person_add_outlined,
                      color: isActive ? Colors.red : Colors.green, size: 20),
                    title: Text(isActive ? 'Deactivate' : 'Activate'),
                    contentPadding: EdgeInsets.zero, dense: true,
                  )),
                ],
                onSelected: (v) {
                  if (v == 'edit') _showEmployeeDialog(emp: emp);
                  if (v == 'toggle') _toggleEmployeeActive(emp);
                },
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildTeamCard(_Team team, ColorScheme cs) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(side: BorderSide(color: cs.outline.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text(team.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: mdaPrimaryBlue))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(6)),
              child: Text(team.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[800])),
            ),
          ]),
          const Divider(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.people, size: 15, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(child: Text(team.members.isNotEmpty ? team.members : 'No members', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
            InkWell(onTap: () => _showTeamDialog(existing: team), child: const Icon(Icons.edit, color: mdaPrimaryBlue, size: 20)),
            const SizedBox(width: 12),
            InkWell(onTap: () => _deleteTeam(team), child: const Icon(Icons.delete, color: Colors.red, size: 20)),
          ]),
        ]),
      ),
    );
  }

  // ─── FAB ───────────────────────────────────────────────────────────────────

  Widget _buildFAB(ColorScheme cs) {
    if (_selectedTabIndex == 2) {
      return FloatingActionButton.extended(
        onPressed: () => _showTeamDialog(),
        icon: const Icon(Icons.group_add), label: const Text('Add Team'),
        backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white,
      );
    }
    return FloatingActionButton.extended(
      onPressed: () => _showEmployeeDialog(),
      icon: const Icon(Icons.person_add), label: const Text('Add Employee'),
      backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white,
    );
  }

  // ─── Employee Dialog ────────────────────────────────────────────────────────

  void _showEmployeeDialog({_Employee? emp}) {
    final isEdit = emp != null;
    final nameCt     = TextEditingController(text: emp?.name ?? '');
    final passCt     = TextEditingController(text: emp?.pass ?? '');
    final mobileCt   = TextEditingController(text: emp?.mobile ?? '');
    final emailCt    = TextEditingController(text: emp?.email ?? '');
    final initialsCt = TextEditingController(text: emp?.initials ?? '');

    final empGrade = emp?.grade.trim() ?? '';
    final empDept  = emp?.deptId.trim() ?? '';
    // Validate against actual dropdown items — prevents DropdownButtonFormField assertion when saved grade/dept ID isn't in the list
    String? selGrade = _grades.any((g) => g['value'] == empGrade)
        ? empGrade
        : (_grades.isNotEmpty ? _grades[0]['value'] : null);
    String? selDept = _departments.any((d) => d['value'] == empDept)
        ? empDept
        : (_departments.isNotEmpty ? _departments[0]['value'] : null);
    String? selReport = emp?.parentId.isEmpty == false ? emp!.parentId : '0';
    bool autoAllot    = (emp?.autoAllot ?? '0') == '1';
    bool obscure      = true;
    bool saving       = false;
    final Map<String, String?> errors = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Employee' : 'Add Employee', style: const TextStyle(fontWeight: FontWeight.bold, color: mdaPrimaryBlue)),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dialogRow([
                // Point 1: auto-fill initials whenever name changes
                _dialogField('Name *', nameCt, errorText: errors['name'], onChanged: (v) {
                  final computed = _computeInitials(v);
                  if (computed.isNotEmpty) initialsCt.text = computed;
                  setSt(() => errors['name'] = null);
                }),
                _dialogField('Password *', passCt, obscure: obscure, errorText: errors['pass'],
                  suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18), onPressed: () => setSt(() => obscure = !obscure)),
                  onChanged: (v) => setSt(() => errors['pass'] = null)),
              ]),
              const SizedBox(height: 12),
              _dialogRow([
                _dialogField('Mobile', mobileCt, kb: TextInputType.phone, errorText: errors['mobile'],
                  onChanged: (v) => setSt(() => errors['mobile'] = null)),
                _dialogField('Email', emailCt, kb: TextInputType.emailAddress, errorText: errors['email'],
                  onChanged: (v) => setSt(() => errors['email'] = null)),
              ]),
              const SizedBox(height: 12),
              _dialogRow([
                _dialogDropdown('Grade *', _grades, selGrade, (v) => setSt(() { selGrade = v; errors['grade'] = null; }), errorText: errors['grade']),
                _dialogDropdown('Department', _departments, selDept, (v) => setSt(() => selDept = v)),
              ]),
              const SizedBox(height: 12),
              _dialogRow([
                _dialogDropdown('Reporting To', _reporters, selReport, (v) => setSt(() => selReport = v)),
                _dialogField('Initials *', initialsCt, errorText: errors['initials'],
                  onChanged: (v) => setSt(() => errors['initials'] = null)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Checkbox(value: autoAllot, onChanged: (v) => setSt(() => autoAllot = v ?? false)),
                const Expanded(child: Text('Auto allot customer when adding new', style: TextStyle(fontSize: 13))),
              ]),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: saving ? null : () async {
                final name     = nameCt.text.trim();
                final pass     = passCt.text.trim();
                final mobile   = mobileCt.text.trim();
                final email    = emailCt.text.trim();
                final initials = initialsCt.text.trim();

                // Validate all fields and show inline errors
                errors['name']     = name.isEmpty ? 'Name is required.' : null;
                errors['pass']     = pass.isEmpty ? 'Password is required.' : null;
                errors['grade']    = (selGrade == null || selGrade!.isEmpty) ? 'Grade is required.' : null;
                errors['initials'] = initials.isEmpty ? 'Initials are required.' : null;
                errors['mobile']   = (mobile.isNotEmpty && mobile.length != 10) ? 'Must be exactly 10 digits.' : null;
                errors['email']    = (email.isNotEmpty && !RegExp(r'^[\w.+-]+@[\w-]+\.\w{2,}$').hasMatch(email)) ? 'Invalid email format.' : null;
                if (errors.values.any((e) => e != null)) { setSt(() {}); return; }

                setSt(() => saving = true);
                Navigator.pop(ctx);
                await _saveEmployee(
                  name: name, pass: pass,
                  mobile: mobile, email: email,
                  gradeVal: selGrade ?? '0', depVal: selDept ?? '0',
                  reportVal: selReport ?? '0', initials: initials,
                  autoAllot: autoAllot ? 1 : 0,
                  sno: isEdit ? (int.tryParse(emp.sno) ?? 0) : 0,
                  oldMobile: emp?.mobile ?? '',
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white),
              child: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  // ─── Team Dialog ────────────────────────────────────────────────────────────

  void _showTeamDialog({_Team? existing}) {
    final isEdit = existing != null;
    final nameCt = TextEditingController(text: existing?.name ?? '');

    String? selStatus     = existing?.status.isEmpty == false ? existing!.status : (_statuses.isNotEmpty ? _statuses[0]['text'] : null);
    String? selNextStatus = existing?.nextStatus.isEmpty == false ? existing!.nextStatus : (_statuses.isNotEmpty ? _statuses[0]['text'] : null);

    // pre-select existing members by sno
    final preSelected = existing != null ? existing.empSno.split(',').where((s) => s.isNotEmpty).toSet() : <String>{};
    final selectedSnos = <String>{...preSelected};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Team' : 'Add Team', style: const TextStyle(fontWeight: FontWeight.bold, color: mdaPrimaryBlue)),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dialogRow([
                _dialogField('Team Name', nameCt),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Linked Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: selStatus,
                    isExpanded: true,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                    items: _statuses.map((s) => DropdownMenuItem(value: s['text'], child: Text(s['text']!, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setSt(() => selStatus = v),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Next Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selNextStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder()),
                  items: _statuses.map((s) => DropdownMenuItem(value: s['text'], child: Text(s['text']!, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setSt(() => selNextStatus = v),
                ),
              ]),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft, child: Text('Select Members', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _activeEmployees.length,
                  itemBuilder: (_, i) {
                    final emp = _activeEmployees[i];
                    final checked = selectedSnos.contains(emp.sno);
                    return CheckboxListTile(
                      dense: true,
                      value: checked,
                      onChanged: (v) => setSt(() {
                      if (v == true) { selectedSnos.add(emp.sno); } else { selectedSnos.remove(emp.sno); }
                    }),
                      title: Text(emp.name, style: const TextStyle(fontSize: 13)),
                      secondary: CircleAvatar(radius: 14, backgroundColor: mdaPrimaryBlue.withValues(alpha: 0.1),
                          child: Text(emp.initials, style: const TextStyle(fontSize: 11, color: mdaPrimaryBlue))),
                    );
                  },
                ),
              ),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCt.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team name is required.')));
                  return;
                }
                if (selectedSnos.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one member.')));
                  return;
                }
                Navigator.pop(ctx);
                await _saveTeam(
                  teamName: nameCt.text.trim(),
                  status: selStatus ?? '',
                  nextStatus: selNextStatus ?? '',
                  empSno: selectedSnos.join('^'),
                  existing: existing,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white),
              child: Text(isEdit ? 'Update' : 'Save'),
            ),
          ],
        );
      }),
    );
  }

  // ─── Dialog helpers ─────────────────────────────────────────────────────────

  Widget _dialogRow(List<Widget> children) => Row(
    children: children.map((w) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: w))).toList(),
  );

  Widget _dialogField(String label, TextEditingController ctrl, {bool obscure = false, TextInputType? kb, Widget? suffixIcon, ValueChanged<String>? onChanged, String? errorText}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: kb,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: const OutlineInputBorder(),
          errorText: errorText,
          suffixIcon: suffixIcon,
        ),
      ),
    ]);
  }

  // Derives initials from all words in a name ("TEST EMP New" → "TEN")
  String _computeInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.map((p) => p[0]).join().toUpperCase();
    return '';
  }

  Widget _dialogDropdown(String label, List<Map<String, String>> items, String? value, ValueChanged<String?> onChanged, {String? errorText}) {
    final validValue = items.any((i) => i['value'] == value) ? value : (items.isNotEmpty ? items[0]['value'] : null);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 4),
      InputDecorator(
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          border: const OutlineInputBorder(),
          errorText: errorText,
          errorStyle: const TextStyle(fontSize: 11),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: validValue,
            isExpanded: true,
            isDense: true,
            items: items.map((i) => DropdownMenuItem(
              value: i['value'],
              child: Text(i['text']!, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ]);
  }

  // ─── Tabs ──────────────────────────────────────────────────────────────────

  Widget _buildTopTabs(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.outline.withValues(alpha: 0.5))),
      child: Row(children: [
        Expanded(child: _buildTabItem('Active', Icons.verified_user, 0, cs)),
        Container(width: 1, height: 40, color: cs.outline.withValues(alpha: 0.5)),
        Expanded(child: _buildTabItem('Inactive', Icons.no_accounts, 1, cs)),
        Container(width: 1, height: 40, color: cs.outline.withValues(alpha: 0.5)),
        Expanded(child: _buildTabItem('Teams', Icons.groups, 2, cs)),
      ]),
    );
  }

  Widget _buildTabItem(String title, IconData icon, int index, ColorScheme cs) {
    final isActive = _selectedTabIndex == index;
    final count = index == 0 ? _activeEmployees.length : (index == 1 ? _inactiveEmployees.length : _teams.length);
    return InkWell(
      onTap: () {
        if (_selectedTabIndex == index) return;
        setState(() { _selectedTabIndex = index; _searchQuery = ''; _searchCtrl.clear(); _currentPage = 1; });
        if (index == 2) _fetchTeams();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? mdaPrimaryBlue.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: index == 0 ? const Radius.circular(8) : Radius.zero,
            right: index == 2 ? const Radius.circular(8) : Radius.zero,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: isActive ? mdaPrimaryBlue : cs.onSurfaceVariant, size: 20),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: TextStyle(color: isActive ? mdaPrimaryBlue : cs.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 12)),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive ? mdaPrimaryBlue : cs.onSurfaceVariant.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                  style: TextStyle(color: isActive ? Colors.white : cs.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class _Employee {
  final String sno, name, email, grade, mobile, gradeName, initials, autoAllot, heir, parentId, deptId, pass, uCode, rawData;
  const _Employee({
    required this.sno, required this.name, required this.email, required this.grade,
    required this.mobile, required this.gradeName, required this.initials,
    required this.autoAllot, required this.heir, required this.parentId,
    required this.deptId, required this.pass, required this.uCode, required this.rawData,
  });
}

class _Team {
  final String name, tsno, members, empSno, teamId, status, nextStatus;
  const _Team({required this.name, required this.tsno, required this.members, required this.empSno, required this.teamId, required this.status, required this.nextStatus});
}
