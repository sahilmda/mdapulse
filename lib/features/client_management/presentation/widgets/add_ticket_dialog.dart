import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mda_crm/shared/utils/app_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class AddTicketDialog extends StatefulWidget {
  final String customerName;
  final String mobileNumber;
  final String customerSno;
  /// 'true' if this customer is already a Customer (not a Prospect). Default 'false'.
  final String prosCust;

  const AddTicketDialog({
    super.key,
    required this.customerName,
    required this.mobileNumber,
    required this.customerSno,
    this.prosCust = 'false',
  });

  @override
  State<AddTicketDialog> createState() => _AddTicketDialogState();
}

class _AddTicketDialogState extends State<AddTicketDialog> {
  int _currentStep = 2;
  bool _isLoadingDropdowns = true;
  bool _isSaving = false;
  String? _saveError;

  String _clientId = '';
  String _sno = '';
  String _db = '';
  String _ucode = '';

  List<Map<String, String>> _executives = [];
  List<Map<String, String>> _activities = [];
  List<Map<String, String>> _products = [];
  List<Map<String, String>> _pendingStatuses = [];
  List<Map<String, String>> _closeStatuses = [];

  String? _selectedExecutive;
  String? _selectedActivity;
  List<String> _selectedProducts = [];
  String? _selectedStatus;

  late TextEditingController _customerController;
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _nextDaysController = TextEditingController(text: '1');
  final TextEditingController _nextDateController = TextEditingController();
  final TextEditingController _nextTimeController = TextEditingController();

  bool _isCallTypeCall = true;
  bool _isStatusOngoing = true;
  bool _isNextCallTypeCall = true;
  bool _isCheckingUnique = false;


  int _proToCust = 0;
  bool _showCustomerId = false;
  final TextEditingController _customerIdController = TextEditingController();

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _customerController = TextEditingController(
      text: '${widget.customerName} - ${widget.mobileNumber}',
    );
    _mobileController.text = widget.mobileNumber;

    final now = DateTime.now();
    _selectedDate = now;
    _dateController.text = _fmtDate(now);
    _timeController.text = _fmtTimeDT(now);
    _nextDateController.text = _fmtDate(now.add(const Duration(days: 1)));
    _nextTimeController.text = _fmtTimeDT(now);

    _nextDaysController.addListener(_onDaysChanged);
    _fetchDropdowns();
  }

  @override
  void dispose() {
    _customerController.dispose();
    _mobileController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _remarkController.dispose();
    _nextDaysController.removeListener(_onDaysChanged);
    _nextDaysController.dispose();
    _nextDateController.dispose();
    _nextTimeController.dispose();
    _customerIdController.dispose();
    super.dispose();
  }

  void _onDaysChanged() {
    final days = int.tryParse(_nextDaysController.text.trim());
    if (days != null && days >= 0 && mounted) {
      setState(() => _nextDateController.text = _fmtDate(_selectedDate.add(Duration(days: days))));
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  String _fmtTimeDT(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  String _fmtTimeOfDay(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  DateTime _parseDate(String s) {
    try {
      final p = s.split('-');
      return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      return DateTime.now();
    }
  }

  Future<void> _fetchDropdowns() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _clientId = prefs.getString('CLIENTID') ?? '';
      _sno = prefs.getString('sno') ?? '';
      _db = prefs.getString('D_Database') ?? '';
      _ucode = prefs.getString('UCode') ?? '';

      final int snoInt = int.tryParse(_sno) ?? 0;
      final custUrl = Uri.parse('https://webservices.mdapulse.com/Customer.aspx/Fill_DropDown');
      final callUrl = Uri.parse('https://webservices.mdapulse.com/Calling.aspx/Fill_DropDown');
      final headers = {'Content-Type': 'application/json; charset=utf-8'};

      final responses = await Future.wait([
        http.post(custUrl, headers: headers, body: jsonEncode({"ClientId": _clientId, "chk": "Emp", "sno": snoInt, "DB": _db})),
        http.post(custUrl, headers: headers, body: jsonEncode({"ClientId": _clientId, "chk": "TypeOfCall", "sno": snoInt, "DB": _db})),
        http.post(custUrl, headers: headers, body: jsonEncode({"ClientId": _clientId, "chk": "Product", "sno": snoInt, "DB": _db})),
        http.post(callUrl, headers: headers, body: jsonEncode({"ClientId": _clientId, "Type": "Pending", "CustID": 0, "DB": _db})),
        http.post(callUrl, headers: headers, body: jsonEncode({"ClientId": _clientId, "Type": "Close", "CustID": 0, "DB": _db})),
      ]);

      if (mounted) {
        final executives = _parseDropdown(responses[0].body);
        setState(() {
          _executives = executives;
          _activities = _parseDropdown(responses[1].body);
          _products = _parseDropdown(responses[2].body);
          _pendingStatuses = _parseStatusDropdown(responses[3].body);
          _closeStatuses = _parseStatusDropdown(responses[4].body);
          // Auto-select the logged-in user's executive entry
          if (_selectedExecutive == null && executives.any((e) => e['val'] == _ucode)) {
            _selectedExecutive = _ucode;
          }
          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDropdowns = false);
    }
  }

  // Standard: val=parts[0], text=parts[1]  (UCode~UName, sno~ProdName, XlsFldNM~StatName)
  // Deduplicates by val to prevent DropdownButton assertion errors.
  List<Map<String, String>> _parseDropdown(String body) {
    final List<Map<String, String>> result = [];
    final Set<String> seen = {};
    try {
      final raw = jsonDecode(body)['d']?.toString() ?? '';
      for (final row in raw.split('#')) {
        if (row.trim().isEmpty) continue;
        final p = row.split('~');
        if (p.length >= 2) {
          final val = p[0].trim();
          if (seen.add(val)) result.add({'val': val, 'text': p[1].trim()});
        }
      }
    } catch (_) {}
    return result;
  }

  // Status: StatName~sno — display and send StatName. Deduplicates by name.
  List<Map<String, String>> _parseStatusDropdown(String body) {
    final List<Map<String, String>> result = [];
    final Set<String> seen = {};
    try {
      final raw = jsonDecode(body)['d']?.toString() ?? '';
      for (final row in raw.split('#')) {
        final name = row.split('~').first.trim();
        if (name.isNotEmpty && seen.add(name)) result.add({'val': name, 'text': name});
      }
    } catch (_) {}
    return result;
  }

  List<Map<String, String>> get _currentStatuses =>
      _isStatusOngoing ? _pendingStatuses : _closeStatuses;

  Future<void> _pickDate(TextEditingController ctrl, {bool isMain = false}) async {
    final initial = isMain ? _selectedDate : _parseDate(ctrl.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      ctrl.text = _fmtDate(picked);
      if (isMain) {
        _selectedDate = picked;
        final days = int.tryParse(_nextDaysController.text.trim()) ?? 1;
        _nextDateController.text = _fmtDate(picked.add(Duration(days: days)));
      }
    });
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    TimeOfDay initial = TimeOfDay.now();
    try {
      final p1 = ctrl.text.split(':');
      final p2 = p1[1].split(' ');
      int h = int.parse(p1[0]);
      final isPm = p2.length > 1 && p2[1] == 'PM';
      if (isPm && h != 12) h += 12;
      if (!isPm && h == 12) h = 0;
      initial = TimeOfDay(hour: h, minute: int.parse(p2[0]));
    } catch (_) {}
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() => ctrl.text = _fmtTimeOfDay(picked));
  }

  String? _validateStep2() {
    if (_selectedExecutive == null) return 'Please select an Executive.';
    if (_selectedActivity == null) return 'Please select an Activity.';
    if (_selectedProducts.isEmpty) return 'Please select at least one Product.';
    return null;
  }

  Future<void> _onStep2Next() async {
    final err = _validateStep2();
    if (err != null) { setState(() => _saveError = err); return; }

    setState(() { _isCheckingUnique = true; _saveError = null; });

    try {
      final productNames = _selectedProducts.map((val) {
        return _products.firstWhere(
          (p) => p['val'] == val,
          orElse: () => {'text': val},
        )['text'] ?? val;
      }).join(',');

      final rdata = [
        widget.customerSno,        // [0] sno
        widget.customerSno,        // [1] custID
        _selectedExecutive ?? '',  // [2] ucode (unused in server query)
        productNames,              // [3] Product names, comma-separated
        _selectedActivity ?? '',   // [4] typeOfCall / activity
      ].join('^');

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Calling.aspx/chk_UniqueEntry'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': _clientId,
          'Rdata': rdata,
          'ucode': _ucode,
          'DB': _db,
        }),
      );

      if (!mounted) return;

      final result = jsonDecode(response.body)['d']?.toString() ?? '';
      final parts  = result.split('#');

      if (parts[0] == '0') {
        final dupProduct = parts.length > 1 ? parts[1].trim() : 'a selected product';
        setState(() {
          _isCheckingUnique = false;
          _saveError = 'A ticket is already in progress for "$dupProduct". '
              'Please change the activity or product, or edit the existing ticket.';
        });
        return;
      }

      setState(() { _isCheckingUnique = false; _currentStep = 3; _saveError = null; });
    } catch (_) {
      if (mounted) {
        setState(() { _isCheckingUnique = false; _saveError = 'Network error. Check your connection.'; });
      }
    }
  }


  Future<void> _fetchCloseTimeCheck(String statusVal) async {
    if (statusVal.isEmpty) {
      setState(() { _proToCust = 0; _showCustomerId = false; _customerIdController.clear(); });
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Calling.aspx/chkAtCloseTime'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': _clientId, 'val': statusVal, 'DB': _db}),
      );
      if (!mounted) return;

      final data = jsonDecode(response.body)['d']?.toString() ?? '';
      if (data.contains('~')) {
        final saleReject = data.split('#').first.split('~').elementAtOrNull(1)?.trim() ?? '';
        if (saleReject == 'Sale') {
          final alreadyCustomer = widget.prosCust.toLowerCase() == 'true';
          setState(() {
            _proToCust       = alreadyCustomer ? 0 : 1;
            _showCustomerId  = !alreadyCustomer;
            if (alreadyCustomer) _customerIdController.clear();
          });
        } else {
          setState(() { _proToCust = 0; _showCustomerId = false; _customerIdController.clear(); });
        }
      } else {
        setState(() { _proToCust = 0; _showCustomerId = false; _customerIdController.clear(); });
      }
    } catch (_) {
      // silently fail — leave customerID hidden
    }
  }

  void _clearCloseFields() {
    _proToCust = 0;
    _showCustomerId = false;
    _customerIdController.clear();
  }

  String? _validateStep3() {
    if (_dateController.text.isEmpty) return 'Please select a Date.';
    if (_timeController.text.isEmpty) return 'Please select a Time.';
    if (_selectedStatus == null) return 'Please select a Status.';
    if (_isStatusOngoing && _nextDateController.text.isEmpty) {
      return 'Please select a Next Follow-up Date.';
    }
    return null;
  }

  String _buildRemark() {
    final text = _remarkController.text.trim();
    if (text.isEmpty) return '';
    return '${_dateController.text.trim()} --- $text';
  }

  Future<void> _saveTicket() async {
    final err = _validateStep3();
    if (err != null) { setState(() => _saveError = err); return; }

    setState(() { _isSaving = true; _saveError = null; });
    try {
      final productName = _selectedProducts.map((val) {
        return _products.firstWhere((p) => p['val'] == val, orElse: () => {'text': val})['text'] ?? val;
      }).join(', ');

      final rdata = [
        '0',
        widget.customerSno,
        _selectedExecutive ?? '',
        widget.customerName,
        _isCallTypeCall ? 'Call' : 'Visit',
        _dateController.text.trim(),
        _timeController.text.trim(),
        _isStatusOngoing ? 'Pending' : 'Close',
        _selectedStatus ?? '',
        productName,
        _buildRemark(),
        '',                              // [11] Stage (always empty)
        _isStatusOngoing ? _nextDateController.text.trim() : '',
        _isStatusOngoing ? _nextTimeController.text.trim() : '',
        _selectedActivity ?? '',
        _isNextCallTypeCall ? 'Call' : 'Visit',
        _customerIdController.text.trim(),  // [16] ChProToCustId
        '0',                                // [17] TeamMemberCode
        '',                                 // [18] TeamMemberName
      ].join('^');

      debugPrint('[Save_Call] rdata=$rdata');

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Calling.aspx/Save_Call'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept-Language': 'en-US',
        },
        body: jsonEncode({
          'ClientId': _clientId,
          'Rdata': rdata,
          'ucode': _ucode,
          'DB': _db,
          'ProTOcust': _proToCust,
          'sno_11': int.tryParse(widget.customerSno) ?? 0,
        }),
      );

      debugPrint('[Save_Call] status=${response.statusCode} body=${response.body}');

      if (!mounted) return;
      final result = jsonDecode(response.body)['d']?.toString() ?? '';

      if (response.statusCode == 200 && result == '1') {
        Navigator.pop(context, true);
        showAppDialog(context,
          type: DialogType.success,
          title: 'Ticket Added',
          message: 'Ticket has been saved successfully.',
        );
      } else {
        setState(() { _isSaving = false; _saveError = 'Failed to save. Please try again.'; });
      }
    } catch (_) {
      if (mounted) setState(() { _isSaving = false; _saveError = 'Network error. Check your connection.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: mdaPrimaryBlue,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Add Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                  InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 22)),
                ],
              ),
            ),

            // Stepper
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepCircle(1), _buildStepLine(),
                  _buildStepCircle(2), _buildStepLine(),
                  _buildStepCircle(3),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _isLoadingDropdowns
                  ? const Center(child: CircularProgressIndicator(color: mdaPrimaryBlue))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: _currentStep == 1
                          ? _buildStep1()
                          : _currentStep == 2
                              ? _buildStep2()
                              : _buildStep3(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEPS ──────────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(children: [
      const SizedBox(height: 16),
      _buildField('Customer', _customerController, readOnly: true),
      const SizedBox(height: 16),
      _buildField('Mobile Number', _mobileController, readOnly: true),
      const SizedBox(height: 32),
      _navButton('Next', Icons.arrow_right_alt, () => setState(() { _currentStep = 2; _saveError = null; })),
    ]);
  }

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Customer name display
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: mdaPrimaryBlue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: mdaPrimaryBlue.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.person_outline, size: 16, color: mdaPrimaryBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.customerName.isNotEmpty ? widget.customerName : 'Customer',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: mdaPrimaryBlue),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(widget.mobileNumber, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ]),
      ),
      const SizedBox(height: 14),
      _buildDropdown('Executive', _executives, _selectedExecutive,
          (v) => setState(() { _selectedExecutive = v; })),
      const SizedBox(height: 14),
      _buildDropdown('Activity', _activities, _selectedActivity,
          (v) => setState(() { _selectedActivity = v; })),
      const SizedBox(height: 14),
      _buildMultiSelectProduct(),
      const SizedBox(height: 28),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _navButton('Back', Icons.arrow_left, _isCheckingUnique ? null : () => setState(() { _currentStep = 1; _saveError = null; }), isBack: true),
        const SizedBox(width: 12),
        _isCheckingUnique
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: mdaPrimaryBlue, strokeWidth: 2))
            : _navButton('Next', Icons.arrow_right_alt, _onStep2Next),
      ]),
      if (_saveError != null) ...[
        const SizedBox(height: 12),
        _errorBanner(_saveError!),
      ],
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildMultiSelectProduct() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Product', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      const SizedBox(height: 6),
      InkWell(
        onTap: _showProductPicker,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: _selectedProducts.isEmpty
                    ? const Text('Select', style: TextStyle(color: Colors.grey, fontSize: 14))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: _selectedProducts.map((val) {
                          final name = _products.firstWhere(
                            (p) => p['val'] == val, orElse: () => {'text': val})['text'] ?? val;
                          return Chip(
                            label: Text(name, style: const TextStyle(fontSize: 12, color: mdaPrimaryBlue)),
                            deleteIcon: const Icon(Icons.close, size: 14, color: mdaPrimaryBlue),
                            onDeleted: () => setState(() => _selectedProducts.remove(val)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: mdaPrimaryBlue.withValues(alpha: 0.1),
                            side: BorderSide.none,
                          );
                        }).toList(),
                      ),
              ),
              const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    ]);
  }

  Future<void> _showProductPicker() async {
    final temp = List<String>.from(_selectedProducts);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Select Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _products.map((p) {
                final isSelected = temp.contains(p['val']);
                return CheckboxListTile(
                  title: Text(p['text']!, style: const TextStyle(fontSize: 14)),
                  value: isSelected,
                  activeColor: mdaPrimaryBlue,
                  checkColor: Colors.white,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  onChanged: (v) => setDialog(() {
                    if (v == true) { temp.add(p['val']!); }
                    else { temp.remove(p['val']!); }
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); setState(() => _selectedProducts = temp); },
              style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Call Details card
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardHeader(Icons.phone_outlined, 'Call Details'),
        const SizedBox(height: 14),
        _label('Call Type'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _toggle('Call', Icons.phone, _isCallTypeCall, () => setState(() => _isCallTypeCall = true))),
          const SizedBox(width: 10),
          Expanded(child: _toggle('Visit', Icons.location_on_outlined, !_isCallTypeCall, () => setState(() => _isCallTypeCall = false))),
        ]),
        const SizedBox(height: 14),
        _buildField('Date', _dateController, icon: Icons.calendar_today, onTap: () => _pickDate(_dateController, isMain: true)),
        const SizedBox(height: 14),
        _buildField('Time', _timeController, icon: Icons.access_time, onTap: () => _pickTime(_timeController)),
        const SizedBox(height: 14),
        _label('Status Type'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _toggle('Ongoing', Icons.access_time, _isStatusOngoing, () => setState(() {
            _isStatusOngoing = true;
            _selectedStatus = null;
            _clearCloseFields();
          }))),
          const SizedBox(width: 10),
          Expanded(child: _toggle('Closed', Icons.check_circle_outline, !_isStatusOngoing, () => setState(() {
            _isStatusOngoing = false;
            _selectedStatus = null;
            _clearCloseFields();
          }))),
        ]),
        const SizedBox(height: 14),
        _buildDropdown('Status', _currentStatuses, _selectedStatus, (v) {
          setState(() => _selectedStatus = v);
          if (v == null) {
            setState(_clearCloseFields);
            return;
          }
          if (_isStatusOngoing) {
            setState(_clearCloseFields);
          } else {
            _fetchCloseTimeCheck(v);
          }
        }),
        if (_showCustomerId) ...[
          const SizedBox(height: 14),
          _buildField('Customer ID', _customerIdController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        ],
        const SizedBox(height: 14),
        _label('Remark'),
        const SizedBox(height: 8),
        TextField(
          controller: _remarkController,
          maxLines: 3,
          decoration: InputDecoration(
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: mdaPrimaryBlue, width: 2)),
          ),
        ),
      ])),
      const SizedBox(height: 14),

      // Follow-up card
      if (_isStatusOngoing)
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHeader(Icons.calendar_today_outlined, 'Follow-up Details'),
          const SizedBox(height: 14),
          _label('Next Call Type'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _toggle('Call', Icons.phone, _isNextCallTypeCall, () => setState(() => _isNextCallTypeCall = true))),
            const SizedBox(width: 10),
            Expanded(child: _toggle('Visit', Icons.location_on_outlined, !_isNextCallTypeCall, () => setState(() => _isNextCallTypeCall = false))),
          ]),
          const SizedBox(height: 14),
          _buildField('After Number of Days', _nextDaysController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 14),
          _buildField('Next Follow-up Date', _nextDateController, icon: Icons.calendar_today, onTap: () => _pickDate(_nextDateController)),
          const SizedBox(height: 14),
          _buildField('Next Follow-up Time', _nextTimeController, icon: Icons.access_time, onTap: () => _pickTime(_nextTimeController)),
        ])),

      if (_saveError != null) ...[
        const SizedBox(height: 12),
        _errorBanner(_saveError!),
      ],
      const SizedBox(height: 20),

      // Footer buttons
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _navButton('Back', Icons.arrow_left, () => setState(() { _currentStep = 2; _saveError = null; }), isBack: true),
        const SizedBox(width: 12),
        _isSaving
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: mdaPrimaryBlue, strokeWidth: 2))
            : ElevatedButton(
                onPressed: _saveTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: mdaPrimaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
      ]),
      const SizedBox(height: 8),
    ]);
  }

  // ── HELPER WIDGETS ─────────────────────────────────────────────────────────

  Widget _buildStepCircle(int step) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? mdaPrimaryBlue : isDone ? Colors.green.shade100 : Colors.grey.shade100,
        boxShadow: isActive ? [BoxShadow(color: mdaPrimaryBlue.withValues(alpha: 0.35), blurRadius: 8, spreadRadius: 1)] : null,
      ),
      alignment: Alignment.center,
      child: isDone
          ? const Icon(Icons.check, color: Colors.green, size: 20)
          : Text(step.toString(), style: TextStyle(color: isActive ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildStepLine() => Container(
    width: 36, height: 2,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: Colors.grey.shade300,
  );

  Widget _navButton(String label, IconData icon, VoidCallback? onPressed, {bool isBack = false}) =>
    ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isBack ? Colors.grey.shade200 : mdaPrimaryBlue,
        foregroundColor: isBack ? Colors.black87 : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isBack) ...[Icon(icon, size: 18), const SizedBox(width: 4)],
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        if (!isBack) ...[const SizedBox(width: 4), Icon(icon, size: 18)],
      ]),
    );

  Widget _toggle(String text, IconData icon, bool isActive, VoidCallback onTap) =>
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? mdaPrimaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? mdaPrimaryBlue : Colors.grey.shade300),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: isActive ? Colors.white : Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: isActive ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      ),
    );

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold));

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: child,
  );

  Widget _cardHeader(IconData icon, String title) => Row(children: [
    Icon(icon, color: mdaPrimaryBlue.withValues(alpha: 0.7), size: 18),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
  ]);

  Widget _errorBanner(String msg) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade200)),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: const TextStyle(color: Colors.red, fontSize: 13))),
    ]),
  );

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    bool readOnly = false,
    IconData? icon,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      const SizedBox(height: 6),
      SizedBox(
        height: 42,
        child: TextField(
          controller: ctrl,
          readOnly: readOnly || onTap != null,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onTap: onTap,
          style: TextStyle(color: readOnly ? Colors.grey.shade600 : Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            suffixIcon: icon != null ? Icon(icon, size: 18, color: Colors.grey.shade500) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: readOnly ? Colors.grey.shade300 : mdaPrimaryBlue, width: readOnly ? 1 : 2)),
          ),
        ),
      ),
    ]);
  }

  Widget _buildDropdown(String label, List<Map<String, String>> items, String? value, ValueChanged<String?> onChanged) {
    final safeValue = value != null && items.any((e) => e['val'] == value) ? value : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      const SizedBox(height: 6),
      Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: DropdownButton<String>(
          isExpanded: true,
          value: safeValue,
          underline: const SizedBox.shrink(),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          hint: const Text('Select', style: TextStyle(fontSize: 14, color: Colors.grey)),
          items: items.map((e) => DropdownMenuItem(value: e['val'], child: Text(e['text']!, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    ]);
  }
}
