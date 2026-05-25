// File: lib/features/client_management/presentation/widgets/edit_customer_dialog.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class EditCustomerDialog extends StatefulWidget {
  final String customerSno;

  const EditCustomerDialog({super.key, required this.customerSno});

  @override
  State<EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<EditCustomerDialog> {
  int _currentStep = 1;
  bool _isLoadingData = true;
  bool _isSaving = false;
  String? _errorMessage;

  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _altNoController = TextEditingController();
  final TextEditingController _altNameController = TextEditingController();
  final TextEditingController _add1Controller = TextEditingController();
  final TextEditingController _add2Controller = TextEditingController();
  final TextEditingController _add3Controller = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  String? _selectedCategory;
  String? _selectedGrouping;
  String? _selectedSource;

  final TextEditingController _cityController = TextEditingController();
  List<Map<String, String>> _cityItems = [];
  List<Map<String, String>> _stateItems = [];
  String? _selectedState;
  String _db = 'mdapulse';

  String _prosCust = '0';
  final TextEditingController _customerIdController = TextEditingController();
  String _dateAdded = '';

  String? _selectedReference;
  String? _selectedReferEmployee;
  final TextEditingController _referByController = TextEditingController();
  List<Map<String, String>> _employeeItems = [];

  List<Map<String, String>> _categoryItems = [];
  List<Map<String, String>> _groupingItems = [];
  List<Map<String, String>> _sourceItems = [];
  bool _isLoadingDropdowns = false;
  bool _showArchitect = false;
  String _archName = 'Grouping Name';

  @override
  void initState() {
    super.initState();
    _fetchCustomerDetails();
    _fetchCityList();
    _fetchDropdowns();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _contactPersonController.dispose();
    _orgNameController.dispose();
    _emailController.dispose();
    _remarkController.dispose();
    _altNoController.dispose();
    _altNameController.dispose();
    _add1Controller.dispose();
    _add2Controller.dispose();
    _add3Controller.dispose();
    _pinController.dispose();
    _cityController.dispose();
    _referByController.dispose();
    _customerIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchCustomerDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/CustomerListBySno'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "sno": int.parse(widget.customerSno), "DB": db}),
      );

      if (response.statusCode == 200) {
        final String raw = jsonDecode(response.body)['d'] ?? '';
        final parts = raw.split('^');
        if (parts.length >= 23) {
          setState(() {
            _orgNameController.text = parts[1];
            _contactPersonController.text = parts[2];
            _emailController.text = parts[3];
            _mobileController.text = parts[4];
            _altNoController.text = parts[5];
            _add1Controller.text = parts[6];
            _add2Controller.text = parts[7];
            _add3Controller.text = parts[8];
            _pinController.text = parts[9] == '0' ? '' : parts[9];
            _cityController.text = (parts[10].isNotEmpty && parts[10] != '0') ? parts[10] : '';
            _selectedState = (parts[11].isNotEmpty && parts[11] != '0') ? parts[11] : null;
            _selectedCategory = parts[12].isNotEmpty ? parts[12] : null;
            _remarkController.text = parts[13];
            _dateAdded = parts[14];
            _prosCust = parts[15].toLowerCase() == 'true' ? '1' : '0';
            _customerIdController.text = (parts[16].isEmpty || parts[16] == '0') ? '' : parts[16];
            _altNameController.text = parts[18];
            _selectedGrouping = parts[19].isNotEmpty && parts[19] != '0' ? parts[19] : null;
            _selectedSource = parts[20].isNotEmpty ? parts[20] : null;
            final String ref = parts[21];
            final String referBy = parts[22].replaceAll('#', '');
            _selectedReference = ref.isNotEmpty ? ref : null;
            if (ref.toLowerCase() == 'employee') {
              _selectedReferEmployee = referBy.isNotEmpty ? referBy : null;
            } else {
              _referByController.text = referBy;
            }
            _isLoadingData = false;
          });
        } else {
          setState(() { _errorMessage = "Invalid data format received."; _isLoadingData = false; });
        }
      } else {
        setState(() { _errorMessage = "Server error ${response.statusCode}"; _isLoadingData = false; });
      }
    } catch (e) {
      setState(() { _errorMessage = "Network error while loading data."; _isLoadingData = false; });
    }
  }

  Future<void> _updateCustomer() async {
    final String emailVal = _emailController.text.trim();
    if (emailVal.isNotEmpty &&
        !RegExp(r'^[\w.%+\-]+@[\w.\-]+\.[a-zA-Z]{2,}$').hasMatch(emailVal)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }
    setState(() { _isSaving = true; _errorMessage = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      final String ucode = prefs.getString('UCode') ?? '1';
      final bool autoAllot = (prefs.getString('AutoAllot') ?? 'true').toLowerCase() == 'true';

      final String reference = _isReferenceSource() ? (_selectedReference ?? '') : '';
      final String referBy = _isReferenceSource()
          ? (_isEmployeeReference() ? (_selectedReferEmployee ?? '') : _referByController.text.trim())
          : '';
      final String rdata = "${_orgNameController.text.trim()}^${_contactPersonController.text.trim()}^${_emailController.text.trim()}^${_selectedCategory ?? ''}^${_remarkController.text.trim()}^${_altNoController.text.trim()}^${_add1Controller.text.trim()}^${_add2Controller.text.trim()}^${_add3Controller.text.trim()}^${_pinController.text.trim()}^${_cityController.text.trim()}^${_selectedState ?? ''}^${_mobileController.text.trim()}^$_prosCust^${_customerIdController.text.trim()}^$_dateAdded^${_altNameController.text.trim()}^${_selectedGrouping ?? '0'}^${_selectedSource ?? ''}^$reference^$referBy";

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/SaveCustomer'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "sno": widget.customerSno, "rdata": rdata, "ucode": ucode, "hid": int.parse(widget.customerSno), "AutoAllot": autoAllot, "DB": db}),
      );

      if (response.statusCode == 200) {
        final String result = jsonDecode(response.body)['d'] ?? '';
        if (result.startsWith('1#') || result.startsWith('2#')) {
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          setState(() => _errorMessage = "Failed to update: $result");
        }
      } else {
        setState(() => _errorMessage = "Server error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _errorMessage = "Network error. Check connection.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _isReferenceSource() =>
      _selectedSource != null && _selectedSource!.toLowerCase().contains('reference');

  bool _isEmployeeReference() => _selectedReference?.toLowerCase() == 'employee';

  Future<void> _fetchCityList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/fillCategory'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "Type1": "City", "DB": db}),
      );
      if (response.statusCode == 200) {
        final String data = jsonDecode(response.body)['d']?.toString() ?? '';
        if (data.isNotEmpty && !data.startsWith('Something')) {
          final items = data.split('#').where((row) => row.contains('^')).map((row) {
            final parts = row.split('^');
            return {'id': parts[0], 'label': parts.length > 1 ? parts[1] : parts[0]};
          }).toList();
          if (mounted) setState(() { _cityItems = items; _db = db; });
        }
      }
    } catch (_) {}
  }

  Future<void> _showAddProductDialog(String type1, String displayName) async {
    final String? savedName = await showDialog<String>(
      context: context,
      builder: (_) => _AddProductDialog(type1: type1, displayName: displayName),
    );
    if (savedName == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
    final String db = prefs.getString('D_Database') ?? 'mdapulse';
    if (type1 == 'CAT') {
      final newItems = await _fetchCategory(clientId, db);
      final match = newItems.firstWhere(
        (item) => item['label']?.toLowerCase() == savedName.toLowerCase(),
        orElse: () => <String, String>{},
      );
      if (mounted) setState(() { _categoryItems = newItems; if (match.isNotEmpty) _selectedCategory = match['label']; });
    } else {
      final newItems = await _fetchFillDropdown(clientId, 'Sorc', db);
      final match = newItems.firstWhere(
        (item) => item['label']?.toLowerCase() == savedName.toLowerCase(),
        orElse: () => <String, String>{},
      );
      if (mounted) setState(() { _sourceItems = newItems; if (match.isNotEmpty) _selectedSource = match['label']; });
    }
  }

  Future<void> _showAddCityDialog() async {
    final String? savedName = await showDialog<String>(
      context: context,
      builder: (_) => const _AddProductDialog(type1: 'City', displayName: 'City'),
    );
    if (savedName == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
    final String db = prefs.getString('D_Database') ?? 'mdapulse';
    final newItems = await _fetchCategoryType(clientId, 'City', db);
    final match = newItems.firstWhere(
      (item) => item['label']?.toLowerCase() == savedName.toLowerCase(),
      orElse: () => <String, String>{},
    );
    if (mounted) {
      setState(() {
        _cityItems = newItems;
        if (match.isNotEmpty) _cityController.text = match['label']!;
      });
      if (match.isNotEmpty) {
        final cityId = int.tryParse(match['id'] ?? '0') ?? 0;
        if (cityId > 0) _prefillState(cityId);
      }
    }
  }

  Future<void> _showAddGroupingDialog() async {
    final String? savedName = await showDialog<String>(
      context: context,
      builder: (_) => _AddGroupingDialog(archName: _archName, cityItems: _cityItems),
    );
    if (savedName == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
    final String db = prefs.getString('D_Database') ?? 'mdapulse';
    final newItems = await _fetchFillDropdown(clientId, 'ARCH', db);
    final match = newItems.firstWhere(
      (item) => item['label']?.toLowerCase() == savedName.toLowerCase(),
      orElse: () => <String, String>{},
    );
    if (mounted) setState(() { _groupingItems = newItems; if (match.isNotEmpty) _selectedGrouping = match['id']; });
  }

  Future<void> _fetchDropdowns() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      _showArchitect = (prefs.getString('Architect') ?? '').toLowerCase() == 'true';
      _archName = prefs.getString('Arch_Name') ?? 'Grouping Name';

      final results = await Future.wait([
        _fetchCategory(clientId, db),
        _fetchFillDropdown(clientId, 'ARCH', db),
        _fetchFillDropdown(clientId, 'Sorc', db),
        _fetchCategoryType(clientId, 'State', db),
        _fetchFillDropdown(clientId, 'EMP1', db),
      ]);

      if (mounted) {
        setState(() {
          _categoryItems = results[0];
          _groupingItems = results[1];
          _sourceItems = results[2];
          _stateItems = results[3];
          _employeeItems = results[4];
          _isLoadingDropdowns = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDropdowns = false);
    }
  }

  Future<List<Map<String, String>>> _fetchCategory(String clientId, String db) async {
    try {
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/fillCategory'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "Type1": "CAT", "DB": db}),
      );
      if (response.statusCode == 200) {
        final String data = jsonDecode(response.body)['d']?.toString() ?? '';
        if (data.isEmpty || data.startsWith('Something')) return [];
        return data.split('#').where((row) => row.contains('^')).map((row) {
          final parts = row.split('^');
          return {'id': parts[0], 'label': parts.length > 1 ? parts[1] : parts[0]};
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, String>>> _fetchCategoryType(String clientId, String type1, String db) async {
    try {
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/fillCategory'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "Type1": type1, "DB": db}),
      );
      if (response.statusCode == 200) {
        final String data = jsonDecode(response.body)['d']?.toString() ?? '';
        if (data.isEmpty || data.startsWith('Something')) return [];
        return data.split('#').where((row) => row.contains('^')).map((row) {
          final parts = row.split('^');
          return {'id': parts[0], 'label': parts.length > 1 ? parts[1] : parts[0]};
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, String>>> _fetchFillDropdown(String clientId, String chk, String db) async {
    try {
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/Fill_DropDown'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "chk": chk, "sno": 0, "DB": db}),
      );
      if (response.statusCode == 200) {
        final String data = jsonDecode(response.body)['d']?.toString() ?? '';
        if (data.isEmpty || !data.contains('~')) return [];
        return data.split('#').where((row) => row.contains('~')).map((row) {
          final parts = row.split('~');
          return {'id': parts[0], 'label': parts.length > 1 ? parts[1] : parts[0]};
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _prefillState(int cityId) async {
    try {
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/fillState'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"CityID": cityId, "DB": _db}),
      );
      if (response.statusCode == 200) {
        final String raw = jsonDecode(response.body)['d']?.toString() ?? '';
        final String data = raw.replaceAll('#', '').trim();
        String stateName = '';
        if (data.contains('^')) {
          stateName = data.split('^')[1].trim();
        } else if (data.isNotEmpty) {
          stateName = data;
        }
        if (stateName.isNotEmpty && mounted) {
          final match = _stateItems.firstWhere(
            (s) => s['label']!.toLowerCase() == stateName.toLowerCase(),
            orElse: () => <String, String>{},
          );
          setState(() => _selectedState = match.isNotEmpty ? match['label'] : stateName);
        }
      }
    } catch (_) {}
  }

  void _showCitySearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CitySearchSheet(
        cityItems: _cityItems,
        onSelected: (city) {
          setState(() => _cityController.text = city['label']!);
          final cityId = int.tryParse(city['id'] ?? '0') ?? 0;
          if (cityId > 0) _prefillState(cityId);
        },
      ),
    );
  }

  Widget _buildCityPickerField(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('City', style: TextStyle(fontSize: 14, color: cs.onSurface, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showAddCityDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                child: const Text('Add New', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showCitySearch,
          child: AbsorbPointer(
            child: TextField(
              controller: _cityController,
              decoration: InputDecoration(
                hintText: 'Select city',
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                suffixIcon: Icon(Icons.search, color: cs.onSurfaceVariant, size: 18),
                filled: true,
                fillColor: cs.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: mdaPrimaryBlue, width: 2)),
              ),
            ),
          ),
        ),
      ],
    );
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
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: mdaPrimaryBlue,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 20)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepCircle(cs, 1),
                  _buildStepLine(cs),
                  _buildStepCircle(cs, 2),
                  _buildStepLine(cs),
                  _buildStepCircle(cs, 3),
                ],
              ),
            ),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                color: Colors.red.shade50,
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
            Expanded(
              child: _isLoadingData
                  ? const Center(child: CircularProgressIndicator(color: mdaPrimaryBlue))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Builder(builder: (context) {
                        final cs = Theme.of(context).colorScheme;
                        if (_currentStep == 1) return _buildStep1(cs);
                        if (_currentStep == 2) return _buildStep2(cs);
                        return _buildStep3(cs);
                      }),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(ColorScheme cs) {
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildTextField(cs, 'Mobile Number', _mobileController, isNumber: true, isCenter: true),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => setState(() => _currentStep = 2),
          style: ElevatedButton.styleFrom(
            backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(width: 8),
              Icon(Icons.arrow_right_alt, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(cs, 'Contact Person *', _contactPersonController),
        const SizedBox(height: 16),
        _buildTextField(cs, 'Organisation Name', _orgNameController),
        const SizedBox(height: 16),
        _buildTextField(cs, 'Email', _emailController),
        const SizedBox(height: 16),
        _buildTextField(cs, 'Remark', _remarkController),
        const SizedBox(height: 16),
        _buildTextField(cs, 'Alternate No.', _altNoController, isNumber: true),
        const SizedBox(height: 16),
        _buildTextField(cs, 'Alternate Name', _altNameController),
        const SizedBox(height: 16),
        _buildDropdownField(cs, 'Category', _categoryItems, _selectedCategory, showAddNew: true, onAddNewTap: () => _showAddProductDialog('CAT', 'Category'), onChanged: (v) => setState(() => _selectedCategory = v)),
        const SizedBox(height: 16),
        if (_showArchitect) ...[
          _buildDropdownField(cs, _archName, _groupingItems, _selectedGrouping, valueKey: 'id', showAddNew: true, onAddNewTap: _showAddGroupingDialog, onChanged: (v) => setState(() => _selectedGrouping = v)),
          const SizedBox(height: 16),
        ],
        _buildDropdownField(cs, 'Source', _sourceItems, _selectedSource, showAddNew: true, onAddNewTap: () => _showAddProductDialog('SRC', 'Source'), onChanged: (v) => setState(() {
          _selectedSource = v;
          if (!_isReferenceSource()) {
            _selectedReference = null;
            _selectedReferEmployee = null;
            _referByController.clear();
          }
        })),
        if (_isReferenceSource()) ...[
          const SizedBox(height: 16),
          _buildDropdownField(
            cs,
            'Reference',
            const [
              {'id': 'Customer', 'label': 'Customer'},
              {'id': 'Employee', 'label': 'Employee'},
              {'id': 'Other', 'label': 'Other'},
            ],
            _selectedReference,
            onChanged: (v) => setState(() {
              _selectedReference = v;
              _selectedReferEmployee = null;
              _referByController.clear();
            }),
          ),
          if (_selectedReference != null) ...[
            const SizedBox(height: 16),
            if (_isEmployeeReference())
              _buildDropdownField(cs, 'Refer By', _employeeItems, _selectedReferEmployee, onChanged: (v) => setState(() => _selectedReferEmployee = v))
            else
              _buildTextField(cs, 'Refer By', _referByController),
          ],
        ],
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNavButton('Back', Icons.arrow_left, () => setState(() => _currentStep = 1), isBack: true),
            const SizedBox(width: 16),
            _buildNavButton('Next', Icons.arrow_right_alt, () => setState(() => _currentStep = 3)),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStep3(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTextField(cs, 'Address Line 1', _add1Controller),
        const SizedBox(height: 16),
        _buildTextField(cs, 'Address Line 2', _add2Controller),
        const SizedBox(height: 16),
        _buildTextField(cs, 'Address Line 3', _add3Controller),
        const SizedBox(height: 16),
        _buildTextField(cs, 'Pin code', _pinController, isNumber: true),
        const SizedBox(height: 16),
        _buildCityPickerField(cs),
        const SizedBox(height: 16),
        _buildDropdownField(cs, 'State', _stateItems, _selectedState, onChanged: (v) => setState(() => _selectedState = v)),
        if (_prosCust == '1') ...[
          const SizedBox(height: 16),
          _buildTextField(cs, 'Customer ID', _customerIdController, isNumber: true),
        ],
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNavButton('Back', Icons.arrow_left, () => setState(() => _currentStep = 2), isBack: true),
            const SizedBox(width: 16),
            _isSaving
                ? const CircularProgressIndicator(color: mdaPrimaryBlue)
                : ElevatedButton(
                    onPressed: _updateCustomer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStepCircle(ColorScheme cs, int step) {
    bool isActive = _currentStep == step;
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? mdaPrimaryBlue : cs.surfaceContainerHighest,
        boxShadow: isActive ? [BoxShadow(color: mdaPrimaryBlue.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)] : null,
      ),
      alignment: Alignment.center,
      child: Text(step.toString(), style: TextStyle(color: isActive ? Colors.white : cs.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildStepLine(ColorScheme cs) {
    return Container(
      width: 60, height: 2,
      color: cs.outline.withValues(alpha: 0.4),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildNavButton(String text, IconData icon, VoidCallback onPressed, {bool isBack = false}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBack) ...[Icon(icon, size: 20), const SizedBox(width: 6)],
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (!isBack) ...[const SizedBox(width: 6), Icon(icon, size: 20)],
        ],
      ),
    );
  }

  Widget _buildTextField(ColorScheme cs, String label, TextEditingController controller, {bool isNumber = false, bool isCenter = false}) {
    return Column(
      crossAxisAlignment: isCenter ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLength: isNumber ? 10 : null,
          textAlign: isCenter ? TextAlign.center : TextAlign.start,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: cs.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: mdaPrimaryBlue, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(ColorScheme cs, String label, List<Map<String, String>> items, String? currentValue, {String valueKey = 'label', bool showAddNew = false, VoidCallback? onAddNewTap, required Function(String?) onChanged}) {
    final menuItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('Select')),
      ...items.map((item) => DropdownMenuItem(value: item[valueKey], child: Text(item['label'] ?? ''))),
    ];
    final effectiveValue = (currentValue?.isNotEmpty ?? false) ? currentValue! : '';
    final validValue = menuItems.any((m) => m.value == effectiveValue) ? effectiveValue : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: cs.onSurface, fontWeight: FontWeight.bold)),
            if (showAddNew) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAddNewTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                  child: const Text('Add New', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: _isLoadingDropdowns
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 11),
                  child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: mdaPrimaryBlue)),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: validValue,
                    items: menuItems,
                    onChanged: onChanged,
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Private helper dialogs — proper StatefulWidgets avoid StatefulBuilder's
// closure-recreation bug during exit animation that triggers _dependents.isEmpty
// ---------------------------------------------------------------------------

class _AddProductDialog extends StatefulWidget {
  final String type1;
  final String displayName;
  const _AddProductDialog({required this.type1, required this.displayName});

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final _nameCtrl = TextEditingController();
  String? _errMsg;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errMsg = '${widget.displayName} name is required.');
      return;
    }
    setState(() { _isSaving = true; _errMsg = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final db = prefs.getString('D_Database') ?? 'mdapulse';
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Setting.aspx/save_Product'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': clientId, 'Name': name, 'DB': db, 'sno': 0, 'type1': widget.type1}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result.trim() == '1') {
          Navigator.of(context).pop(name);
        } else if (result.trim() == '2') {
          setState(() { _isSaving = false; _errMsg = '${widget.displayName} already exists.'; });
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
      title: Text('Add New ${widget.displayName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_errMsg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_errMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '${widget.displayName} Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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

class _AddGroupingDialog extends StatefulWidget {
  final String archName;
  final List<Map<String, String>> cityItems;
  const _AddGroupingDialog({required this.archName, required this.cityItems});

  @override
  State<_AddGroupingDialog> createState() => _AddGroupingDialogState();
}

class _AddGroupingDialogState extends State<_AddGroupingDialog> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  String? _errMsg;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  void _openCitySearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CitySearchSheet(
        cityItems: widget.cityItems,
        onSelected: (city) => setState(() => _cityCtrl.text = city['label']!),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errMsg = '${widget.archName} name is required.');
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
        body: jsonEncode({'ClientId': clientId, 'Rdata': '$name^$city^$mobile', 'DB': db, 'SnoARch': 0}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result.trim() == '1') {
          Navigator.of(context).pop(name);
        } else if (result.trim() == '2') {
          setState(() { _isSaving = false; _errMsg = '${widget.archName} already exists.'; });
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
      title: Text('Add New ${widget.archName}'),
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
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '${widget.archName} Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _openCitySearch,
              child: AbsorbPointer(
                child: TextField(
                  controller: _cityCtrl,
                  decoration: InputDecoration(
                    labelText: 'City',
                    suffixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mobileCtrl,
              keyboardType: TextInputType.number,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
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
      height: MediaQuery.of(context).size.height * 0.75,
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
