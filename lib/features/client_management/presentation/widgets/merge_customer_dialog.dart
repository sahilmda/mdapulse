// File: lib/features/client_management/presentation/widgets/merge_customer_dialog.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mda_crm/shared/utils/app_dialogs.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class MergeCustomerDialog extends StatefulWidget {
  const MergeCustomerDialog({super.key});

  @override
  State<MergeCustomerDialog> createState() => _MergeCustomerDialogState();
}

class _MergeCustomerDialogState extends State<MergeCustomerDialog> {
  int _currentStep = 1;
  bool _isLoading = true;
  bool _isFetchingDetails = false;
  bool _isMerging = false;

  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _displayedCustomers = [];

  String _searchQuery = '';
  int _currentPage = 1;
  final int _entriesPerPage = 10;
  int _totalEntries = 0;

  final Set<String> _selectedToMerge = {};
  String? _primarySno;

  Map<String, dynamic> _primaryCustomerData = {};
  final List<Map<String, dynamic>> _secondaryCustomersData = [];

  final TextEditingController _finalContactPersonCtrl = TextEditingController();
  final TextEditingController _finalPhoneCtrl = TextEditingController();
  final TextEditingController _finalAltNameCtrl = TextEditingController();
  final TextEditingController _finalAltNoCtrl = TextEditingController();
  final TextEditingController _finalOrgNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomersForMerge();
  }

  @override
  void dispose() {
    _finalContactPersonCtrl.dispose();
    _finalPhoneCtrl.dispose();
    _finalAltNameCtrl.dispose();
    _finalAltNoCtrl.dispose();
    _finalOrgNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomersForMerge() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      final int grade = int.tryParse(prefs.getString('Grade') ?? '0') ?? 0;
      final String sno7 = prefs.getString('sno') ?? '0';
      final int showAllC = int.tryParse(prefs.getString('showAllCustomer') ?? '0') ?? 0;

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/fillCustomerList'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "chk": "P1", "DB": db, "Grade": grade, "sno_7": sno7, "showAllC": showAllC}),
      );

      if (response.statusCode == 200) {
        final String rawData = jsonDecode(response.body)['d'] ?? '';
        List<Map<String, dynamic>> parsedList = [];
        if (rawData.isNotEmpty) {
          for (String row in rawData.split('#')) {
            if (row.trim().isEmpty) continue;
            final cols = row.split('^');
            if (cols.length >= 7) {
              parsedList.add({
                'sno': cols[0].trim(),
                'orgName': cols[1].trim(),
                'contactPerson': cols[2].trim(),
                'phone': cols[3].trim(),
              });
            }
          }
        }
        parsedList.sort((a, b) => (a['orgName'] ?? '').toString().toLowerCase().compareTo((b['orgName'] ?? '').toString().toLowerCase()));
        setState(() { _allCustomers = parsedList; _isLoading = false; });
        _applyFiltersAndPagination();
      }
    } catch (e) {
      debugPrint("Error fetching customers for merge: $e");
      setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndPagination() {
    List<Map<String, dynamic>> filtered = _allCustomers;
    if (_searchQuery.isNotEmpty) {
      final search = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        return (c['orgName'] ?? '').toString().toLowerCase().contains(search) ||
               (c['contactPerson'] ?? '').toString().toLowerCase().contains(search) ||
               (c['phone'] ?? '').toString().toLowerCase().contains(search);
      }).toList();
    }
    _totalEntries = filtered.length;
    int startIndex = (_currentPage - 1) * _entriesPerPage;
    int endIndex = startIndex + _entriesPerPage;
    if (startIndex >= filtered.length) { startIndex = 0; _currentPage = 1; endIndex = _entriesPerPage; }
    if (endIndex > filtered.length) endIndex = filtered.length;
    setState(() => _displayedCustomers = filtered.sublist(startIndex, endIndex));
  }

  Future<void> _prepareStep2() async {
    if (_selectedToMerge.length < 2) {
      showAppDialog(context, type: DialogType.warning, title: 'Selection Required', message: 'Please select at least 2 customers to merge.');
      return;
    }
    if (_primarySno == null) {
      showAppDialog(context, type: DialogType.warning, title: 'Primary Required', message: 'Please select a Primary customer before proceeding.');
      return;
    }
    setState(() => _isFetchingDetails = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';

      // Build a lookup of step-1 data (orgName, contactPerson, phone already fetched)
      final Map<String, Map<String, dynamic>> listDataBySno = {
        for (final c in _allCustomers) c['sno'].toString(): c,
      };

      Map<String, dynamic> mergeWithListData(Map<String, dynamic> detail, String sno) {
        final listData = listDataBySno[sno.trim()] ?? {};
        // Prefer API value; fall back to list-row value when API returns empty
        if ((detail['orgName'] as String).isEmpty) detail['orgName'] = (listData['orgName'] ?? '').toString();
        if ((detail['contactPerson'] as String).isEmpty) detail['contactPerson'] = (listData['contactPerson'] ?? '').toString();
        if ((detail['phone'] as String).isEmpty) detail['phone'] = (listData['phone'] ?? '').toString();
        return detail;
      }

      _primaryCustomerData = mergeWithListData(
        await _fetchCustomerDetail(_primarySno!, clientId, db), _primarySno!);

      _secondaryCustomersData.clear();
      for (final sno in _selectedToMerge) {
        if (sno != _primarySno) {
          _secondaryCustomersData.add(mergeWithListData(
            await _fetchCustomerDetail(sno, clientId, db), sno));
        }
      }

      _finalOrgNameCtrl.text = _primaryCustomerData['orgName'] ?? '';
      _finalContactPersonCtrl.text = _primaryCustomerData['contactPerson'] ?? '';
      _finalPhoneCtrl.text = _primaryCustomerData['phone'] ?? '';
      String altName = _primaryCustomerData['altName'] ?? '';
      String altNo = _primaryCustomerData['altNo'] ?? '';
      if (altName.isEmpty && _secondaryCustomersData.isNotEmpty) altName = _secondaryCustomersData[0]['contactPerson'] ?? '';
      if (altNo.isEmpty && _secondaryCustomersData.isNotEmpty) altNo = _secondaryCustomersData[0]['phone'] ?? '';
      _finalAltNameCtrl.text = altName;
      _finalAltNoCtrl.text = altNo;

      setState(() { _currentStep = 2; _isFetchingDetails = false; });
    } catch (e) {
      setState(() => _isFetchingDetails = false);
      if (mounted) showAppDialog(context, type: DialogType.error, title: 'Load Failed', message: 'Failed to load customer details. Please try again.');
    }
  }

  Future<Map<String, dynamic>> _fetchCustomerDetail(String sno, String clientId, String db) async {
    final int? snoInt = int.tryParse(sno.trim());
    if (snoInt == null) return {'sno': sno, 'orgName': '', 'contactPerson': '', 'phone': '', 'altNo': '', 'altName': ''};

    final response = await http.post(
      Uri.parse('https://webservices.mdapulse.com/Customer.aspx/CustomerListBySno'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({"ClientID": clientId, "sno": snoInt, "DB": db}),
    );
    if (response.statusCode == 200) {
      // Response: sno^OrgName^CPerson^eMail^Mobile^AltNo^Addr1^...^AlternateName^...#
      final raw = jsonDecode(response.body)['d']?.toString() ?? '';
      final parts = raw.split('#').first.split('^');
      if (parts.length >= 19) {
        return {
          'sno': sno,
          'orgName': parts[1].trim(),
          'contactPerson': parts[2].trim(),
          'phone': parts[4].trim(),
          'altNo': parts[5].trim(),
          'altName': parts[18].trim(),
        };
      }
    }
    return {'sno': sno, 'orgName': '', 'contactPerson': '', 'phone': '', 'altNo': '', 'altName': ''};
  }

  Future<void> _confirmFinalMerge() async {
    setState(() => _isMerging = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final db = prefs.getString('D_Database') ?? 'mdapulse';

      final int primaryId = int.tryParse(_primarySno ?? '0') ?? 0;
      final String mergCustIDs = _selectedToMerge.join('^');
      final String custData =
          '${_finalContactPersonCtrl.text.trim()}^'
          '${_finalPhoneCtrl.text.trim()}^'
          '${_finalAltNameCtrl.text.trim()}^'
          '${_finalAltNoCtrl.text.trim()}';

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/Save_Merge_customer'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': clientId,
          'DB': db,
          'PrimaryId': primaryId,
          'MergCustIDs': mergCustIDs,
          'CustData': custData,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result.trim() == '1') {
          Navigator.pop(context, true);
        } else {
          showAppDialog(context, type: DialogType.error, title: 'Merge Failed', message: 'Failed to merge customers. Please try again.');
          setState(() => _isMerging = false);
        }
      } else {
        showAppDialog(context, type: DialogType.error, title: 'Server Error', message: 'Server error (${response.statusCode}). Please try again.');
        setState(() => _isMerging = false);
      }
    } catch (_) {
      if (mounted) {
        showAppDialog(context, type: DialogType.error, title: 'Network Error', message: 'Could not connect to server. Check your connection.');
        setState(() => _isMerging = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Merge Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 20)),
                ],
              ),
            ),
            Expanded(child: _currentStep == 1 ? _buildStep1Table(cs) : _buildStep2Confirmation(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Table(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              const Text('Search: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
                    ),
                    onChanged: (val) { _searchQuery = val; _currentPage = 1; _applyFiltersAndPagination(); },
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: mdaPrimaryBlue))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(cs.surfaceContainerHighest),
                      columnSpacing: 24,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 48,
                      columns: const [
                        DataColumn(label: Text('Merge', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Organisation Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Contact Person', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Primary', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _displayedCustomers.map((cust) {
                        final sno = cust['sno'].toString();
                        final bool isMerged = _selectedToMerge.contains(sno);
                        return DataRow(
                          cells: [
                            DataCell(Checkbox(
                              value: isMerged,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) { _selectedToMerge.add(sno); }
                                  else { _selectedToMerge.remove(sno); if (_primarySno == sno) _primarySno = null; }
                                });
                              },
                            )),
                            DataCell(Text(cust['phone'].toString().isNotEmpty ? cust['phone'] : '--')),
                            DataCell(Text(cust['orgName'].toString())),
                            DataCell(Text(cust['contactPerson'].toString())),
                            DataCell(Radio<String>(
                              value: sno,
                              groupValue: _primarySno,
                              onChanged: isMerged ? (val) => setState(() => _primarySno = val) : null,
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.3)))),
          child: Column(
            children: [
              Text(
                _totalEntries == 0
                    ? 'No entries found'
                    : 'Showing ${(_currentPage - 1) * _entriesPerPage + 1} to ${_currentPage * _entriesPerPage > _totalEntries ? _totalEntries : _currentPage * _entriesPerPage} of $_totalEntries entries',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: _currentPage > 1 ? () { setState(() => _currentPage--); _applyFiltersAndPagination(); } : null,
                        child: const Text('Previous'),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: mdaPrimaryBlue, borderRadius: BorderRadius.circular(4)),
                        child: Text('$_currentPage', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(
                        onPressed: _currentPage < (_totalEntries / _entriesPerPage).ceil() ? () { setState(() => _currentPage++); _applyFiltersAndPagination(); } : null,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                  _isFetchingDetails
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: mdaPrimaryBlue, strokeWidth: 2))
                      : ElevatedButton(
                          onPressed: _prepareStep2,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mdaPrimaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Next', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Confirmation(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCustomerReviewCard(cs, title: 'Primary Customer', titleColor: mdaPrimaryBlue, borderColor: mdaPrimaryBlue, data: _primaryCustomerData),
                const SizedBox(height: 16),
                const Text('Secondary Customers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                ..._secondaryCustomersData.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: _buildCustomerReviewCard(cs, title: 'Customer ${entry.key + 1}', titleColor: cs.onSurface, borderColor: cs.outline.withValues(alpha: 0.5), data: entry.value),
                  );
                }),
                _buildFinalCustomerDetailCard(cs),
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
              ElevatedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              _isMerging
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF198754), strokeWidth: 2))
                  : ElevatedButton(
                      onPressed: _confirmFinalMerge,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF198754), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                      child: const Text('Confirm Merge', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerReviewCard(ColorScheme cs, {required String title, required Color titleColor, required Color borderColor, required Map<String, dynamic> data}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surface, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildReadOnlyField(cs, 'Organisation Name', data['orgName']),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildReadOnlyField(cs, 'Contact Person', data['contactPerson'])),
              const SizedBox(width: 16),
              Expanded(child: _buildReadOnlyField(cs, 'Contact No.', data['phone'])),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildReadOnlyField(cs, 'Alternate Name', data['altName'])),
              const SizedBox(width: 16),
              Expanded(child: _buildReadOnlyField(cs, 'Alternate mobile no.', data['altNo'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField(ColorScheme cs, String label, String? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
          ),
          child: Text(value?.isNotEmpty == true ? value! : ' ', style: TextStyle(color: cs.onSurface)),
        ),
      ],
    );
  }

  Widget _buildFinalCustomerDetailCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: const Color(0xFF198754)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Final Customer Detail', style: TextStyle(color: mdaPrimaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildEditableField(cs, 'Organisation Name', _finalOrgNameCtrl),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildEditableField(cs, 'Contact Person', _finalContactPersonCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildEditableField(cs, 'Contact No.', _finalPhoneCtrl)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildEditableField(cs, 'Alternate Name', _finalAltNameCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildEditableField(cs, 'Alternate mobile no.', _finalAltNoCtrl)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(ColorScheme cs, String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              filled: true,
              fillColor: cs.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: mdaPrimaryBlue, width: 2)),
            ),
          ),
        ),
      ],
    );
  }
}
