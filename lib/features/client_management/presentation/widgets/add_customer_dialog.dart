// File: lib/features/client_management/presentation/widgets/add_customer_dialog.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class AddCustomerDialog extends StatefulWidget {
  const AddCustomerDialog({super.key});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  int _currentStep = 1;
  bool _isLoading = false;
  String? _errorMessage;

  // Controllers - Step 1
  final TextEditingController _mobileController = TextEditingController();

  // Controllers - Step 2
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _altNoController = TextEditingController();
  final TextEditingController _altNameController = TextEditingController();

  // Dropdown Selections - Step 2
  String? _selectedCategory;
  String? _selectedGrouping;
  String? _selectedSource;

  // Controllers - Step 3
  final TextEditingController _add1Controller = TextEditingController();
  final TextEditingController _add2Controller = TextEditingController();
  final TextEditingController _add3Controller = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();

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
    _stateController.dispose();
    super.dispose();
  }

  // --- API LOGIC PLACEHOLDERS ---
  
  Future<void> _verifyMobileAndProceed() async {
    final mobile = _mobileController.text.trim();
    if (mobile.length != 10) {
      setState(() => _errorMessage = "Please enter a valid 10-digit mobile number.");
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    await Future.delayed(const Duration(milliseconds: 800)); 

    setState(() {
      _isLoading = false;
      _currentStep = 2; 
    });
  }

  bool _isSaving = false;

  Future<void> _saveCustomer() async {
    if (_contactPersonController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Contact Person is required.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      final String sno = prefs.getString('sno') ?? '1';
      final String ucode = prefs.getString('UCode') ?? '1';
      
      final String autoAllotStr = prefs.getString('AutoAllot') ?? 'true';
      final bool autoAllot = autoAllotStr.toLowerCase() == 'true' || autoAllotStr == '1';

      final String orgName = _orgNameController.text.trim();
      final String custName = _contactPersonController.text.trim();
      final String email = _emailController.text.trim();
      final String category = _selectedCategory != 'Select' && _selectedCategory != null ? _selectedCategory! : '';
      final String remark = _remarkController.text.trim();
      final String altNo = _altNoController.text.trim();
      
      // Step 3 Variables (location — all optional)
      final String add1 = _add1Controller.text.trim();
      final String add2 = _add2Controller.text.trim();
      final String add3 = _add3Controller.text.trim();
      final String pin = _pinController.text.trim().isEmpty ? '0' : _pinController.text.trim();
      final String city = _cityController.text.trim();
      final String state = _stateController.text.trim();

      final String mobile = _mobileController.text.trim();
      const String custType = '0';
      const String custId = '0';
      const String custDateTxt = '';
      final String altName = _altNameController.text.trim();

      final String archSNo = _selectedGrouping != 'Select' && _selectedGrouping != null ? _selectedGrouping! : '0';
      final String source = _selectedSource != 'Select' && _selectedSource != null ? _selectedSource! : '';

      const String reference = '';
      const String referBy = '';

      // 21 fields delimited by ^
      final String rdata = "$orgName^$custName^$email^$category^$remark^$altNo^$add1^$add2^$add3^$pin^$city^$state^$mobile^$custType^$custId^$custDateTxt^$altName^$archSNo^$source^$reference^$referBy";

      final response = await http.post(
        Uri.parse('https://mdapulse.com/Customer.aspx/SaveCustomer'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          "ClientId": clientId,
          "sno": sno,
          "rdata": rdata,
          "ucode": ucode,
          "hid": 0,
          "AutoAllot": autoAllot,
          "DB": db
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String result = responseData['d'] ?? '';

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

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    // Determine dialog height based on step
    final double dialogHeight = _currentStep == 1 ? 350 : MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      backgroundColor: Colors.grey.shade50,
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
            // Header
            Container(
              color: mdaPrimaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add New Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 20)),
                ],
              ),
            ),

            // Custom Stepper
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: _buildCustomStepper(),
            ),

            // Error Message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0).copyWith(bottom: 12),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
              ),

            // Content Area (Scrollable for Step 2 & 3)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildStepContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStepCircle(1),
        _buildStepLine(),
        _buildStepCircle(2),
        _buildStepLine(),
        _buildStepCircle(3),
      ],
    );
  }

  Widget _buildStepCircle(int stepNumber) {
    bool isActive = _currentStep == stepNumber;
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: isActive ? mdaPrimaryBlue : Colors.grey.shade100,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [BoxShadow(color: mdaPrimaryBlue.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)]
            : null,
      ),
      child: Center(
        child: Text(
          '$stepNumber',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade500,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine() {
    return Container(
      width: 40,
      height: 2,
      color: Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildStepContent() {
    if (_currentStep == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildTextField('Mobile Number', _mobileController, isNumber: true),
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
          _buildTextField('Contact Person *', _contactPersonController, inputType: TextInputType.text),
          const SizedBox(height: 16),
          _buildTextField('Organisation Name', _orgNameController, inputType: TextInputType.text),
          const SizedBox(height: 16),
          _buildTextField('Email', _emailController, inputType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField('Remark', _remarkController, inputType: TextInputType.text),
          const SizedBox(height: 16),
          _buildTextField('Alternate No.', _altNoController, isNumber: true),
          const SizedBox(height: 16),
          _buildTextField('Alternate Name', _altNameController, inputType: TextInputType.name),
          const SizedBox(height: 16),
          
          _buildDropdownField('Category', true, ['Select', 'Accountant', 'Cash'], _selectedCategory, (val) => setState(() => _selectedCategory = val)),
          const SizedBox(height: 16),
          _buildDropdownField('Grouping Name', true, ['Select', 'Group A', 'Group B'], _selectedGrouping, (val) => setState(() => _selectedGrouping = val)),
          const SizedBox(height: 16),
          _buildDropdownField('Source', true, ['Select', 'Google', 'Reference'], _selectedSource, (val) => setState(() => _selectedSource = val)),
          const SizedBox(height: 32),

          // Action Buttons for Step 2
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mdaPrimaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(children: [
                  Icon(Icons.arrow_back, size: 20), 
                  SizedBox(width: 8), 
                  Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                ]),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => setState(() => _currentStep = 3),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mdaPrimaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(children: [
                  Text('Next', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
                  SizedBox(width: 8), 
                  Icon(Icons.arrow_forward, size: 20)
                ]),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      );
    } else {
      // STEP 3 — Location Details
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTextField('Address Line 1', _add1Controller),
          const SizedBox(height: 16),
          _buildTextField('Address Line 2', _add2Controller),
          const SizedBox(height: 16),
          _buildTextField('Address Line 3', _add3Controller),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField('Pin Code', _pinController, isNumber: true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('City', _cityController)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField('State', _stateController),
          const SizedBox(height: 32),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isSaving ? null : () => setState(() => _currentStep = 2),
                style: ElevatedButton.styleFrom(
                  backgroundColor: mdaPrimaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Row(children: [
                  Icon(Icons.arrow_back, size: 20),
                  SizedBox(width: 8),
                  Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              ),
              const SizedBox(width: 16),
              _isSaving
                  ? const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: Colors.green))
                  : ElevatedButton(
                      onPressed: _saveCustomer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
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

 // UPDATED: Added inputType and pure white background
  Widget _buildTextField(String label, TextEditingController controller, {bool isNumber = false, TextInputType? inputType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          // Bulletproof fallback
          keyboardType: inputType ?? (isNumber ? TextInputType.number : TextInputType.text),
          // Auto-capitalize words for any text input
          textCapitalization: isNumber || inputType == TextInputType.emailAddress ? TextCapitalization.none : TextCapitalization.words,
          maxLength: isNumber ? 10 : null,
          decoration: InputDecoration(
            counterText: '', 
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: mdaPrimaryBlue, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, bool showAddNew, List<String> items, String? selectedValue, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 13)),
            if (showAddNew) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                child: const Text('Add New', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
            ]
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white, // ADDED: Pure white background for dropdowns
            border: Border.all(color: Colors.grey.shade300), 
            borderRadius: BorderRadius.circular(8)
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedValue ?? items[0],
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}