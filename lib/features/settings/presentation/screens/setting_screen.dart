import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/widgets/app_drawer.dart';
import 'package:mda_crm/shared/widgets/app_user_menu.dart';
import 'package:mda_crm/shared/theme/theme_notifier.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  int _selectedTabIndex = 0;
  String _companyName = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _items = [];

  // Table search & pagination (used by Call Status table)
  final TextEditingController _tableSearchCtrl = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _pageSize = 10;

  final List<Map<String, dynamic>> _tabs = [
    {'title': 'Call Status', 'icon': Icons.phone_in_talk, 'chk': 'Status', 'type1': 'Status'},
    {'title': 'Products', 'icon': Icons.shopping_cart, 'chk': 'PRO', 'type1': 'PRO'},
    {'title': 'Activities', 'icon': Icons.task, 'chk': 'ACT', 'type1': 'ACT'},
    {'title': 'Categories', 'icon': Icons.category, 'chk': 'CAT', 'type1': 'CAT'},
    {'title': 'Sources', 'icon': Icons.link, 'chk': 'SRC', 'type1': 'SRC'},
    {'title': 'Scheduler', 'icon': Icons.schedule, 'chk': 'Scheduler', 'type1': 'Scheduler'},
    {'title': 'Theme', 'icon': Icons.palette, 'chk': '', 'type1': ''},
  ];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _companyName = p.getString('O_Name') ?? '');
    });
    _fetchData(0);
  }

  @override
  void dispose() {
    _tableSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData(int tabIndex) async {
    if (tabIndex == 6) {
      if (mounted) setState(() => _items = []);
      return; // Theme has no API
    }
    setState(() { _isLoading = true; _searchQuery = ''; _currentPage = 1; _tableSearchCtrl.clear(); });
    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString('CLIENTID') ?? 'Demo';
    final db = prefs.getString('D_Database') ?? 'mdapulse';
    
    final chk = _tabs[tabIndex]['chk'] as String;
    
    try {
      if (tabIndex == 0) {
        final response = await http.post(
          Uri.parse('https://webservices.mdapulse.com/Setting.aspx/FillList'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'ClientId': clientId, 'chk': chk, 'DB': db}),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body)['d']?.toString() ?? '';
          _parseStatusData(data);
        }
      } else if (tabIndex == 5) {
        final response = await http.post(
          Uri.parse('https://webservices.mdapulse.com/Setting.aspx/FillScheduler'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'ClientId': clientId, 'DB': db}),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body)['d']?.toString() ?? '';
          _parseSchedulerData(data);
        }
      } else {
        final response = await http.post(
          Uri.parse('https://webservices.mdapulse.com/Setting.aspx/ProductList'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'ClientId': clientId, 'chk': chk, 'DB': db}),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body)['d']?.toString() ?? '';
          _parseGenericData(data);
        }
      }
    } catch (_) {
      _items = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _parseStatusData(String data) {
    if (data.isEmpty) {
      _items = [];
      return;
    }
    final rows = data.split('#').where((r) => r.isNotEmpty).toList();
    _items = rows.map((r) {
      final arr = r.split('^');
      return {
        'sno': arr.isNotEmpty ? arr[0] : '',
        'name': arr.length > 1 ? arr[1] : '',
        'type': arr.length > 2 ? arr[2] : '',
        'saleRej': arr.length > 3 ? arr[3] : '',
        'color': arr.length > 4 ? _parseColor(arr[4]) : Colors.grey.shade300,
        'category': arr.length > 5 ? arr[5] : '',
      };
    }).toList();
  }

  void _parseGenericData(String data) {
    if (data.isEmpty) {
      _items = [];
      return;
    }
    final rows = data.split('#').where((r) => r.isNotEmpty).toList();
    _items = rows.map((r) {
      final arr = r.split('^');
      return {
        'sno': arr.isNotEmpty ? arr[0] : '',
        'name': arr.length > 1 ? arr[1] : '',
      };
    }).toList();
  }

  void _parseSchedulerData(String data) {
    if (data.isEmpty) {
      _items = [];
      return;
    }
    final rows = data.split('#').where((r) => r.isNotEmpty).toList();
    _items = rows.map((r) {
      final arr = r.split('^');
      return {
        'sno': arr.isNotEmpty ? arr[0] : '', // SchedulerID
        'ClientId': arr.length > 1 ? arr[1] : '',
        'Function_type': arr.length > 2 ? arr[2] : '',
        'Mobile': arr.length > 3 ? arr[3] : '',
        'Start_time': arr.length > 4 ? arr[4] : '',
        'End_time': arr.length > 5 ? arr[5] : '',
        'Frequency': arr.length > 6 ? arr[6] : '',
        'name': arr.length > 7 ? arr[7] : '', // EmpName
      };
    }).toList();
  }

  Color _parseColor(String raw) {
    if (raw.isEmpty) return Colors.grey.shade300;
    // Web version stores color as a name ("Green", "Yellow", "Red", "Blue", "Grey")
    switch (raw.trim().toLowerCase()) {
      case 'green':  return const Color(0xFF4CAF50);
      case 'yellow': return const Color(0xFFFFC107);
      case 'red':    return const Color(0xFFF44336);
      case 'blue':   return const Color(0xFF0257E6);
      case 'grey':
      case 'gray':   return Colors.grey.shade300;
    }
    // Fallback: treat as hex (e.g. "#4CAF50" from older Flutter saves)
    String hexStr = raw.toUpperCase().replaceAll('#', '');
    if (hexStr.length == 6) hexStr = 'FF$hexStr';
    return Color(int.tryParse(hexStr, radix: 16) ?? 0xFFE0E0E0);
  }

  Future<void> _deleteItem(String sno) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final clientId = prefs.getString('CLIENTID') ?? 'Demo';
    final db = prefs.getString('D_Database') ?? 'mdapulse';
    final type1 = _tabs[_selectedTabIndex]['type1'] as String;
    
    try {
      if (type1 == 'Scheduler') {
        final response = await http.post(
          Uri.parse('https://webservices.mdapulse.com/Setting.aspx/DeleteScheduler'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'ClientId': clientId, 'SID': int.tryParse(sno) ?? 0}),
        );
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body)['d']?.toString() ?? '';
          if (result == '1') {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
            _fetchData(_selectedTabIndex);
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete')));
            setState(() => _isLoading = false);
          }
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        final response = await http.post(
          Uri.parse('https://webservices.mdapulse.com/Setting.aspx/DeleteSetting'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'ClientId': clientId, 'Sno': sno, 'DB': db, 'type1': type1}),
        );
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body)['d']?.toString() ?? '';
          if (result == '1') {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
            _fetchData(_selectedTabIndex);
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete')));
            setState(() => _isLoading = false);
          }
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        actions: const [AppUserMenu()],
      ),
      drawer: AppDrawer(currentRoute: 'Settings', companyName: _companyName),
      floatingActionButton: _buildSmartFAB(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: cs.surface,
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.6,
              ),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final bool isSelected = _selectedTabIndex == index;
                return GestureDetector(
                  onTap: () {
                    if (_selectedTabIndex != index) {
                      setState(() {
                        _selectedTabIndex = index;
                        _items = [];
                      });
                      _fetchData(index);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? mdaPrimaryBlue : cs.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? mdaPrimaryBlue : cs.outline.withValues(alpha: 0.5)),
                      boxShadow: isSelected
                          ? [BoxShadow(color: mdaPrimaryBlue.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 3))]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_tabs[index]['icon'], color: isSelected ? Colors.white : mdaPrimaryBlue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _tabs[index]['title'],
                          style: TextStyle(color: isSelected ? Colors.white : cs.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(16.0), child: _buildTabContent()),
          ),
        ],
      ),
    );
  }

  Widget? _buildSmartFAB() {
    // Tab 0 (Call Status) has its add button inline in the table header
    if (_selectedTabIndex == 0 || _selectedTabIndex == 6) return null;
    String label = 'Add ';
    VoidCallback action = () => _showGenericAddDialog(_tabs[_selectedTabIndex]['title']);
    if (_selectedTabIndex == 1) { label += 'Product'; }
    else if (_selectedTabIndex == 2) { label += 'Activity'; }
    else if (_selectedTabIndex == 3) { label += 'Category'; }
    else if (_selectedTabIndex == 4) { label += 'Source'; }
    else if (_selectedTabIndex == 5) { label += 'Scheduler'; action = _showAddSchedulerDialog; }
    return FloatingActionButton.extended(
      onPressed: action, icon: const Icon(Icons.add), label: Text(label),
      backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white,
    );
  }

  Widget _buildTabContent() {
    if (_selectedTabIndex == 6) return _buildThemeSettings();
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text('No items found.'));

    if (_selectedTabIndex == 0) return _buildStatusTable();
    if (_selectedTabIndex == 5) return _buildSchedulerList();
    return _buildGenericList(showMergeButton: _selectedTabIndex == 1);
  }

  Widget _buildStatusTable() {
    final filtered = _searchQuery.isEmpty
        ? _items
        : _items.where((i) => (i['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final total = filtered.length;
    final totalPages = (total / _pageSize).ceil().clamp(1, 99999);
    final safeCurrentPage = _currentPage.clamp(1, totalPages);
    final startIdx = (safeCurrentPage - 1) * _pageSize;
    final endIdx = (startIdx + _pageSize).clamp(0, total);
    final pageItems = filtered.sublist(startIdx, endIdx);

    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    const headerColor = Color(0xFFF1F3F4);
    const borderColor = Color(0xFFDEE2E6);

    return Column(children: [
      // ── Toolbar: search left, Add Status right ──────────────────────────
      Row(children: [
        const Text('Search: ', style: TextStyle(fontSize: 13)),
        Expanded(
          child: SizedBox(
            height: 34,
            child: TextField(
              controller: _tableSearchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              onChanged: (v) => setState(() { _searchQuery = v; _currentPage = 1; }),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _showAddStatusDialog,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Status'),
          style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
        ),
      ]),
      const SizedBox(height: 12),
      // ── Table ───────────────────────────────────────────────────────────
      Expanded(child: Column(children: [
        // Header row
        Container(
          color: headerColor,
          child: Row(children: [
            _th('Sno.', flex: 1, align: TextAlign.center, style: headerStyle),
            _th('Status', flex: 4, align: TextAlign.center, style: headerStyle),
            _th('Action', flex: 2, align: TextAlign.center, style: headerStyle),
          ]),
        ),
        const Divider(height: 1, color: borderColor),
        // Data rows
        Expanded(
          child: pageItems.isEmpty
              ? const Center(child: Text('No items found.'))
              : ListView.separated(
                  itemCount: pageItems.length,
                  separatorBuilder: (_, r) => const Divider(height: 1, color: borderColor),
                  itemBuilder: (ctx, i) {
                    final item = pageItems[i];
                    final color = item['color'] as Color;
                    final hasColor = color.toARGB32() != 0xFFE0E0E0;
                    final rowBg = hasColor ? color.withValues(alpha: 0.18) : (i.isEven ? Colors.white : const Color(0xFFEBEBEB));
                    final sno = startIdx + i + 1;
                    return Container(
                      color: rowBg,
                      child: Row(children: [
                        // Sno
                        Expanded(flex: 1, child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text('$sno', textAlign: TextAlign.center, style: hasColor ? TextStyle(color: color, fontWeight: FontWeight.w600) : null),
                        )),
                        // Status name or badge
                        Expanded(flex: 4, child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: hasColor
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                                  child: Text(item['name'], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                )
                              : Text(item['name'], style: const TextStyle(fontSize: 13))),
                        )),
                        // Action buttons
                        Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _iconActionBtn(Icons.edit, mdaPrimaryBlue, () {
                            _showAddStatusDialog(itemToEdit: item);
                          }),
                          const SizedBox(width: 2),
                          _iconActionBtn(Icons.delete, Colors.red, () {
                            _deleteItem(item['sno'].toString());
                          }),
                        ])),
                      ]),
                    );
                  },
                ),
        ),
      ])),
      const Divider(height: 1, color: borderColor),
      // ── Footer: count row + pagination row (stacked to avoid overflow) ──
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Showing ${total == 0 ? 0 : startIdx + 1} to $endIdx of $total entries',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _pageBtn('Previous', safeCurrentPage > 1, () => setState(() => _currentPage = safeCurrentPage - 1)),
              ...List.generate(totalPages, (i) {
                final p = i + 1;
                final isActive = p == safeCurrentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: isActive ? null : () => setState(() => _currentPage = p),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 32, height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive ? mdaPrimaryBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isActive ? mdaPrimaryBlue : Colors.grey.shade300),
                      ),
                      child: Text('$p', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.black87)),
                    ),
                  ),
                );
              }),
              _pageBtn('Next', safeCurrentPage < totalPages, () => setState(() => _currentPage = safeCurrentPage + 1)),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _th(String label, {required int flex, TextAlign align = TextAlign.left, TextStyle? style}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Text(label, textAlign: align, style: style),
      ),
    );
  }

  Widget _iconActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }

  Widget _pageBtn(String label, bool enabled, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
            color: enabled ? Colors.white : Colors.grey.shade100,
          ),
          child: Text(label, style: TextStyle(fontSize: 12, color: enabled ? Colors.black87 : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildSchedulerList() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    const headerColor = Color(0xFFF1F3F4);
    const borderColor = Color(0xFFDEE2E6);

    return Column(children: [
      // Header row
      Container(
        color: headerColor,
        child: Row(children: [
          _th('Sno.', flex: 1, align: TextAlign.center, style: headerStyle),
          _th('Employee', flex: 3, style: headerStyle),
          _th('Mobile', flex: 2, style: headerStyle),
          _th('Time', flex: 3, style: headerStyle),
          _th('Action', flex: 2, align: TextAlign.center, style: headerStyle),
        ]),
      ),
      const Divider(height: 1, color: borderColor),
      Expanded(
        child: _items.isEmpty
            ? const Center(child: Text('No items found.'))
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, r) => const Divider(height: 1, color: borderColor),
                itemBuilder: (ctx, i) {
                  final item = _items[i];
                  final rowBg = i.isEven ? Colors.white : const Color(0xFFEBEBEB);
                  final time = '${item['Start_time']} - ${item['End_time']} (${item['Frequency']}m)';
                  return Container(
                    color: rowBg,
                    child: Row(children: [
                      Expanded(flex: 1, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('${i + 1}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)))),
                      Expanded(flex: 3, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)))),
                      Expanded(flex: 2, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text(item['Mobile'] ?? '', style: const TextStyle(fontSize: 13)))),
                      Expanded(flex: 3, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text(time, style: const TextStyle(fontSize: 12, color: Colors.black54)))),
                      Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _iconActionBtn(Icons.edit, mdaPrimaryBlue, () => _showAddSchedulerDialog(itemToEdit: item)),
                        const SizedBox(width: 2),
                        _iconActionBtn(Icons.delete, Colors.red, () => _deleteItem(item['sno'].toString())),
                      ])),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  Widget _buildGenericList({bool showMergeButton = false}) {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13);
    const headerColor = Color(0xFFF1F3F4);
    const borderColor = Color(0xFFDEE2E6);

    // Derive column label from tab title (e.g. "Products" → "Product Name")
    final tabTitle = _tabs[_selectedTabIndex]['title'] as String;
    final colLabel = tabTitle.endsWith('s') ? '${tabTitle.substring(0, tabTitle.length - 1)} Name' : '$tabTitle Name';

    return Column(children: [
      if (showMergeButton) ...[
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _showMergeProductDialog,
            icon: const Icon(Icons.merge_type, size: 18),
            label: const Text('Merge Products'),
            style: OutlinedButton.styleFrom(foregroundColor: mdaPrimaryBlue, side: const BorderSide(color: mdaPrimaryBlue)),
          ),
        ),
        const SizedBox(height: 12),
      ],
      // Header row
      Container(
        color: headerColor,
        child: Row(children: [
          _th('Sno.', flex: 1, align: TextAlign.center, style: headerStyle),
          _th(colLabel, flex: 5, style: headerStyle),
          _th('Action', flex: 2, align: TextAlign.center, style: headerStyle),
        ]),
      ),
      const Divider(height: 1, color: borderColor),
      Expanded(
        child: _items.isEmpty
            ? const Center(child: Text('No items found.'))
            : ListView.separated(
                itemCount: _items.length,
                separatorBuilder: (_, r) => const Divider(height: 1, color: borderColor),
                itemBuilder: (ctx, i) {
                  final item = _items[i];
                  final rowBg = i.isEven ? Colors.white : const Color(0xFFEBEBEB);
                  return Container(
                    color: rowBg,
                    child: Row(children: [
                      Expanded(flex: 1, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('${i + 1}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)))),
                      Expanded(flex: 5, child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), child: Text(item['name'], style: const TextStyle(fontSize: 13)))),
                      Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _iconActionBtn(Icons.edit, mdaPrimaryBlue, () => _showGenericAddDialog(tabTitle, itemToEdit: item)),
                        const SizedBox(width: 2),
                        _iconActionBtn(Icons.delete, Colors.red, () => _deleteItem(item['sno'].toString())),
                      ])),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }


  Widget _buildThemeSettings() {
    return SingleChildScrollView(
      child: ValueListenableBuilder<ThemeState>(
        valueListenable: themeNotifier,
        builder: (context, themeState, _) {
          final cs = Theme.of(context).colorScheme;
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(side: BorderSide(color: cs.outline.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme Customization', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: mdaPrimaryBlue)),
                  const Divider(height: 30),
                  const Text('Appearance Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      themeNotifier.updateTheme(isDarkMode: !themeState.isDarkMode);
                    },
                    icon: Icon(themeState.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                    label: Text(themeState.isDarkMode ? 'Toggle Light Mode' : 'Toggle Dark Mode'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 0),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Sidebar Color', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildColorSwatch(mdaPrimaryBlue, isActive: themeState.sidebarColor == mdaPrimaryBlue, onTap: () => themeNotifier.updateTheme(sidebarColor: mdaPrimaryBlue)),
                      _buildColorSwatch(Colors.green, isActive: themeState.sidebarColor == Colors.green, onTap: () => themeNotifier.updateTheme(sidebarColor: Colors.green)),
                      _buildColorSwatch(Colors.red, isActive: themeState.sidebarColor == Colors.red, onTap: () => themeNotifier.updateTheme(sidebarColor: Colors.red)),
                      _buildColorSwatch(Colors.black87, isActive: themeState.sidebarColor == Colors.black87, onTap: () => themeNotifier.updateTheme(sidebarColor: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Top Bar Color', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildColorSwatch(Colors.white, isActive: themeState.topBarColor == Colors.white, isBordered: true, onTap: () => themeNotifier.updateTheme(topBarColor: Colors.white)),
                      _buildColorSwatch(Colors.lightBlue, isActive: themeState.topBarColor == Colors.lightBlue, onTap: () => themeNotifier.updateTheme(topBarColor: Colors.lightBlue)),
                      _buildColorSwatch(Colors.amber, isActive: themeState.topBarColor == Colors.amber, onTap: () => themeNotifier.updateTheme(topBarColor: Colors.amber)),
                      _buildColorSwatch(Colors.black87, isActive: themeState.topBarColor == Colors.black87, onTap: () => themeNotifier.updateTheme(topBarColor: Colors.black87)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildColorSwatch(Color color, {bool isActive = false, bool isBordered = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? Colors.black : (isBordered ? Colors.grey.shade300 : Colors.transparent),
            width: isActive ? 2 : 1,
          ),
        ),
        child: isActive ? Icon(Icons.check, color: color == Colors.white ? Colors.black : Colors.white) : null,
      ),
    );
  }

  void _showMergeProductDialog() async {
    if (_items.isEmpty) return;
    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      builder: (_) => _MergeProductDialog(products: List.from(_items)),
    );
    if (shouldRefresh == true && mounted) _fetchData(_selectedTabIndex);
  }

  void _showAddStatusDialog({Map<String, dynamic>? itemToEdit}) async {
    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      builder: (_) => _AddStatusDialog(itemToEdit: itemToEdit),
    );
    if (shouldRefresh == true && mounted) {
      _fetchData(_selectedTabIndex);
    }
  }

  void _showAddSchedulerDialog({Map<String, dynamic>? itemToEdit}) async {
    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      builder: (_) => _AddSchedulerDialog(itemToEdit: itemToEdit),
    );
    if (shouldRefresh == true && mounted) {
      _fetchData(_selectedTabIndex);
    }
  }

  void _showGenericAddDialog(String itemType, {Map<String, dynamic>? itemToEdit}) async {
    final type1 = _tabs[_selectedTabIndex]['type1'] as String;
    final bool? shouldRefresh = await showDialog<bool>(
      context: context,
      builder: (_) => _AddGenericDialog(itemType: itemType, type1: type1, itemToEdit: itemToEdit),
    );
    if (shouldRefresh == true && mounted) {
      _fetchData(_selectedTabIndex);
    }
  }
}

class _AddGenericDialog extends StatefulWidget {
  final String itemType;
  final String type1;
  final Map<String, dynamic>? itemToEdit;
  const _AddGenericDialog({required this.itemType, required this.type1, this.itemToEdit});

  @override
  State<_AddGenericDialog> createState() => _AddGenericDialogState();
}

class _AddGenericDialogState extends State<_AddGenericDialog> {
  final _nameCtrl = TextEditingController();
  bool _isSaving = false;
  String? _errMsg;

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      _nameCtrl.text = widget.itemToEdit!['name'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errMsg = 'Name is required.');
      return;
    }
    setState(() { _isSaving = true; _errMsg = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final db = prefs.getString('D_Database') ?? 'mdapulse';
      final sno = widget.itemToEdit != null ? widget.itemToEdit!['sno'] : 0;
      
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Setting.aspx/save_Product'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': clientId, 'Name': name, 'DB': db, 'sno': sno, 'type1': widget.type1}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result.trim() == '1') {
          Navigator.of(context).pop(true);
        } else if (result.trim() == '2') {
          setState(() { _isSaving = false; _errMsg = 'Already exists.'; });
        } else {
          setState(() { _isSaving = false; _errMsg = 'Failed to save.'; });
        }
      } else {
        setState(() { _isSaving = false; _errMsg = 'Server error.'; });
      }
    } catch (_) {
      if (mounted) setState(() { _isSaving = false; _errMsg = 'Network error.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final singularName = widget.itemType.endsWith('ies')
        ? widget.itemType.replaceFirst('ies', 'y')
        : (widget.itemType.endsWith('s') ? widget.itemType.substring(0, widget.itemType.length - 1) : widget.itemType);
        
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: mdaPrimaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.itemToEdit == null ? "Add" : "Edit"} $singularName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 20)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$singularName Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    errorText: _errMsg,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.3)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isSaving) const Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddStatusDialog extends StatefulWidget {
  final Map<String, dynamic>? itemToEdit;
  const _AddStatusDialog({this.itemToEdit});

  @override
  State<_AddStatusDialog> createState() => _AddStatusDialogState();
}

class _AddStatusDialogState extends State<_AddStatusDialog> {
  final _nameCtrl = TextEditingController();
  String _type = 'Pending';
  String _colorName = 'Blue';
  bool _isSaving = false;
  String? _errMsg;

  final Map<String, String> _colorsMap = {
    'Blue': '#0257E6',
    'Yellow': '#FFC107',
    'Green': '#4CAF50',
    'Red': '#F44336',
    'Grey': '#9E9E9E',
  };

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      _nameCtrl.text = widget.itemToEdit!['name'] ?? '';
      _type = (widget.itemToEdit!['type'] ?? 'Pending');
      if (_type != 'Pending' && _type != 'Close') _type = 'Pending';
      final color = widget.itemToEdit!['color'] as Color?;
      if (color != null) {
        String hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
        _colorName = _colorsMap.entries.firstWhere((e) => e.value == hex, orElse: () => const MapEntry('Grey', '#9E9E9E')).key;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errMsg = 'Status Name is required.');
      return;
    }
    setState(() { _isSaving = true; _errMsg = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final db = prefs.getString('D_Database') ?? 'mdapulse';
      final sno = widget.itemToEdit != null ? widget.itemToEdit!['sno'] : 0;
      
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Setting.aspx/save_status'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': clientId, 'ProsCust': '0', 'Status': name, 'Type': _type, 
          'SaleRej': '', 'sn': sno, 'StatusClolor': _colorName,
          'DB': db, 'status_cat': ''
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result.startsWith('1#')) {
          Navigator.of(context).pop(true);
        } else if (result.startsWith('2#')) {
          setState(() { _isSaving = false; _errMsg = 'Already exists.'; });
        } else {
          setState(() { _isSaving = false; _errMsg = 'Failed to save.'; });
        }
      } else {
        setState(() { _isSaving = false; _errMsg = 'Server error.'; });
      }
    } catch (_) {
      if (mounted) setState(() { _isSaving = false; _errMsg = 'Network error.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: mdaPrimaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.itemToEdit == null ? "Add" : "Edit"} Status', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 20)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errMsg != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_errMsg!, style: const TextStyle(color: Colors.red))),
                const Text('Status Name', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Close / Pending', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: cs.outline.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _type,
                      items: ['Pending', 'Close'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Colour', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: cs.outline.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _colorName,
                      items: _colorsMap.keys.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setState(() => _colorName = v!),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.3)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isSaving) const Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddSchedulerDialog extends StatefulWidget {
  final Map<String, dynamic>? itemToEdit;
  const _AddSchedulerDialog({this.itemToEdit});

  @override
  State<_AddSchedulerDialog> createState() => _AddSchedulerDialogState();
}

class _AddSchedulerDialogState extends State<_AddSchedulerDialog> {
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errMsg;

  List<Map<String, String>> _employees = [];
  String? _selectedEmployeeMobile;
  final _mobileCtrl = TextEditingController(); // fallback if not in dropdown
  final _startTimeCtrl = TextEditingController(text: '09:00');
  final _endTimeCtrl = TextEditingController(text: '18:00');
  final _freqCtrl = TextEditingController(text: '60');
  String _functionType = '1';

  final Map<String, String> _functionTypes = {
    '1': 'Overall Summary',
    '2': 'Employee wise summary',
  };

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final db = prefs.getString('D_Database') ?? 'mdapulse';
      
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Setting.aspx/Fill_DropDown'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': clientId, 'chk': 'Emp', 'sno': 1, 'DB': db}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['d']?.toString() ?? '';
        if (data.isNotEmpty && data.contains('~')) {
          final List<Map<String, String>> items = [];
          final rows = data.split('#').where((r) => r.isNotEmpty).toList();
          for (var r in rows) {
            final arr = r.split('~');
            if (arr.isNotEmpty) {
              items.add({'val': arr[0], 'text': arr.length > 1 ? arr[1] : arr[0]});
            }
          }
          if (mounted) {
            setState(() {
              _employees = items;
            });
          }
        }
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _initForm();
        });
      }
    }
  }

  void _initForm() {
    if (widget.itemToEdit != null) {
      final item = widget.itemToEdit!;
      _functionType = item['Function_type']?.toString() ?? '1';
      if (!_functionTypes.containsKey(_functionType)) _functionType = '1';
      
      final mob = item['Mobile']?.toString() ?? '';
      _mobileCtrl.text = mob;
      if (_employees.any((e) => e['val'] == mob)) {
        _selectedEmployeeMobile = mob;
      }
      
      _startTimeCtrl.text = item['Start_time']?.toString() ?? '09:00';
      _endTimeCtrl.text = item['End_time']?.toString() ?? '18:00';
      _freqCtrl.text = item['Frequency']?.toString() ?? '60';
    } else if (_employees.isNotEmpty) {
      _selectedEmployeeMobile = _employees.first['val'];
      _mobileCtrl.text = _selectedEmployeeMobile ?? '';
    }
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _freqCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final mobile = _selectedEmployeeMobile ?? _mobileCtrl.text.trim();
    if (mobile.isEmpty) {
      setState(() => _errMsg = 'Mobile is required.');
      return;
    }
    setState(() { _isSaving = true; _errMsg = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final db = prefs.getString('D_Database') ?? 'mdapulse';
      final sid = widget.itemToEdit != null ? widget.itemToEdit!['sno'] : 0;
      final oldMobile = widget.itemToEdit != null ? widget.itemToEdit!['Mobile'] : '';
      
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Setting.aspx/save_Scheduler'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': clientId, 
          'FunctionType': _functionType, 
          'Mobile': mobile, 
          'StartTime': _startTimeCtrl.text.trim(), 
          'EndTime': _endTimeCtrl.text.trim(), 
          'frequency': _freqCtrl.text.trim(), 
          'SID': int.tryParse(sid.toString()) ?? 0, 
          'DB': db, 
          'OldMobileNo': oldMobile,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result == '1') {
          Navigator.of(context).pop(true);
        } else if (result == '2') {
          setState(() { _isSaving = false; _errMsg = 'Duplicate scheduler exists.'; });
        } else if (result == '3') {
          setState(() { _isSaving = false; _errMsg = 'Employee with this mobile not found.'; });
        } else {
          setState(() { _isSaving = false; _errMsg = 'Failed to save.'; });
        }
      } else {
        setState(() { _isSaving = false; _errMsg = 'Server error.'; });
      }
    } catch (_) {
      if (mounted) setState(() { _isSaving = false; _errMsg = 'Network error.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: mdaPrimaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.itemToEdit == null ? "Add" : "Edit"} Scheduler', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 20)),
              ],
            ),
          ),
          if (_isLoading)
             const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errMsg != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_errMsg!, style: const TextStyle(color: Colors.red))),
                    const Text('Function Type', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: cs.outline.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _functionType,
                          items: _functionTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                          onChanged: (v) => setState(() => _functionType = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Employee Mobile', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_employees.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(border: Border.all(color: cs.outline.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedEmployeeMobile,
                            hint: const Text('Select Employee'),
                            items: _employees.map((e) => DropdownMenuItem(value: e['val'], child: Text('${e['text']} (${e['val']})'))).toList(),
                            onChanged: (v) => setState(() {
                              _selectedEmployeeMobile = v;
                              _mobileCtrl.text = v ?? '';
                            }),
                          ),
                        ),
                      )
                    else
                      TextField(
                        controller: _mobileCtrl,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: 'Enter Mobile Number',
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _startTimeCtrl,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  hintText: 'HH:mm',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End Time', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _endTimeCtrl,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  hintText: 'HH:mm',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Frequency (Minutes)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _freqCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.3)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isSaving) const Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Merge Product Dialog ---

class _MergeProductDialog extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  const _MergeProductDialog({required this.products});

  @override
  State<_MergeProductDialog> createState() => _MergeProductDialogState();
}

class _MergeProductDialogState extends State<_MergeProductDialog> {
  final Set<String> _selectedSnos = {};
  String? _mergeIntoSno;
  bool _isSaving = false;
  String? _errMsg;

  Future<void> _save() async {
    if (_selectedSnos.isEmpty) {
      setState(() => _errMsg = 'Select at least one product to merge.');
      return;
    }
    if (_mergeIntoSno == null) {
      setState(() => _errMsg = 'Select a Merge Into product.');
      return;
    }
    final fromItems = widget.products
        .where((p) => _selectedSnos.contains(p['sno'].toString()) && p['sno'].toString() != _mergeIntoSno)
        .toList();
    if (fromItems.isEmpty) {
      setState(() => _errMsg = 'The selected products cannot be the same as the Merge Into product.');
      return;
    }
    final selectedValues = fromItems.map((p) => p['name'] + r'$' + p['sno'].toString()).join(',');
    final mergeInto = widget.products.firstWhere((p) => p['sno'].toString() == _mergeIntoSno, orElse: () => {});
    if (mergeInto.isEmpty) return;
    final mergeIntoValue = mergeInto['name'] + r'$' + mergeInto['sno'].toString();

    setState(() { _isSaving = true; _errMsg = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final db = prefs.getString('D_Database') ?? 'mdapulse';
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Setting.aspx/Merge_Product'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': clientId, 'DB': db, 'selectedValues': selectedValues, 'MerggeInProduct': mergeIntoValue}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result == '1') {
          Navigator.of(context).pop(true);
        } else {
          setState(() { _isSaving = false; _errMsg = 'Merge failed. Please try again.'; });
        }
      } else {
        setState(() { _isSaving = false; _errMsg = 'Server error.'; });
      }
    } catch (_) {
      if (mounted) setState(() { _isSaving = false; _errMsg = 'Network error.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            color: mdaPrimaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Merge Products', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 20)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_errMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade200)),
                    child: Text(_errMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                const Text('Select products to merge (FROM):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: cs.outline.withValues(alpha: 0.4)), borderRadius: BorderRadius.circular(8)),
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.products.length,
                    itemBuilder: (_, i) {
                      final p = widget.products[i];
                      final sno = p['sno'].toString();
                      return CheckboxListTile(
                        dense: true,
                        value: _selectedSnos.contains(sno),
                        title: Text(p['name'], style: const TextStyle(fontSize: 13)),
                        onChanged: (v) => setState(() { if (v == true) { _selectedSnos.add(sno); } else { _selectedSnos.remove(sno); } }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Merge INTO product:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border.all(color: cs.outline.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _mergeIntoSno,
                      hint: const Text('Select target product', style: TextStyle(fontSize: 13)),
                      items: widget.products.map((p) => DropdownMenuItem(value: p['sno'].toString(), child: Text(p['name'], style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _mergeIntoSno = v),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.3)))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (_isSaving) const Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              TextButton(onPressed: _isSaving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white),
                child: const Text('Merge'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
