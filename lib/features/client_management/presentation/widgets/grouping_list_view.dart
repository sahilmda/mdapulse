// File: lib/features/client_management/presentation/widgets/grouping_list_view.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mda_crm/features/client_management/data/models/group_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class GroupingListView extends StatefulWidget {
  final List<CustomerGroup> groups;
  final String searchQuery;
  final VoidCallback onRefresh;

  const GroupingListView({
    super.key,
    required this.groups,
    required this.searchQuery,
    required this.onRefresh,
  });

  @override
  State<GroupingListView> createState() => _GroupingListViewState();
}

class _GroupingListViewState extends State<GroupingListView> {
  int _currentPage = 1;
  final int _entriesPerPage = 10;

  @override
  void didUpdateWidget(GroupingListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groups != widget.groups || oldWidget.searchQuery != widget.searchQuery) {
      _currentPage = 1;
    }
  }

  List<CustomerGroup> get _filtered {
    if (widget.searchQuery.isEmpty) return widget.groups;
    final q = widget.searchQuery.toLowerCase();
    return widget.groups.where((g) =>
      g.groupName.toLowerCase().contains(q) ||
      g.city.toLowerCase().contains(q) ||
      g.mobileNumber.contains(q),
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final total = filtered.length;

    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(child: Text('No groups found.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      );
    }

    final int startIndex = (_currentPage - 1) * _entriesPerPage;
    final int endIndex = (startIndex + _entriesPerPage).clamp(0, total);
    final displayed = filtered.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayed.length,
          itemBuilder: (context, index) => GroupCard(
            group: displayed[index],
            onRefresh: widget.onRefresh,
          ),
        ),
        _buildPaginationFooter(context, total, startIndex, endIndex),
      ],
    );
  }

  Widget _buildPaginationFooter(BuildContext context, int total, int startIndex, int endIndex) {
    final cs = Theme.of(context).colorScheme;
    final int totalPages = (total / _entriesPerPage).ceil();
    final int startEntry = total == 0 ? 0 : startIndex + 1;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            'Showing $startEntry to $endIndex of $total entries',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  minimumSize: const Size(0, 36),
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
                onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  minimumSize: const Size(0, 36),
                  side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GroupCard extends StatefulWidget {
  final CustomerGroup group;
  final VoidCallback onRefresh;

  const GroupCard({super.key, required this.group, required this.onRefresh});

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool _isExpanded = false;

  Future<void> _deleteGrouping() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final db = prefs.getString('D_Database') ?? 'mdapulse';
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/DeleteArch'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': clientId,
          'SnoARch': int.tryParse(widget.group.snoArch) ?? 0,
          'DB': db,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result.trim() == '1') {
          widget.onRefresh();
        } else {
          _showError('Failed to delete. Please try again.');
        }
      } else {
        _showError('Server error. Please try again.');
      }
    } catch (_) {
      if (mounted) _showError('Network error. Check your connection.');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool hasMembers = widget.group.members.isNotEmpty;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: hasMembers ? () => setState(() => _isExpanded = !_isExpanded) : null,
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 12.0, bottom: 12.0, right: 4.0),
              child: Row(
                children: [
                  Icon(
                    hasMembers ? (_isExpanded ? Icons.arrow_drop_down : Icons.play_arrow) : Icons.play_arrow_outlined,
                    color: hasMembers ? (_isExpanded ? Colors.red : cs.onSurfaceVariant) : cs.outline,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.groupName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: mdaPrimaryBlue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_city, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.group.city.isNotEmpty ? widget.group.city : '—',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.group.mobileNumber.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(widget.group.mobileNumber, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface, fontSize: 13)),
                    ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final result = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => GroupingDialog(
                            snoArch: widget.group.snoArch,
                            initialName: widget.group.groupName,
                            initialCity: widget.group.city,
                            initialMobile: widget.group.mobileNumber,
                          ),
                        );
                        if (result == true) widget.onRefresh();
                      } else if (value == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Grouping'),
                            content: Text('Are you sure you want to delete "${widget.group.groupName}"? All customers linked to this group will be unlinked.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) await _deleteGrouping();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(leading: Icon(Icons.edit, color: mdaPrimaryBlue), title: Text('Edit'), contentPadding: EdgeInsets.zero),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded && hasMembers)
            Container(
              color: cs.surfaceContainerHighest,
              padding: const EdgeInsets.only(left: 48.0, right: 16.0, top: 12.0, bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.group.members.map((member) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              member.orgName.isNotEmpty ? member.orgName : member.contactPerson,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (member.status.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: member.status == 'Complete' || member.status == 'Work Done' ? Colors.green[100] : Colors.amber[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                member.status,
                                style: TextStyle(
                                  color: member.status == 'Complete' || member.status == 'Work Done' ? Colors.green[800] : Colors.black87,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (member.contactPerson.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                member.contactPerson,
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (member.phone.isNotEmpty || member.email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (member.phone.isNotEmpty) ...[
                              Icon(Icons.phone, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(member.phone, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                              const SizedBox(width: 12),
                            ],
                            if (member.email.isNotEmpty) ...[
                              Icon(Icons.email, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  member.email,
                                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (member.lastContact.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(member.lastContact, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                          ],
                        ),
                      ],
                    ],
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add / Edit Grouping dialog
// ---------------------------------------------------------------------------

class GroupingDialog extends StatefulWidget {
  final String? snoArch;       // null = add, non-null = edit
  final String initialName;
  final String initialCity;
  final String initialMobile;

  const GroupingDialog({
    super.key,
    this.snoArch,
    this.initialName = '',
    this.initialCity = '',
    this.initialMobile = '',
  });

  @override
  State<GroupingDialog> createState() => _GroupingDialogState();
}

class _GroupingDialogState extends State<GroupingDialog> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  List<Map<String, String>> _cityItems = [];
  String? _errMsg;
  bool _isSaving = false;
  bool _isLoadingCities = true;

  bool get _isEdit => widget.snoArch != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName;
    _cityCtrl.text = widget.initialCity;
    _mobileCtrl.text = widget.initialMobile;
    _loadCities();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final db = prefs.getString('D_Database') ?? 'mdapulse';
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/fillCategory'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': clientId, 'Type1': 'City', 'DB': db}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['d']?.toString() ?? '';
        if (data.isNotEmpty && !data.startsWith('Something')) {
          final items = data.split('#').where((r) => r.contains('^')).map((r) {
            final parts = r.split('^');
            return {'id': parts[0], 'label': parts.length > 1 ? parts[1] : parts[0]};
          }).toList();
          if (mounted) setState(() { _cityItems = items; _isLoadingCities = false; });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingCities = false);
  }

  void _openCitySearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CitySearchSheet(
        cityItems: _cityItems,
        onSelected: (city) => setState(() => _cityCtrl.text = city['label']!),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errMsg = 'Name is required.');
      return;
    }
    final mobile = _mobileCtrl.text.trim();
    if (mobile.isNotEmpty && mobile.length != 10) {
      setState(() => _errMsg = 'Please enter a valid 10-digit mobile number.');
      return;
    }
    setState(() { _isSaving = true; _errMsg = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final db = prefs.getString('D_Database') ?? 'mdapulse';
      final city = _cityCtrl.text.trim();
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/SaveArch'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': clientId,
          'Rdata': '$name^$city^$mobile',
          'DB': db,
          'SnoARch': int.tryParse(widget.snoArch ?? '0') ?? 0,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result.trim() == '1') {
          Navigator.of(context).pop(true);
        } else if (result.trim() == '2') {
          setState(() { _isSaving = false; _errMsg = 'This name already exists.'; });
        } else {
          setState(() { _isSaving = false; _errMsg = 'Failed to save. Please try again.'; });
        }
      } else {
        setState(() { _isSaving = false; _errMsg = 'Server error. Please try again.'; });
      }
    } catch (_) {
      if (mounted) setState(() { _isSaving = false; _errMsg = 'Network error. Check your connection.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Grouping' : 'Add Grouping'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errMsg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_errMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            const Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            const Text('City', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            _isLoadingCities
                ? const SizedBox(height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: mdaPrimaryBlue)))
                : GestureDetector(
                    onTap: _openCitySearch,
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _cityCtrl,
                        decoration: InputDecoration(
                          hintText: 'Select city',
                          suffixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            const Text('Mobile No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _mobileCtrl,
              keyboardType: TextInputType.number,
              maxLength: 10,
              decoration: InputDecoration(
                hintText: 'Enter mobile number',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// City search bottom sheet — proper StatefulWidget avoids StatefulBuilder's
// setState-after-dispose crash triggered by IME events during sheet animation
// ---------------------------------------------------------------------------

class _CitySearchSheet extends StatefulWidget {
  final List<Map<String, String>> cityItems;
  final ValueChanged<Map<String, String>> onSelected;

  const _CitySearchSheet({required this.cityItems, required this.onSelected});

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final _searchCtrl = TextEditingController();
  late List<Map<String, String>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.cityItems);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: cs.outline.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search city...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (q) => setState(() {
                _filtered = widget.cityItems
                    .where((c) => c['label']!.toLowerCase().contains(q.toLowerCase()))
                    .toList();
              }),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(_filtered[i]['label']!),
                onTap: () {
                  Navigator.pop(context);
                  widget.onSelected(_filtered[i]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
