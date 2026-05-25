// File: lib/features/dashboard/presentation/screens/dashboard_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mda_crm/shared/widgets/app_drawer.dart';
import 'package:mda_crm/shared/widgets/app_user_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // 0: Employee Wise, 1: Status Wise, 2: Activity Wise
  int _selectedTabIndex = 0;
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _entriesPerPage = 10;

  String _clientId = '';
  String _sno = '';
  String _db = '';
  String _companyName = '';

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _tableData = [];

  static const _tabConfig = [
    {'type': 'uname',       'type2': 'UCode',          'colLabel': 'Employee Name'},
    {'type': 'p14_Status',  'type2': 'p14_Status',     'colLabel': 'Status Name'},
    {'type': 'P5_StatName', 'type2': 'P14_TypeOfCall', 'colLabel': 'Activity Name'},
  ];

  @override
  void initState() {
    super.initState();
    _loadAndFetch();
  }

  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _clientId = prefs.getString('CLIENTID') ?? '';
      _sno = prefs.getString('sno') ?? '';
      _db = prefs.getString('D_Database') ?? '';
      _companyName = prefs.getString('O_Name') ?? '';
    });
    await _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _tableData = [];
    });

    try {
      final cfg = _tabConfig[_selectedTabIndex];
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Dashboard.aspx/fillEmpList'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept-Language': 'en-US',
        },
        body: jsonEncode({
          'ClientID': _clientId,
          'Type': cfg['type'],
          'Type2': cfg['type2'],
          'sno': _sno,
          'DB': _db,
          'showAllC': 0,
        }),
      );

      final decoded = jsonDecode(response.body);
      final rdata = decoded['d'] as String? ?? '';

      if (rdata.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      if (rdata.contains('Something went wrong')) {
        setState(() {
          _isLoading = false;
          _errorMessage = rdata;
        });
        return;
      }

      setState(() {
        _tableData = _parseResponse(rdata);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
      });
    }
  }

  List<Map<String, dynamic>> _parseResponse(String rdata) {
    final Map<String, Map<String, dynamic>> empMap = {};

    void processGroup(String dataStr, String key) {
      if (dataStr.isEmpty) return;
      for (final entry in dataStr.split('#')) {
        if (!entry.contains('^')) continue;
        final parts = entry.split('^');
        final name = parts[0].trim();
        if (name.isEmpty) continue;
        empMap.putIfAbsent(name, () => {
          'name': name,
          'field': '',
          'o_over_due': 0, 'o_due_today': 0, 'added': 0,
          'calls': 0, 'over_due': 0, 'due_today': 0, 'due_later': 0,
        });
        empMap[name]![key] = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        // parts[2] is Type2 (UCode / status name / TypeOfCall code) — needed for fillCallList
        if (parts.length > 2 && (empMap[name]!['field'] as String).isEmpty) {
          empMap[name]!['field'] = parts[2].trim();
        }
      }
    }

    // Server response: OpenOverDue~OpenDueToday~AddedToday~CompToday~overDue~DueToday~DueLater
    final groups = rdata.split('~');
    if (groups.length >= 7) {
      processGroup(groups[0], 'o_over_due');
      processGroup(groups[1], 'o_due_today');
      processGroup(groups[2], 'added');
      processGroup(groups[3], 'calls');
      processGroup(groups[4], 'over_due');
      processGroup(groups[5], 'due_today');
      processGroup(groups[6], 'due_later');
    }

    final list = empMap.values.toList();
    list.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    return list;
  }

  List<Map<String, dynamic>> get _filteredData {
    if (_searchQuery.isEmpty) return _tableData;
    final q = _searchQuery.toLowerCase();
    return _tableData.where((row) {
      return row.values.any((v) => v.toString().toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        actions: const [AppUserMenu()],
      ),
      drawer: AppDrawer(currentRoute: 'Dashboard', companyName: _companyName),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          return Padding(
            padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Responsive Tabs
                if (isMobile)
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildTabCard(0, 'Employee Wise', Icons.person, cs)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTabCard(1, 'Status Wise', Icons.check_circle_outline, cs)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTabCard(2, 'Activity Wise', Icons.show_chart, cs),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: _buildTabCard(0, 'Employee Wise', Icons.person, cs)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTabCard(1, 'Status Wise', Icons.check_circle_outline, cs)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTabCard(2, 'Activity Wise', Icons.show_chart, cs)),
                    ],
                  ),

                SizedBox(height: isMobile ? 16 : 24),

                // Data Table Card
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: cs.shadow.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Search Bar Header
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: isMobile
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.end,
                            children: [
                              Text('Search: ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface,
                                      fontSize: 15)),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: isMobile ? 1 : 0,
                                child: SizedBox(
                                  width: isMobile ? null : 250,
                                  height: 36,
                                  child: TextField(
                                    style: TextStyle(color: cs.onSurface),
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 0),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide:
                                              BorderSide(color: cs.outline)),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          borderSide:
                                              BorderSide(color: cs.outline)),
                                      focusedBorder: OutlineInputBorder(
                                          borderSide:
                                              const BorderSide(color: mdaPrimaryBlue)),
                                    ),
                                    onChanged: (val) =>
                                        setState(() { _searchQuery = val; _currentPage = 1; }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Table Content
                        Expanded(child: _buildTableContent(cs)),

                        Divider(height: 1, color: cs.outlineVariant),

                        // Pagination Footer
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Builder(builder: (context) {
                            final total = _filteredData.length;
                            final start = total == 0 ? 0 : (_currentPage - 1) * _entriesPerPage + 1;
                            final end = (_currentPage * _entriesPerPage).clamp(0, total);
                            final label = total == 0
                                ? 'No entries found'
                                : 'Showing $start to $end of $total entries';
                            return isMobile
                                ? Column(
                                    children: [
                                      Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                                      const SizedBox(height: 12),
                                      _buildPaginationButtons(cs),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
                                      _buildPaginationButtons(cs),
                                    ],
                                  );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableContent(ColorScheme cs) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 40),
            const SizedBox(height: 12),
            Text(_errorMessage!,
                style: TextStyle(color: cs.error),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_tableData.isEmpty) {
      return Center(
          child: Text('No data available.',
              style: TextStyle(color: cs.onSurfaceVariant)));
    }
    return _buildCardList(cs);
  }

  Widget _buildTabCard(int index, String title, IconData icon, ColorScheme cs) {
    final isActive = _selectedTabIndex == index;
    return InkWell(
      onTap: () {
        if (_selectedTabIndex != index) {
          setState(() {
            _selectedTabIndex = index;
            _searchQuery = '';
            _currentPage = 1;
          });
          _fetchData();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? mdaPrimaryBlue : cs.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            if (isActive)
              BoxShadow(
                  color: mdaPrimaryBlue.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            if (!isActive)
              BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  color: isActive ? Colors.white : mdaPrimaryBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  color: isActive ? Colors.white : cs.onSurface,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardList(ColorScheme cs) {
    final filtered = _filteredData;
    final int startIndex = (_currentPage - 1) * _entriesPerPage;
    final int endIndex = (startIndex + _entriesPerPage).clamp(0, filtered.length);
    final data = filtered.sublist(startIndex, endIndex);

    final totals = <String, int>{
      'over_due':    filtered.fold(0, (s, r) => s + (r['over_due']    as int)),
      'due_today':   filtered.fold(0, (s, r) => s + (r['due_today']   as int)),
      'due_later':   filtered.fold(0, (s, r) => s + (r['due_later']   as int)),
      'o_over_due':  filtered.fold(0, (s, r) => s + (r['o_over_due']  as int)),
      'o_due_today': filtered.fold(0, (s, r) => s + (r['o_due_today'] as int)),
      'added':       filtered.fold(0, (s, r) => s + (r['added']       as int)),
      'calls':       filtered.fold(0, (s, r) => s + (r['calls']       as int)),
    };

    final itemCount = data.length + (filtered.isNotEmpty ? 1 : 0);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < data.length) return _buildDashboardCard(cs, data[index]);
        return _buildTotalCard(cs, totals);
      },
    );
  }

  Widget _buildTotalCard(ColorScheme cs, Map<String, int> t) {
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: mdaPrimaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mdaPrimaryBlue.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TOTAL', style: tt.titleSmall!.copyWith(color: mdaPrimaryBlue, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
          IntrinsicHeight(
            child: Row(children: [
              _metricCell(cs, tt, Icons.warning_amber_rounded, 'Over Due',  t['over_due']!,  Colors.red[700]!),
              _vertDivider(cs),
              _metricCell(cs, tt, Icons.today_outlined,        'Due Today', t['due_today']!, Colors.orange[800]!),
              _vertDivider(cs),
              _metricCell(cs, tt, Icons.schedule_outlined,     'Due Later', t['due_later']!, mdaPrimaryBlue),
            ]),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
          IntrinsicHeight(
            child: Row(children: [
              _smallMetricCell(cs, tt, 'O. Over Due',  t['o_over_due']!),
              _vertDivider(cs),
              _smallMetricCell(cs, tt, 'O. Due Today', t['o_due_today']!),
              _vertDivider(cs),
              _smallMetricCell(cs, tt, 'Added',        t['added']!),
              _vertDivider(cs),
              _smallMetricCell(cs, tt, 'Calls Made',   t['calls']!),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildDashboardCard(ColorScheme cs, Map<String, dynamic> row) {
    final name = row['name'].toString();
    final tt   = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCallList(row),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: tt.titleLarge!.copyWith(
                  color: mdaPrimaryBlue,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _metricCell(cs, tt, Icons.warning_amber_rounded, 'Over Due',
                        row['over_due'] as int, Colors.red[700]!),
                    _vertDivider(cs),
                    _metricCell(cs, tt, Icons.today_outlined, 'Due Today',
                        row['due_today'] as int, Colors.orange[800]!),
                    _vertDivider(cs),
                    _metricCell(cs, tt, Icons.schedule_outlined, 'Due Later',
                        row['due_later'] as int, mdaPrimaryBlue),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              IntrinsicHeight(
                child: Row(
                  children: [
                    _smallMetricCell(cs, tt, 'O. Over Due',  row['o_over_due']  as int),
                    _vertDivider(cs),
                    _smallMetricCell(cs, tt, 'O. Due Today', row['o_due_today'] as int),
                    _vertDivider(cs),
                    _smallMetricCell(cs, tt, 'Added',        row['added']       as int),
                    _vertDivider(cs),
                    _smallMetricCell(cs, tt, 'Calls Made',   row['calls']       as int),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricCell(ColorScheme cs, TextTheme tt, IconData icon, String label, int value, Color color) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: (tt.titleMedium!.fontSize ?? 16) * 1.2, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: tt.labelMedium!.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value.toString(),
            style: tt.headlineSmall!.copyWith(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _vertDivider(ColorScheme cs) {
    return VerticalDivider(width: 1, thickness: 1, color: cs.outlineVariant);
  }

  Widget _smallMetricCell(ColorScheme cs, TextTheme tt, String label, int value) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            style: tt.titleLarge!.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: tt.labelSmall!.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showCallList(Map<String, dynamic> row) {
    final type = _tabConfig[_selectedTabIndex]['type']!;
    final field = row['field']?.toString() ?? '';
    final name = row['name']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (_) => _CallListDialog(
        clientId: _clientId,
        db: _db,
        sno: _sno,
        type: type,
        field: field,
        title: name,
      ),
    );
  }

  Widget _buildPaginationButtons(ColorScheme cs) {
    final int totalPages = (_filteredData.length / _entriesPerPage).ceil().clamp(1, 999);
    final bool canPrev = _currentPage > 1;
    final bool canNext = _currentPage < totalPages;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: canPrev ? () => setState(() => _currentPage--) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: canPrev ? cs.surfaceContainerHighest : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
            ),
            child: Text('Previous',
                style: TextStyle(color: canPrev ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.4))),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: mdaPrimaryBlue,
          child: Text('$_currentPage',
              style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold)),
        ),
        GestureDetector(
          onTap: canNext ? () => setState(() => _currentPage++) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: canNext ? cs.surfaceContainerHighest : cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
            ),
            child: Text('Next',
                style: TextStyle(color: canNext ? mdaPrimaryBlue : mdaPrimaryBlue.withValues(alpha: 0.4))),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Call List Dialog — shown when a dashboard row is tapped
// ---------------------------------------------------------------------------

class _CallListDialog extends StatefulWidget {
  final String clientId;
  final String db;
  final String sno;
  final String type;
  final String field;
  final String title;

  const _CallListDialog({
    required this.clientId,
    required this.db,
    required this.sno,
    required this.type,
    required this.field,
    required this.title,
  });

  @override
  State<_CallListDialog> createState() => _CallListDialogState();
}

class _CallListDialogState extends State<_CallListDialog> {
  bool _isLoading = true;
  List<Map<String, String>> _calls = [];
  String? _error;
  int _currentPage = 1;
  static const int _entriesPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchCallList();
  }

  Future<void> _fetchCallList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final showAllC =
          (prefs.getString('showAllCustomer') ?? '').toLowerCase() == 'true' ? 1 : 0;

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Dashboard.aspx/fillCallList'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': widget.clientId,
          'DB': widget.db,
          'Type': widget.type,
          'Field': widget.field,
          'sno': widget.sno,
          'showAllC': showAllC,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final rdata = jsonDecode(response.body)['d']?.toString() ?? '';
        if (rdata.isEmpty || rdata.contains('Something went wrong')) {
          setState(() { _isLoading = false; _error = 'No calls found.'; });
          return;
        }
        final calls = rdata.split('#').where((r) => r.contains('^')).map((r) {
          final p = r.split('^');
          return {
            'uid':       p.length > 2  ? p[2]  : '',
            'cname':     p.length > 4  ? p[4]  : '',
            'uname':     p.length > 5  ? p[5]  : '',
            'ndate':     p.length > 6  ? p[6]  : '',
            'status':    p.length > 7  ? p[7]  : '',
            'actName':   p.length > 10 ? p[10] : '',
            'prosCust':  p.length > 11 ? p[11] : '',
            'nCallType': p.length > 12 ? p[12] : '',
            'statColor': p.length > 13 ? p[13] : '',
            'sno11':     p.length > 14 ? p[14] : '',
          };
        }).toList();
        setState(() { _calls = calls; _isLoading = false; });
      } else {
        setState(() { _isLoading = false; _error = 'Server error (${response.statusCode}).'; });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _error = 'Network error.'; });
    }
  }

@override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: mdaPrimaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildContent(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildCallCard(ColorScheme cs, Map<String, String> call) {
    final isCustomer = call['prosCust']?.toLowerCase() == 'true';
    final isVisit    = call['nCallType'] == 'Visit';
    final statColor  = call['statColor'] ?? '';
    final uid        = call['uid'] ?? '';
    final sno11      = call['sno11'] ?? '';

    final Color badgeBg;
    final Color badgeText;
    if (statColor == 'Green') {
      badgeBg   = Colors.green[100]!;
      badgeText = Colors.green[900]!;
    } else if (statColor == 'Red') {
      badgeBg   = Colors.red[100]!;
      badgeText = Colors.red[900]!;
    } else {
      badgeBg   = Colors.amber[100]!;
      badgeText = Colors.orange[900]!;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: uid.isNotEmpty
            ? () => showDialog(
                  context: context,
                  builder: (_) => _CallDetailDialog(
                    clientId: widget.clientId,
                    db: widget.db,
                    uid: uid,
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(children: [
                        TextSpan(
                          text: isCustomer ? 'C  ' : 'P  ',
                          style: TextStyle(
                            color: isCustomer ? mdaPrimaryBlue : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        TextSpan(
                          text: call['cname'] ?? '',
                          style: const TextStyle(
                            color: mdaPrimaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 130),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      call['status'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                call['uname'] ?? '',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  const Icon(Icons.task_alt_outlined, size: 15, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Activity',
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        Text(
                          call['actName'] ?? '',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.calendar_today_outlined, size: 15, color: Colors.grey),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Next Date',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: call['ndate'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: cs.onSurface,
                            ),
                          ),
                          TextSpan(
                            text: isVisit ? '  V' : '  C',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isVisit ? Colors.red : mdaPrimaryBlue,
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ),
                  if (sno11.isNotEmpty && sno11 != '0') ...[
                    const SizedBox(width: 14),
                    const Icon(Icons.phone, color: mdaPrimaryBlue, size: 20),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: mdaPrimaryBlue));
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: cs.onSurfaceVariant)));
    if (_calls.isEmpty) return Center(child: Text('No calls found.', style: TextStyle(color: cs.onSurfaceVariant)));

    final int total = _calls.length;
    final int totalPages = (total / _entriesPerPage).ceil().clamp(1, 999);
    final int start = (_currentPage - 1) * _entriesPerPage;
    final int end = (start + _entriesPerPage).clamp(0, total);
    final paged = _calls.sublist(start, end);
    final bool canPrev = _currentPage > 1;
    final bool canNext = _currentPage < totalPages;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: paged.length,
            itemBuilder: (context, index) => _buildCallCard(cs, paged[index]),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Column(
            children: [
              Text(
                'Showing ${total == 0 ? 0 : start + 1} to $end of $total entries',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: canPrev ? () => setState(() => _currentPage--) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        'Previous',
                        style: TextStyle(
                          color: canPrev ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    color: mdaPrimaryBlue,
                    child: Text(
                      '$_currentPage',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: canNext ? () => setState(() => _currentPage++) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                      child: Text(
                        'Next',
                        style: TextStyle(
                          color: canNext ? mdaPrimaryBlue : mdaPrimaryBlue.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Call Detail Dialog — shown when the play icon is tapped in _CallListDialog
// ---------------------------------------------------------------------------

class _CallDetailDialog extends StatefulWidget {
  final String clientId;
  final String db;
  final String uid;

  const _CallDetailDialog({
    required this.clientId,
    required this.db,
    required this.uid,
  });

  @override
  State<_CallDetailDialog> createState() => _CallDetailDialogState();
}

class _CallDetailDialogState extends State<_CallDetailDialog> {
  bool _isLoading = true;
  List<Map<String, String>> _details = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCallDetail();
  }

  Future<void> _fetchCallDetail() async {
    try {
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Calling.aspx/fillCallDetail'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': widget.clientId,
          'uid': widget.uid,
          'DB': widget.db,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final rdata = jsonDecode(response.body)['d']?.toString() ?? '';
        if (rdata.isEmpty || rdata.contains('Something went wrong')) {
          setState(() { _isLoading = false; _error = 'No details found.'; });
          return;
        }
        final details = rdata.split('#').where((r) => r.contains('^')).map((r) {
          final p = r.split('^');
          return {
            'date':   p[0],
            'remark': p.length > 1 ? p[1] : '',
            'status': p.length > 2 ? p[2] : '',
          };
        }).toList();
        details.sort((a, b) => (a['date'] ?? '').toLowerCase().compareTo((b['date'] ?? '').toLowerCase()));
        setState(() { _details = details; _isLoading = false; });
      } else {
        setState(() { _isLoading = false; _error = 'Server error (${response.statusCode}).'; });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _error = 'Network error.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: mdaPrimaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Call Details',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildContent(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: mdaPrimaryBlue));
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: cs.onSurfaceVariant)));
    if (_details.isEmpty) return Center(child: Text('No details available.', style: TextStyle(color: cs.onSurfaceVariant)));

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(cs.surfaceContainerHighest),
          columnSpacing: 24,
          horizontalMargin: 16,
          columns: const [
            DataColumn(label: Text('Date',   style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Remark', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _details.asMap().entries.map((e) {
            final rowColor = e.key.isEven ? cs.surfaceContainerLowest : cs.surface;
            final detail = e.value;
            return DataRow(
              color: WidgetStateProperty.all(rowColor),
              cells: [
                DataCell(
                  SizedBox(
                    width: 155,
                    child: Text(detail['date'] ?? '', style: const TextStyle(fontSize: 13)),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      detail['remark'] ?? '',
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
