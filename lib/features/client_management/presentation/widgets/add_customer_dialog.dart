// File: lib/features/client_management/presentation/widgets/add_customer_dialog.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class AddCustomerDialog extends StatefulWidget {
  final bool isOldCustomer;
  const AddCustomerDialog({super.key, this.isOldCustomer = false});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  int _currentStep = 1;
  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _altNoController = TextEditingController();
  final TextEditingController _altNameController = TextEditingController();

  String? _selectedCategory;
  String? _selectedGrouping;
  String? _selectedSource;
  String? _selectedReference;
  String? _selectedReferEmployee;

  List<Map<String, String>> _categoryItems = [];
  List<Map<String, String>> _groupingItems = [];
  List<Map<String, String>> _sourceItems = [];
  List<Map<String, String>> _cityItems = [];
  List<Map<String, String>> _stateItems = [];
  List<Map<String, String>> _employeeItems = [];
  String? _selectedState;
  bool _isLoadingDropdowns = false;
  bool _showArchitect = false;
  String _archName = 'Architect';
  String _db = 'mdapulse';

  final TextEditingController _customerIdController = TextEditingController();
  final TextEditingController _referByController = TextEditingController();

  bool _isReferenceSource() =>
      _selectedSource != null && _selectedSource!.toLowerCase().contains('reference');

  bool _isEmployeeReference() => _selectedReference?.toLowerCase() == 'employee';

  final TextEditingController _add1Controller = TextEditingController();
  final TextEditingController _add2Controller = TextEditingController();
  final TextEditingController _add3Controller = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    _customerIdController.dispose();
    _referByController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdowns() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      final String baseCity = prefs.getString('BaseCity') ?? '';
      _showArchitect = (prefs.getString('Architect') ?? '').toLowerCase() == 'true';
      _archName = prefs.getString('Arch_Name') ?? 'Architect';

      final results = await Future.wait([
        _fetchCategory(clientId, db),
        _fetchFillDropdown(clientId, 'ARCH', db),
        _fetchFillDropdown(clientId, 'Sorc', db),
        _fetchCategoryType(clientId, 'City', db),
        _fetchFillDropdown(clientId, 'EMP1', db),
        _fetchCategoryType(clientId, 'State', db),
      ]);

      final List<Map<String, String>> cityList = results[3];

      if (mounted) {
        setState(() {
          _db = db;
          _categoryItems = results[0];
          _groupingItems = results[1];
          _sourceItems = results[2];
          _cityItems = cityList;
          _employeeItems = results[4];
          _stateItems = results[5];
          _isLoadingDropdowns = false;
        });
      }

      if (baseCity.isNotEmpty && mounted) {
        String cityName = '';
        int cityId = 0;

        if (baseCity.contains('~')) {
          final parts = baseCity.split('~');
          final String part0 = parts[0].trim();
          final String part1 = parts.length > 1 ? parts[1].trim() : '';
          final int? parsed0 = int.tryParse(part0);
          final int? parsed1 = int.tryParse(part1);
          if (parsed0 != null) {
            cityId = parsed0;
            cityName = part1;
          } else if (parsed1 != null) {
            cityId = parsed1;
            cityName = part0;
          } else {
            cityName = part0;
          }
        } else {
          cityName = baseCity.trim();
        }

        if (cityId == 0 && cityName.isNotEmpty) {
          final match = cityList.firstWhere(
            (c) => c['label']!.toLowerCase() == cityName.toLowerCase(),
            orElse: () => <String, String>{},
          );
          if (match.isNotEmpty) {
            cityId = int.tryParse(match['id'] ?? '0') ?? 0;
          }
        }

        if (cityName.isNotEmpty && mounted) {
          setState(() => _cityController.text = cityName);
        }
        if (cityId > 0) {
          await _prefillState(cityId, db);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDropdowns = false);
    }
  }

  Future<void> _prefillState(int cityId, String db) async {
    try {
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/fillState'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"CityID": cityId, "DB": db}),
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

  Future<List<Map<String, String>>> _fetchCategoryType(String clientId, String type, String db) async {
    try {
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/fillCategory'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "Type1": type, "DB": db}),
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

  Future<void> _verifyMobileAndProceed() async {
    final mobile = _mobileController.text.trim();
    setState(() => _errorMessage = null);

    if (mobile.isEmpty) {
      FocusScope.of(context).unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Phone No. not filled'),
          content: const Text(
            'Phone No. not filled. Do you really want to leave the phone number blank for this customer?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: mdaPrimaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (confirmed == true && mounted) {
        FocusScope.of(context).unfocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) setState(() => _currentStep = 2);
      }
      return;
    }

    if (mobile.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/chkEmployeeRegister'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"mob": mobile, "ClientID": clientId, "DB": db, "sno_11": 0}),
      );

      if (response.statusCode == 200) {
        final String result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result.contains('^')) {
          final String existingName = result.split('^')[1].trim();
          if (mounted) {
            setState(() => _isLoading = false);
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Duplicate Mobile Number'),
                content: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    children: [
                      const TextSpan(text: 'This mobile number is already added with Customer Name '),
                      TextSpan(
                        text: existingName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const TextSpan(text: '!'),
                    ],
                  ),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mdaPrimaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }
    } catch (_) {
      // If check fails, allow proceeding
    }

    if (mounted) setState(() { _isLoading = false; _currentStep = 2; });
  }

  bool _isSaving = false;

  Future<void> _saveCustomer() async {
    if (_contactPersonController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Contact Person is required.');
      return;
    }
    if (_cityController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'City is required.');
      return;
    }
    if (_selectedState == null || _selectedState!.isEmpty) {
      setState(() => _errorMessage = 'State is required.');
      return;
    }
    final String emailVal = _emailController.text.trim();
    if (emailVal.isNotEmpty &&
        !RegExp(r'^[\w.%+\-]+@[\w.\-]+\.[a-zA-Z]{2,}$').hasMatch(emailVal)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }
    final String altNoVal = _altNoController.text.trim();
    if (altNoVal.isNotEmpty && altNoVal.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit alternate number.');
      return;
    }
    if (altNoVal.isNotEmpty && _altNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Alternate Name is required when Alternate No. is entered.');
      return;
    }

    setState(() { _isSaving = true; _errorMessage = null; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      final String sno = prefs.getString('sno') ?? '1';
      final String ucode = prefs.getString('UCode') ?? '1';
      final String autoAllotStr = prefs.getString('AutoAllot') ?? 'true';
      final bool autoAllot = autoAllotStr.toLowerCase() == 'true' || autoAllotStr == '1';

      final String custName = _contactPersonController.text.trim();
      final String orgName = _orgNameController.text.trim().isEmpty ? custName : _orgNameController.text.trim();
      final String email = _emailController.text.trim();
      final String category = (_selectedCategory?.isNotEmpty ?? false) ? _selectedCategory! : '';
      final String remark = _remarkController.text.trim();
      final String altNo = _altNoController.text.trim();
      final String add1 = _add1Controller.text.trim();
      final String add2 = _add2Controller.text.trim();
      final String add3 = _add3Controller.text.trim();
      final String pin = _pinController.text.trim();
      final String city = _cityController.text.trim();
      final String state = _selectedState ?? '';
      final String mobile = _mobileController.text.trim();
      final String custType = widget.isOldCustomer ? '1' : '0';
      final String custId = _customerIdController.text.trim();
      const String custDateTxt = '';
      final String altName = _altNameController.text.trim();
      final String archSNo = (_selectedGrouping?.isNotEmpty ?? false) ? _selectedGrouping! : '0';
      final String source = (_selectedSource?.isNotEmpty ?? false) ? _selectedSource! : '';
      final String reference = _isReferenceSource() ? (_selectedReference ?? '') : '';
      final String referBy = _isReferenceSource()
          ? (_isEmployeeReference()
              ? (_selectedReferEmployee ?? '')
              : _referByController.text.trim())
          : '';

      final String rdata = "$orgName^$custName^$email^$category^$remark^$altNo^$add1^$add2^$add3^$pin^$city^$state^$mobile^$custType^$custId^$custDateTxt^$altName^$archSNo^$source^$reference^$referBy";
      debugPrint('rdata: $rdata');
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/SaveCustomer'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "sno": sno, "rdata": rdata, "ucode": ucode, "hid": 0, "AutoAllot": autoAllot, "DB": db}),
      );

      if (response.statusCode == 200) {
        final String result = jsonDecode(response.body)['d'] ?? '';
        if (result.startsWith('1#') || result.startsWith('2#')) {
          if (!mounted) return;
          Navigator.pop(context, true);
        } else if (result.startsWith('3#')) {
          setState(() => _errorMessage = "This customer already exists.");
        } else {
          setState(() => _errorMessage = "Failed to add customer. Server returned: $result");
        }
      } else {
        setState(() => _errorMessage = "Server error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      setState(() => _errorMessage = "Network error while saving. Check your connection.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final double dialogHeight = _currentStep == 1 ? 350 : MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: dialogHeight,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: mdaPrimaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.isOldCustomer ? 'Add Old Customer' : 'Add New Customer', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 20)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: _buildCustomStepper(cs),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0).copyWith(bottom: 12),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey(_currentStep),
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildStepContent(cs),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomStepper(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(cs, 1),
        _buildStepLine(cs),
        _buildStepCircle(cs, 2),
        _buildStepLine(cs),
        _buildStepCircle(cs, 3),
      ],
    );
  }

  Widget _buildStepCircle(ColorScheme cs, int stepNumber) {
    bool isActive = _currentStep == stepNumber;
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: isActive ? mdaPrimaryBlue : cs.surfaceContainerHighest,
        shape: BoxShape.circle,
        boxShadow: isActive ? [BoxShadow(color: mdaPrimaryBlue.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)] : null,
      ),
      child: Center(
        child: Text(
          '$stepNumber',
          style: TextStyle(color: isActive ? Colors.white : cs.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  Widget _buildStepLine(ColorScheme cs) {
    return Container(
      width: 40,
      height: 2,
      color: cs.outline.withValues(alpha: 0.4),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildStepContent(ColorScheme cs) {
    if (_currentStep == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildTextField(cs, 'Mobile Number', _mobileController, isNumber: true),
          const SizedBox(height: 32),
          _isLoading
              ? const CircularProgressIndicator(color: mdaPrimaryBlue)
              : ElevatedButton(
                  onPressed: _verifyMobileAndProceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mdaPrimaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
        ],
      );
    } else if (_currentStep == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(cs, 'Contact Person *', _contactPersonController, inputType: TextInputType.text),
          const SizedBox(height: 16),
          _buildTextField(cs, 'Organisation Name', _orgNameController, inputType: TextInputType.text),
          const SizedBox(height: 16),
          _buildTextField(cs, 'Email', _emailController, inputType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField(cs, 'Remark', _remarkController, inputType: TextInputType.text),
          const SizedBox(height: 16),
          _buildTextField(cs, 'Alternate No.', _altNoController, isNumber: true),
          const SizedBox(height: 16),
          _buildTextField(cs, 'Alternate Name', _altNameController, inputType: TextInputType.name),
          const SizedBox(height: 16),
          _buildApiDropdownField(cs, 'Category', _categoryItems, _selectedCategory, (val) => setState(() => _selectedCategory = val), showAddNew: true, onAddNewTap: () => _showAddProductDialog('CAT', 'Category')),
          const SizedBox(height: 16),
          if (_showArchitect) ...[
            _buildApiDropdownField(cs, _archName, _groupingItems, _selectedGrouping, (val) => setState(() => _selectedGrouping = val), valueKey: 'id', showAddNew: true, onAddNewTap: _showAddGroupingDialog),
            const SizedBox(height: 16),
          ],
          _buildApiDropdownField(cs, 'Source', _sourceItems, _selectedSource, (val) {
            setState(() {
              _selectedSource = val;
              if (!_isReferenceSource()) {
                _selectedReference = null;
                _selectedReferEmployee = null;
                _referByController.clear();
              }
            });
          }, showAddNew: true, onAddNewTap: () => _showAddProductDialog('SRC', 'Source')),
          if (_isReferenceSource()) ...[
            const SizedBox(height: 16),
            _buildApiDropdownField(
              cs,
              'Reference',
              const [
                {'id': 'Customer', 'label': 'Customer'},
                {'id': 'Employee', 'label': 'Employee'},
                {'id': 'Other', 'label': 'Other'},
              ],
              _selectedReference,
              (val) => setState(() {
                _selectedReference = val;
                _selectedReferEmployee = null;
                _referByController.clear();
              }),
            ),
            if (_selectedReference != null) ...[
              const SizedBox(height: 16),
              if (_isEmployeeReference())
                _buildApiDropdownField(cs, 'Refer By', _employeeItems,
                    _selectedReferEmployee,
                    (val) => setState(() => _selectedReferEmployee = val))
              else
                _buildTextField(cs, 'Refer By', _referByController,
                    inputType: TextInputType.text),
            ],
          ],
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(children: [Icon(Icons.arrow_back, size: 20), SizedBox(width: 8), Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  if (_contactPersonController.text.trim().isEmpty) {
                    setState(() => _errorMessage = 'Contact Person is required.');
                    return;
                  }
                  final String emailVal = _emailController.text.trim();
                  if (emailVal.isNotEmpty &&
                      !RegExp(r'^[\w.%+\-]+@[\w.\-]+\.[a-zA-Z]{2,}$').hasMatch(emailVal)) {
                    setState(() => _errorMessage = 'Please enter a valid email address.');
                    return;
                  }
                  final String altNo = _altNoController.text.trim();
                  if (altNo.isNotEmpty && altNo.length != 10) {
                    setState(() => _errorMessage = 'Please enter a valid 10-digit alternate number.');
                    return;
                  }
                  if (altNo.isNotEmpty && _altNameController.text.trim().isEmpty) {
                    setState(() => _errorMessage = 'Alternate Name is required when Alternate No. is entered.');
                    return;
                  }
                  setState(() { _errorMessage = null; _currentStep = 3; });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(children: [Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(width: 8), Icon(Icons.arrow_forward, size: 20)]),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField(cs, 'Address Line 1', _add1Controller),
          const SizedBox(height: 16),
          _buildTextField(cs, 'Address Line 2', _add2Controller),
          const SizedBox(height: 16),
          _buildTextField(cs, 'Address Line 3', _add3Controller),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField(cs, 'Pin Code', _pinController, isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildCityPickerField(cs)),
            ],
          ),
          const SizedBox(height: 16),
          _buildApiDropdownField(cs, 'State *', _stateItems, _selectedState, (val) => setState(() => _selectedState = val)),
          if (widget.isOldCustomer) ...[
            const SizedBox(height: 16),
            _buildTextField(cs, 'Customer ID', _customerIdController, isNumber: true),
          ],
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isSaving ? null : () => setState(() => _currentStep = 2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(children: [Icon(Icons.arrow_back, size: 20), SizedBox(width: 8), Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
              ),
              const SizedBox(width: 16),
              _isSaving
                  ? const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: Colors.green))
                  : ElevatedButton(
                      onPressed: _saveCustomer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const Text('Save Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      );
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
        if (cityId > 0) _prefillState(cityId, db);
      }
    }
  }

  Widget _buildCityPickerField(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('City *', style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface, fontSize: 13)),
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
                suffixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: mdaPrimaryBlue, width: 2)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showCitySearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CitySearchSheet(
        cityItems: _cityItems,
        sheetHeight: 0.75,
        onSelected: (city) {
          setState(() => _cityController.text = city['label']!);
          final cityId = int.tryParse(city['id'] ?? '0') ?? 0;
          if (cityId > 0) _prefillState(cityId, _db);
        },
      ),
    );
  }

  Widget _buildTextField(ColorScheme cs, String label, TextEditingController controller, {bool isNumber = false, TextInputType? inputType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: inputType ?? (isNumber ? TextInputType.number : TextInputType.text),
          textCapitalization: isNumber || inputType == TextInputType.emailAddress ? TextCapitalization.none : TextCapitalization.words,
          maxLength: isNumber ? 10 : null,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: cs.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: mdaPrimaryBlue, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildApiDropdownField(ColorScheme cs, String label, List<Map<String, String>> items, String? selectedValue, ValueChanged<String?> onChanged, {String valueKey = 'label', bool showAddNew = false, VoidCallback? onAddNewTap}) {
    final menuItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '', child: Text('Select')),
      ...items.map((item) => DropdownMenuItem(value: item[valueKey], child: Text(item['label'] ?? ''))),
    ];
    final effectiveValue = (selectedValue?.isNotEmpty ?? false) ? selectedValue! : '';
    final validValue = menuItems.any((m) => m.value == effectiveValue) ? effectiveValue : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface, fontSize: 13)),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isLoadingDropdowns
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
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
        sheetHeight: 0.75,
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
  final double sheetHeight;

  const _CitySearchSheet({
    required this.cityItems,
    required this.onSelected,
    this.sheetHeight = 0.75,
  });

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
      height: MediaQuery.of(context).size.height * widget.sheetHeight,
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
