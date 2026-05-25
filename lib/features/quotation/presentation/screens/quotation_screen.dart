import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mda_crm/shared/widgets/app_main_scaffold.dart';
import 'package:mda_crm/shared/widgets/app_drawer.dart';
import 'package:mda_crm/features/client_management/presentation/widgets/add_customer_dialog.dart';
import 'package:mda_crm/features/quotation/presentation/screens/quotation_preview_screen.dart';
import 'package:mda_crm/features/quotation/presentation/quotation_pdf_data.dart';

// ── Product row model ─────────────────────────────────────────────────────────

class _ProductRow {
  final TextEditingController nameCtrl     = TextEditingController();
  final FocusNode             nameFocus    = FocusNode();
  final TextEditingController qtyCtrl      = TextEditingController();
  final TextEditingController unitCtrl     = TextEditingController();
  final FocusNode             unitFocus    = FocusNode();
  final TextEditingController rateCtrl     = TextEditingController();
  final TextEditingController discountCtrl = TextEditingController();
  final TextEditingController descCtrl     = TextEditingController();
  String discType = 'PAMT';

  void dispose() {
    nameCtrl.dispose();     nameFocus.dispose();
    qtyCtrl.dispose();      unitCtrl.dispose();
    unitFocus.dispose();    rateCtrl.dispose();
    discountCtrl.dispose(); descCtrl.dispose();
  }
}

// ── History record model ──────────────────────────────────────────────────────

class _HistoryRecord {
  final String sno, date, expiryDate, custName, renamedCust;
  final String state, gstFigure, qtnNo, descr, ph1, sno11, executive;
  final double subTotal, totalAmt, overallDiscount, netTotal;

  const _HistoryRecord({
    required this.sno,         required this.date,
    required this.expiryDate,  required this.custName,
    required this.renamedCust, required this.state,
    required this.gstFigure,   required this.qtnNo,
    required this.descr,       required this.ph1,
    required this.sno11,       required this.executive,
    required this.subTotal,    required this.totalAmt,
    required this.overallDiscount, required this.netTotal,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class QuotationScreen extends StatefulWidget {
  const QuotationScreen({super.key});

  @override
  State<QuotationScreen> createState() => _QuotationScreenState();
}

class _QuotationScreenState extends State<QuotationScreen> {
  String _clientId    = '';
  String _db          = '';
  String _uCode       = '';
  String _companyName = '';
  String _logoUrl     = '';
  String _quoteHistory = 'false';
  String _quotationNo = '0';

  final _dateCtrl     = TextEditingController();
  final _expiryCtrl   = TextEditingController();
  final _renameCtrl   = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _gstPctCtrl   = TextEditingController();

  String? _selectedState;
  List<String> _states = [];
  String _gstType      = 'IncGst';
  String _discountType = 'PAMT';

  String _customerSno  = '';
  String _customerName = '';
  String _customerPh1  = '';

  final List<_ProductRow> _products = [];

  double _netTotal    = 0;
  double _preTaxTotal = 0;

  bool _showHistory    = false;
  List<_HistoryRecord> _history = [];
  bool _historyLoading = false;

  String _editSno   = '0';
  bool _isSaving    = false;
  String _saveError = '';

  // Firm / template data (from FillFirm + getFirmDesign)
  String _firmId          = '0';
  String _firmPrintedName = '';
  String _firmLogoUrl     = '';
  String _firmSignUrl     = '';
  String _headerHtml      = '';
  String _termsHtml       = '';
  String _bankHtml        = '';

  static const _baseUrl = 'https://webservices.mdapulse.com/Quotation.aspx';
  static const _custUrl = 'https://webservices.mdapulse.com/Customer.aspx';
  static const _headers = {'Content-Type': 'application/json; charset=utf-8'};
  static const _blue    = Color(0xFF0257E6);
  static const _blueSoft = Color(0xFFE8EFFD);

  // ── lifecycle ────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _addProductRow();
    _initSession();
  }

  @override
  void dispose() {
    _dateCtrl.dispose();  _expiryCtrl.dispose();
    _renameCtrl.dispose(); _discountCtrl.dispose();
    _gstPctCtrl.dispose();
    for (final p in _products) { p.dispose(); }
    super.dispose();
  }

  Future<void> _initSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _clientId    = prefs.getString('CLIENTID') ?? '';
      _db          = prefs.getString('D_Database') ?? '';
      _uCode       = prefs.getString('UCode') ?? '';
      _companyName = prefs.getString('O_Name') ?? '';
      _logoUrl     = prefs.getString('LogoURL') ?? '';
      _quoteHistory = prefs.getString('Quote_History') ?? 'false';
    });
    final today = _fmtDate(DateTime.now());
    _dateCtrl.text = today;
    _setExpiryDate(today);
    _fetchQuotationNo();
    _fetchStates();
    _fetchFirm();
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}-${d.month.toString().padLeft(2,'0')}-${d.year}';

  void _setExpiryDate(String fromStr) {
    final p = fromStr.split('-');
    if (p.length < 3) return;
    final dd = int.tryParse(p[0]) ?? 1;
    final mm = int.tryParse(p[1]) ?? 1;
    final yy = int.tryParse(p[2]) ?? 2025;
    _expiryCtrl.text = _fmtDate(DateTime(yy, mm + 1, dd).subtract(const Duration(days: 1)));
  }

  Future<DateTime?> _pickDate(String current) async {
    DateTime init = DateTime.now();
    final p = current.split('-');
    if (p.length == 3) {
      init = DateTime(int.tryParse(p[2]) ?? init.year,
                      int.tryParse(p[1]) ?? init.month,
                      int.tryParse(p[0]) ?? init.day);
    }
    return showDatePicker(
      context: context, initialDate: init,
      firstDate: DateTime(2020), lastDate: DateTime(2035),
    );
  }

  InputDecoration _dec({String? hint, Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFAAAFBB)),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE1EA)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDE1EA)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _blue, width: 1.5),
    ),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
  );

  // ── API ──────────────────────────────────────────────────────────────────────

  Future<void> _fetchFirm() async {
    try {
      final r = await http.post(Uri.parse('$_baseUrl/FillFirm'),
          headers: _headers,
          body: jsonEncode({'ClientId': _clientId, 'DB': _db}));
      if (r.statusCode != 200 || !mounted) return;
      final raw = jsonDecode(r.body)['d']?.toString() ?? '';
      if (!raw.contains('~')) return;
      final first = raw.split('#').firstWhere((s) => s.contains('~'), orElse: () => '');
      if (first.isEmpty) return;
      final p = first.split('~');
      final id = p[0];
      final name = p.length > 1 ? p[1] : '';
      setState(() { _firmId = id; _firmPrintedName = name; });
      await _fetchFirmDesign(id);
    } catch (_) {}
  }

  Future<void> _fetchFirmDesign(String firmId) async {
    try {
      final r = await http.post(Uri.parse('$_baseUrl/getFirmDesign'),
          headers: _headers,
          body: jsonEncode({'ClientId': _clientId, 'DB': _db, 'val1': firmId}));
      if (r.statusCode != 200 || !mounted) return;
      final raw = jsonDecode(r.body)['d']?.toString() ?? '';
      final cleaned = raw.endsWith('#') ? raw.substring(0, raw.length - 1) : raw;
      if (!cleaned.contains('^')) return;
      final p = cleaned.split('^');
      setState(() {
        if (p.length > 3 && p[3].isNotEmpty) _firmPrintedName = p[3];
        if (p.length > 4) _firmLogoUrl = p[4];
        if (p.length > 5) _firmSignUrl = p[5];
        if (p.length > 6) _headerHtml  = p[6];
        if (p.length > 7) _termsHtml   = p[7];
        if (p.length > 8) _bankHtml    = p[8];
      });
    } catch (_) {}
  }

  Future<void> _fetchQuotationNo() async {
    try {
      final r = await http.post(Uri.parse('$_baseUrl/getQuotationNo'),
          headers: _headers,
          body: jsonEncode({'ClientId': _clientId, 'DB': _db}));
      if (r.statusCode == 200 && mounted) {
        final v = jsonDecode(r.body)['d']?.toString() ?? '0';
        setState(() => _quotationNo = v);
      }
    } catch (_) {}
  }

  Future<void> _fetchStates() async {
    try {
      final r = await http.post(Uri.parse('$_custUrl/fillCategory'),
          headers: _headers,
          body: jsonEncode({'ClientId': _clientId, 'Type1': 'State', 'DB': _db}));
      if (r.statusCode == 200 && mounted) {
        final raw = jsonDecode(r.body)['d']?.toString() ?? '';
        if (raw.contains('^')) {
          final list = raw.split('#')
              .where((s) => s.contains('^'))
              .map((s) => s.split('^')[1].trim())
              .where((s) => s.isNotEmpty)
              .toList();
          setState(() => _states = list);
        }
      }
    } catch (_) {}
  }

  Future<List<String>> _fetchSuggestions(String value, String type) async {
    try {
      final r = await http.post(Uri.parse('$_baseUrl/getProduct'),
          headers: _headers,
          body: jsonEncode({'ClientId': _clientId, 'DB': _db, 'value': value, 'typ1': type}));
      if (r.statusCode == 200) {
        final raw = jsonDecode(r.body)['d']?.toString() ?? '';
        if (raw.contains('^')) {
          return raw.split('#')
              .where((s) => s.contains('^'))
              .map((s) => s.split('^')[1].trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, String>>> _searchCustomers(String value) async {
    try {
      final r = await http.post(Uri.parse('$_baseUrl/fillCustomerList'),
          headers: _headers,
          body: jsonEncode({'ClientId': _clientId, 'DB': _db, 'value': value}));
      if (r.statusCode == 200) {
        final raw = jsonDecode(r.body)['d']?.toString() ?? '';
        if (raw.contains('^')) {
          return raw.split('#')
              .where((s) => s.contains('^'))
              .map((s) {
                final p = s.split('^');
                return {
                  'sno':     p.isNotEmpty  ? p[0] : '',
                  'ph1':     p.length > 1  ? p[1] : '',
                  'name':    p.length > 2  ? p[2] : '',
                  'state':   p.length > 3  ? p[3] : '',
                  'cperson': p.length > 4  ? p[4] : '',
                };
              }).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<List<_HistoryRecord>> _fetchHistory() async {
    try {
      final r = await http.post(Uri.parse('$_baseUrl/ListQtnHistory'),
          headers: _headers,
          body: jsonEncode({'ClientId': _clientId, 'DB': _db}));
      if (r.statusCode == 200) {
        final raw = jsonDecode(r.body)['d']?.toString() ?? '';
        if (!raw.contains('~')) return [];
        return raw.split('#').where((s) => s.contains('~')).map((s) {
          final p = s.split('~');
          final text1 = p.length > 1  ? p[1] : '';
          final text3 = p.length > 3  ? p[3] : '';
          final text4 = p.length > 4  ? p[4] : '';
          String custName = text1, renamed = '';
          if (text1.contains('^')) {
            custName = text1.split('^')[0];
            renamed  = text1.split('^')[1];
          }
          final exec   = text3.contains('^') ? text3.split('^')[1] : '';
          final state  = text4.contains('^') ? text4.split('^')[0] : text4;
          final expiry = text4.contains('^') ? text4.split('^')[1] : '';
          return _HistoryRecord(
            sno:             p.isNotEmpty   ? p[0]  : '',
            date:            p.length > 2   ? p[2]  : '',
            expiryDate:      expiry,
            custName:        custName,
            renamedCust:     renamed,
            state:           state,
            gstFigure:       p.length > 5   ? p[5]  : '',
            qtnNo:           p.length > 6   ? p[6]  : '',
            subTotal:        double.tryParse(p.length > 7  ? p[7]  : '0') ?? 0,
            totalAmt:        double.tryParse(p.length > 8  ? p[8]  : '0') ?? 0,
            overallDiscount: double.tryParse(p.length > 9  ? p[9]  : '0') ?? 0,
            netTotal:        double.tryParse(p.length > 10 ? p[10] : '0') ?? 0,
            descr:           p.length > 11  ? p[11] : '',
            ph1:             p.length > 12  ? p[12] : '',
            sno11:           p.length > 13  ? p[13] : '',
            executive:       exec,
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> _saveQuotation() async {
    final overallDiscAmt = _calcOverallDiscAmt();
    final allTotal       = _calcAllTotal();
    final custData = [
      _quotationNo, _dateCtrl.text, _expiryCtrl.text, _customerName,
      _selectedState ?? '', _preTaxTotal.toStringAsFixed(2),
      allTotal.toStringAsFixed(2), overallDiscAmt.toStringAsFixed(2),
      _netTotal.toStringAsFixed(2), _sanitize(_renameCtrl.text), _customerSno, _customerPh1,
    ].join('^');

    final sb = StringBuffer();
    final listProd = StringBuffer();
    final listUnit = StringBuffer();
    for (final p in _products) {
      final name = _sanitize(p.nameCtrl.text.trim());
      final qty  = double.tryParse(p.qtyCtrl.text) ?? 0;
      final unit = _sanitize(p.unitCtrl.text.trim());
      final rate = double.tryParse(p.rateCtrl.text) ?? 0;
      final disc = double.tryParse(p.discountCtrl.text) ?? 0;
      final desc = _sanitize(p.descCtrl.text.trim());
      final String discStr;
      final double amount;
      if (p.discType == 'PER') {
        discStr = '${disc.toStringAsFixed(2)}%';
        amount  = (rate - (rate * disc / 100)) * qty;
      } else {
        discStr = disc.toStringAsFixed(2);
        amount  = (rate - disc) * qty;
      }
      sb.write('$name^${qty.toStringAsFixed(2)}^$unit^${rate.toStringAsFixed(2)}'
               '^$discStr^${amount.toStringAsFixed(2)}^$desc((');
      listProd.write('$name^');
      listUnit.write('$unit^');
    }

    final isHistoryMode = _quoteHistory.toLowerCase() == 'true';
    final payload = jsonEncode({
      'ClientId': _clientId, 'DB': _db,
      'Prdata': sb.toString(), 'custData': custData, 'UCode': _uCode,
      'GstFigure': _buildGstFigure(),
      'ListProduct': listProd.toString(), 'ListUnit': listUnit.toString(),
      'QHSR': isHistoryMode ? 1 : 0,
      'hidQSno': int.tryParse(_editSno) ?? 0,
      'FirmQtn': int.tryParse(_firmId) ?? 0,
    });

    if (!isHistoryMode) {
      // Non-history mode: quotation is print-only; server call only updates master tables.
      // Fire-and-forget — don't block on the result.
      Future(() async {
        try {
          await http.post(Uri.parse('$_baseUrl/SaveQuatation'),
              headers: _headers, body: payload);
        } catch (_) {}
      });
      return true;
    }

    try {
      final r = await http.post(Uri.parse('$_baseUrl/SaveQuatation'),
          headers: _headers, body: payload);
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body)['d']?.toString() ?? '';
        if (d != '1') {
          _saveError = 'Server returned: "$d"';
          return false;
        }
        return true;
      }
      _saveError = 'HTTP ${r.statusCode}: ${r.body.length > 120 ? r.body.substring(0, 120) : r.body}';
    } catch (e) {
      _saveError = e.toString();
    }
    return false;
  }

  Future<void> _deleteQuotation(String sno) async {
    try {
      await http.post(Uri.parse('$_baseUrl/DeleteQuatation'),
          headers: _headers,
          body: jsonEncode({'ClientId': _clientId, 'DB': _db, 'QSno': int.tryParse(sno) ?? 0}));
    } catch (_) {}
  }

  // ── calculations ──────────────────────────────────────────────────────────────

  void _recalculate() {
    double net = 0;
    for (final p in _products) {
      final qty  = double.tryParse(p.qtyCtrl.text) ?? 0;
      final rate = double.tryParse(p.rateCtrl.text) ?? 0;
      final disc = double.tryParse(p.discountCtrl.text) ?? 0;
      net += p.discType == 'PER'
          ? (rate - (rate * disc / 100)) * qty
          : (rate - disc) * qty;
    }
    final discAmt = _calcOverallDiscAmtFrom(net, double.tryParse(_discountCtrl.text) ?? 0);
    setState(() { _netTotal = net; _preTaxTotal = net - discAmt; });
  }

  double _calcOverallDiscAmt() =>
      _calcOverallDiscAmtFrom(_netTotal, double.tryParse(_discountCtrl.text) ?? 0);

  double _calcOverallDiscAmtFrom(double net, double d) =>
      _discountType == 'PER' ? (net * d / 100) : d;

  double _calcAllTotal() {
    if (_gstType == 'Gst') {
      final pct = double.tryParse(_gstPctCtrl.text) ?? 0;
      return _preTaxTotal + (_preTaxTotal * pct / 100);
    }
    return _preTaxTotal;
  }

  String _buildGstFigure() {
    if (_gstType == 'ExcGst') return 'ExcGst';
    if (_gstType != 'Gst')    return 'IncGst';
    final pct    = double.tryParse(_gstPctCtrl.text) ?? 0;
    final gstAmt = _preTaxTotal * pct / 100;
    final state  = (_selectedState ?? '').toUpperCase();
    if (state == 'UTTAR PRADESH') {
      return 'CGST^${gstAmt / 2}^${pct / 2}^SGST^${gstAmt / 2}^${pct / 2}';
    }
    return 'IGST^$gstAmt^$pct';
  }

  // ── products ──────────────────────────────────────────────────────────────────

  void _addProductRow() {
    final p = _ProductRow();
    void listener() => _recalculate();
    p.qtyCtrl.addListener(listener);
    p.rateCtrl.addListener(listener);
    p.discountCtrl.addListener(listener);
    setState(() => _products.add(p));
  }

  void _removeProductRow(int idx) {
    if (_products.length <= 1) return;
    _products[idx].dispose();
    setState(() => _products.removeAt(idx));
    _recalculate();
  }

  // ── sanitize ──────────────────────────────────────────────────────────────────

  // Mirrors the JS: .replace(/[~^'"#\r\n]/g,'').replace(/\(\(/g,'[').replace(/\)\)/g,']')
  String _sanitize(String s) => s
      .replaceAll(RegExp(r'''[~^'"#\r\n]'''), '')
      .replaceAll('((', '[')
      .replaceAll('))', ']');

  // ── validation ────────────────────────────────────────────────────────────────

  String? _validate() {
    if (_dateCtrl.text.isEmpty)   return 'Please fill Date';
    if (_expiryCtrl.text.isEmpty) return 'Please fill Expiry Date';
    if (_customerName.isEmpty)    return 'Please select a Customer';
    if (_selectedState == null)   return 'Please select Place of Supply';
    if (_gstType == 'Gst' && _gstPctCtrl.text.isEmpty) return 'Please fill GST %';
    for (var i = 0; i < _products.length; i++) {
      final p = _products[i];
      if (p.nameCtrl.text.trim().isEmpty)               return 'Product name required in row ${i + 1}';
      if ((double.tryParse(p.qtyCtrl.text) ?? 0) <= 0) return 'Qty > 0 required in row ${i + 1}';
      if (p.unitCtrl.text.trim().isEmpty)               return 'Unit required in row ${i + 1}';
      if ((double.tryParse(p.rateCtrl.text) ?? 0) <= 0) return 'Rate > 0 required in row ${i + 1}';
    }
    return null;
  }

  // ── customer dialogs ──────────────────────────────────────────────────────────

  Future<void> _showAddCustomerDialog() async {
    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddCustomerDialog(isOldCustomer: false),
    );
    if (added == true && mounted) _showCustomerDialog();
  }

  Future<void> _showCustomerDialog() async {
    final searchCtrl = TextEditingController();
    List<Map<String, String>> results = [];
    Map<String, String>? selected;

    final chosen = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── header ──────────────────────────────────────────────────────
            Container(
              color: _blue,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(children: [
                const Expanded(
                  child: Text('CustomerList',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ]),
            ),

            // ── search row ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(children: [
                const Text('Search Customer : ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      isDense: true,
                    ),
                    onChanged: (v) async {
                      if (v.length < 2) { setSt(() => results = []); return; }
                      final list = await _searchCustomers(v);
                      setSt(() { results = list; selected = null; });
                    },
                  ),
                ),
              ]),
            ),

            // ── table ────────────────────────────────────────────────────
            Flexible(
              child: results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        searchCtrl.text.length < 2
                            ? 'Type at least 2 characters to search...'
                            : 'No customers found.',
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                          headingTextStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                          dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                          dataRowMinHeight: 38,
                          dataRowMaxHeight: 46,
                          columnSpacing: 14,
                          horizontalMargin: 12,
                          dividerThickness: 0.8,
                          border: TableBorder(
                            top: BorderSide(color: Colors.grey.shade300),
                            bottom: BorderSide(color: Colors.grey.shade300),
                            horizontalInside: BorderSide(color: Colors.grey.shade200),
                          ),
                          columns: const [
                            DataColumn(label: Text('Show')),
                            DataColumn(label: Text('Mobile Number')),
                            DataColumn(label: Text('Organisation Name')),
                            DataColumn(label: Text('Contact Person')),
                          ],
                          rows: results.map((c) {
                            final isSel = c['sno'] == selected?['sno'];
                            return DataRow(
                              color: WidgetStateProperty.resolveWith((states) =>
                                  isSel ? _blueSoft : null),
                              cells: [
                                DataCell(Checkbox(
                                  value: isSel,
                                  activeColor: _blue,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (_) => setSt(() => selected = isSel ? null : c),
                                )),
                                DataCell(Text(c['ph1'] ?? '')),
                                DataCell(Text(c['name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w500))),
                                DataCell(Text(c['cperson'] ?? '')),
                              ],
                              onSelectChanged: (_) => setSt(() => selected = isSel ? null : c),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),

            // ── footer ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                ElevatedButton(
                  onPressed: selected == null ? null : () => Navigator.pop(ctx, selected),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _blue, foregroundColor: Colors.white),
                  child: const Text('Confirm'),
                ),
              ]),
            ),
          ]),
        );
      }),
    );

    if (chosen != null && mounted) {
      setState(() {
        _customerSno  = chosen['sno'] ?? '';
        _customerName = chosen['name'] ?? '';
        _customerPh1  = chosen['ph1'] ?? '';
        final st = chosen['state'] ?? '';
        if (st.isNotEmpty && _states.contains(st)) {
          _selectedState = st;
        } else if (_states.isNotEmpty && !_states.contains(_selectedState)) {
          _selectedState = _states.contains('UTTAR PRADESH') ? 'UTTAR PRADESH' : _states.first;
        }
      });
    }
  }

  // ── form reset / edit ─────────────────────────────────────────────────────────

  void _resetForm() {
    for (final p in _products) { p.dispose(); }
    _products.clear();
    setState(() {
      _customerSno = ''; _customerName = ''; _customerPh1 = '';
      _selectedState = null; _gstType = 'IncGst'; _editSno = '0';
      _discountType = 'PAMT'; _netTotal = 0; _preTaxTotal = 0;
    });
    _renameCtrl.clear(); _discountCtrl.clear(); _gstPctCtrl.clear();
    final today = _fmtDate(DateTime.now());
    _dateCtrl.text = today;
    _setExpiryDate(today);
    _addProductRow();
    _fetchQuotationNo();
  }

  void _loadForEdit(_HistoryRecord rec) {
    for (final p in _products) { p.dispose(); }
    _products.clear();

    String gstType = 'IncGst', gstPct = '';
    if (rec.gstFigure.contains('^')) {
      final gp = rec.gstFigure.split('^');
      gstType = 'Gst';
      if (gp.length == 6) {
        gstPct = ((double.tryParse(gp[2]) ?? 0) + (double.tryParse(gp[5]) ?? 0)).toStringAsFixed(0);
      } else if (gp.length == 3) {
        gstPct = gp[2];
      }
    } else {
      gstType = rec.gstFigure == 'ExcGst' ? 'ExcGst' : 'IncGst';
    }

    if (rec.descr.contains('^')) {
      for (final ps in rec.descr.split('((').where((s) => s.trim().isNotEmpty)) {
        final parts = ps.split('^');
        final row = _ProductRow();
        row.nameCtrl.text     = parts.isNotEmpty ? parts[0] : '';
        row.qtyCtrl.text      = parts.length > 1 ? parts[1] : '';
        row.unitCtrl.text     = parts.length > 2 ? parts[2] : '';
        row.rateCtrl.text     = parts.length > 3 ? parts[3] : '';
        final discStr         = parts.length > 4 ? parts[4] : '0';
        row.descCtrl.text     = parts.length > 6 ? parts[6] : '';
        if (discStr.endsWith('%')) {
          row.discType          = 'PER';
          row.discountCtrl.text = discStr.replaceAll('%', '');
        } else {
          row.discType          = 'PAMT';
          row.discountCtrl.text = discStr;
        }
        void listener() => _recalculate();
        row.qtyCtrl.addListener(listener);
        row.rateCtrl.addListener(listener);
        row.discountCtrl.addListener(listener);
        _products.add(row);
      }
    }
    if (_products.isEmpty) _addProductRow();

    setState(() {
      _editSno = rec.sno; _quotationNo = rec.qtnNo;
      _customerName = rec.custName; _customerSno = rec.sno11; _customerPh1 = rec.ph1;
      _selectedState = rec.state.isNotEmpty ? rec.state : null;
      _gstType = gstType; _discountType = 'PAMT'; _showHistory = false;
    });
    _dateCtrl.text   = rec.date;
    _expiryCtrl.text = rec.expiryDate;
    _renameCtrl.text = rec.renamedCust;
    _gstPctCtrl.text = gstPct;
    _discountCtrl.text = rec.overallDiscount > 0 ? rec.overallDiscount.toStringAsFixed(2) : '';
    _recalculate();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AppMainScaffold(
      title: 'Quotation',
      drawer: AppDrawer(currentRoute: 'Quotation', companyName: _companyName),
      body: Column(children: [
        _buildTabBar(),
        Expanded(child: _showHistory ? _buildHistoryTab() : _buildCreateForm()),
      ]),
    );
  }

  // ── tab bar ───────────────────────────────────────────────────────────────────

  Widget _buildTabBar() => Container(
    margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    height: 44,
    decoration: BoxDecoration(
      color: const Color(0xFFF0F2F8),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      _tabPill('Create', Icons.edit_note_rounded, !_showHistory, () {
        if (_showHistory) setState(() => _showHistory = false);
      }),
      _tabPill('History', Icons.history_rounded, _showHistory, () async {
        setState(() { _showHistory = true; _historyLoading = true; });
        final list = await _fetchHistory();
        if (mounted) setState(() { _history = list; _historyLoading = false; });
      }),
    ]),
  );

  Widget _tabPill(String label, IconData icon, bool active, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: active ? _blue : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              boxShadow: active
                  ? [BoxShadow(color: _blue.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                  : [],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: active ? Colors.white : Colors.black45),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.black45,
              )),
            ]),
          ),
        ),
      );

  // ── create form ───────────────────────────────────────────────────────────────

  Widget _buildCreateForm() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildInfoCard(),
      const SizedBox(height: 14),
      _buildProductsSection(),
      const SizedBox(height: 14),
      _buildSummaryCard(),
      const SizedBox(height: 20),
      _buildActionButtons(),
    ]),
  );

  // ── info card ─────────────────────────────────────────────────────────────────

  Widget _buildInfoCard() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header row: Quotation badge + edit indicator
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _blueSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.receipt_long_rounded, size: 14, color: _blue),
            const SizedBox(width: 5),
            Text('Quotation #$_quotationNo',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _blue)),
          ]),
        ),
        const Spacer(),
        if (_editSno != '0')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Text('Editing', style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
          ),
      ]),

      const SizedBox(height: 14),

      // From Firm
      _fieldLabel('From Firm'),
      const SizedBox(height: 4),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE1EA)),
        ),
        child: Text(
          _companyName.isEmpty ? '--' : _companyName,
          style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
        ),
      ),

      const SizedBox(height: 12),

      // Date + Expiry Date
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _fieldLabel('Date'),
          const SizedBox(height: 4),
          _datePicker(_dateCtrl, onPick: (s) => _setExpiryDate(s)),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _fieldLabel('Expiry Date'),
          const SizedBox(height: 4),
          _datePicker(_expiryCtrl),
        ])),
      ]),

      const SizedBox(height: 12),
      _sectionDivider('Customer'),
      const SizedBox(height: 10),

      // Customer selection
      _customerField(),

      const SizedBox(height: 12),

      // Rename
      _fieldLabel('Rename in Quotation (Optional)'),
      const SizedBox(height: 4),
      TextField(controller: _renameCtrl, decoration: _dec(hint: 'Display name on quotation')),

      const SizedBox(height: 12),
      _sectionDivider('Supply & Tax'),
      const SizedBox(height: 10),

      // Place of Supply
      _fieldLabel('Place of Supply'),
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        // ignore: deprecated_member_use
        value: _states.contains(_selectedState) ? _selectedState : null,
        decoration: _dec(hint: 'Select state'),
        isExpanded: true,
        items: _states.map((s) => DropdownMenuItem(
          value: s,
          child: Text(s, style: const TextStyle(fontSize: 13)),
        )).toList(),
        onChanged: (v) => setState(() => _selectedState = v),
      ),

      const SizedBox(height: 12),

      // GST type
      _fieldLabel('GST Type'),
      const SizedBox(height: 6),
      _gstSegmentedControl(),
      if (_gstType == 'Gst') ...[
        const SizedBox(height: 10),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _gstPctCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec(hint: 'GST percentage'),
            onChanged: (_) => _recalculate(),
          ),
        ),
      ],
    ]),
  );

  Widget _gstSegmentedControl() {
    final options = [
      ('Incl. GST', 'IncGst'),
      ('Excl. GST', 'ExcGst'),
      ('+ GST', 'Gst'),
    ];
    return Row(children: options.map((opt) {
      final active = _gstType == opt.$2;
      return Expanded(child: GestureDetector(
        onTap: () => setState(() { _gstType = opt.$2; _recalculate(); }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.only(right: opt.$2 == 'Gst' ? 0 : 6),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? _blue : const Color(0xFFF0F2F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(opt.$1,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.black54,
            ),
          ),
        ),
      ));
    }).toList());
  }

  // ── customer field ────────────────────────────────────────────────────────────

  Widget _customerField() {
    if (_customerName.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _blueSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _blue.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_customerName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                overflow: TextOverflow.ellipsis),
            if (_customerPh1.isNotEmpty)
              Text(_customerPh1, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ])),
          GestureDetector(
            onTap: _showCustomerDialog,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _blue.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.edit_outlined, size: 14, color: _blue),
            ),
          ),
        ]),
      );
    }

    return Row(children: [
      Expanded(
        child: _outlineBtn(
          icon: Icons.person_add_outlined,
          label: 'Add New Customer',
          onTap: _showAddCustomerDialog,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _outlineBtn(
          icon: Icons.search_rounded,
          label: 'Search Customer',
          onTap: _showCustomerDialog,
          filled: true,
        ),
      ),
    ]);
  }

  Widget _outlineBtn({required IconData icon, required String label, required VoidCallback onTap, bool filled = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: filled ? _blue : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: filled ? _blue : const Color(0xFFDDE1EA)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: filled ? Colors.white : _blue),
            const SizedBox(height: 3),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: filled ? Colors.white : _blue)),
          ]),
        ),
      );

  // ── products section ──────────────────────────────────────────────────────────

  Widget _buildProductsSection() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text('Products', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      GestureDetector(
        onTap: _addProductRow,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 15, color: Colors.white),
            SizedBox(width: 4),
            Text('Add Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
          ]),
        ),
      ),
    ]),
    const SizedBox(height: 10),
    ..._products.asMap().entries.map((e) => _buildProductCard(e.key, e.value)),
  ]);

  Widget _buildProductCard(int idx, _ProductRow p) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE4E8F0)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      // Card header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
            child: Center(child: Text('${idx + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 8),
          const Text('Product', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (_products.length > 1)
            GestureDetector(
              onTap: () => _removeProductRow(idx),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red.shade600),
              ),
            ),
        ]),
      ),
      // Card body
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Product name
          _fieldLabel('Product Name'),
          const SizedBox(height: 4),
          _productAutocomplete(p),

          const SizedBox(height: 10),

          // Qty | Unit
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fieldLabel('Qty'),
              const SizedBox(height: 4),
              TextField(
                controller: p.qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: _dec(),
              ),
            ])),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fieldLabel('Unit'),
              const SizedBox(height: 4),
              _unitAutocomplete(p),
            ])),
          ]),

          const SizedBox(height: 10),

          // Rate | Discount
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fieldLabel('Rate (₹)'),
              const SizedBox(height: 4),
              TextField(
                controller: p.rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: _dec(),
              ),
            ])),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fieldLabel('Discount'),
              const SizedBox(height: 4),
              TextField(
                controller: p.discountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: _dec(),
              ),
              const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 4, children: [
                _discChip('Amt', 'PAMT', p),
                _discChip('Pct %', 'PER', p),
              ]),
            ])),
          ]),

          const SizedBox(height: 10),

          // Description
          _fieldLabel('Description (Optional)'),
          const SizedBox(height: 4),
          TextField(
            controller: p.descCtrl,
            decoration: _dec(hint: 'Brief product description...'),
          ),
        ]),
      ),
    ]),
  );

  Widget _discChip(String label, String val, _ProductRow p) {
    final active = p.discType == val;
    return GestureDetector(
      onTap: () => setState(() { p.discType = val; _recalculate(); }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? _blue : const Color(0xFFF0F2F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 12, height: 12, margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: active ? Colors.white : Colors.grey, width: 1.5),
              color: active ? Colors.white : Colors.transparent,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.black54)),
        ]),
      ),
    );
  }

  // ── summary card ──────────────────────────────────────────────────────────────

  Widget _buildSummaryCard() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionDivider('Summary'),
      const SizedBox(height: 12),

      // Discount on total row
      Row(children: [
        const Text('Discount on Total',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54)),
        const Spacer(),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _discountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            decoration: _dec(),
            onChanged: (_) => _recalculate(),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        _totalDiscChip('Amount', 'PAMT'),
        const SizedBox(width: 8),
        _totalDiscChip('Percent %', 'PER'),
      ]),

      const SizedBox(height: 14),
      Divider(color: Colors.grey.shade200),
      const SizedBox(height: 10),

      // Totals
      _summaryRow('Subtotal', '₹${_netTotal.toStringAsFixed(2)}', small: true),
      if (_calcOverallDiscAmt() > 0) ...[
        const SizedBox(height: 4),
        _summaryRow('Discount', '– ₹${_calcOverallDiscAmt().toStringAsFixed(2)}',
            small: true, valueColor: Colors.red.shade600),
      ],
      const SizedBox(height: 8),
      Container(height: 1, color: Colors.grey.shade200),
      const SizedBox(height: 8),
      _summaryRow('Pre-tax Total', '₹${_preTaxTotal.toStringAsFixed(2)}', bold: true),
      if (_gstType == 'Gst') ...[
        const SizedBox(height: 4),
        _summaryRow(
          'GST (${_gstPctCtrl.text.isEmpty ? '0' : _gstPctCtrl.text}%)',
          '+ ₹${(_calcAllTotal() - _preTaxTotal).toStringAsFixed(2)}',
          small: true, valueColor: Colors.green.shade700,
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: Colors.grey.shade200),
        const SizedBox(height: 8),
        _summaryRow('Net Total', '₹${_calcAllTotal().toStringAsFixed(2)}', bold: true, large: true),
      ],
    ]),
  );

  Widget _summaryRow(String label, String value, {bool bold = false, bool large = false, bool small = false, Color? valueColor}) =>
      Row(children: [
        Text(label, style: TextStyle(
          fontSize: large ? 15 : (small ? 12 : 13),
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: Colors.black54,
        )),
        const Spacer(),
        Text(value, style: TextStyle(
          fontSize: large ? 16 : (small ? 12 : 13),
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: valueColor ?? (bold ? Colors.black87 : Colors.black54),
        )),
      ]);

  Widget _totalDiscChip(String label, String val) {
    final active = _discountType == val;
    return GestureDetector(
      onTap: () => setState(() { _discountType = val; _recalculate(); }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? _blue : const Color(0xFFF0F2F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 12, height: 12, margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: active ? Colors.white : Colors.grey, width: 1.5),
              color: active ? Colors.white : Colors.transparent,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: active ? Colors.white : Colors.black54)),
        ]),
      ),
    );
  }

  // ── action buttons ────────────────────────────────────────────────────────────

  Widget _buildActionButtons() => Column(children: [
    SizedBox(
      width: double.infinity,
      height: 48,
      child: _isSaving
          ? Container(
              decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)),
              child: const Center(child: SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
          : ElevatedButton.icon(
              onPressed: _handleSave,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(_editSno != '0' ? 'Update Quotation' : 'Save Quotation',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
    ),
    const SizedBox(height: 10),
    SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: _isSaving ? null : _handlePreview,
        icon: const Icon(Icons.visibility_outlined, size: 16),
        label: const Text('Preview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _blue),
          foregroundColor: _blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
  ]);

  Future<void> _handlePreview() async {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.orange.shade700));
      return;
    }
    await _openPdfPreview(await _buildPdfData());
  }

  Future<void> _handleSave() async {
    try {
      final err = _validate();
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.orange.shade700));
        return;
      }
      final pdfData = await _buildPdfData();
      setState(() => _isSaving = true);
      final ok = await _saveQuotation();
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (ok) {
        final msg = _quoteHistory.toLowerCase() == 'true'
            ? 'Quotation saved successfully!'
            : 'Quotation ready!';
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 52),
                const SizedBox(height: 12),
                Text(msg,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0257E6),
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        await _openPdfPreview(pdfData);
        if (mounted) _resetForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_saveError.isNotEmpty ? _saveError : 'Failed to save. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8)));
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10)));
      }
      debugPrint('_handleSave error: $e\n$st');
    }
  }

  // ── pdf data ──────────────────────────────────────────────────────────────────

  Future<Uint8List?> _fetchAsBytes(String url) async {
    if (url.isEmpty) return null;
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return r.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future<QuotationPdfData> _buildPdfData() async {
    final effectiveLogo = _firmLogoUrl.isNotEmpty ? _firmLogoUrl : _logoUrl;
    final logoBytes = await _fetchAsBytes(effectiveLogo);
    final signBytes = _firmSignUrl.isNotEmpty ? await _fetchAsBytes(_firmSignUrl) : null;

    final custNm = _renameCtrl.text.trim().isNotEmpty ? _renameCtrl.text.trim() : _customerName;
    final displayCompany = _firmPrintedName.isNotEmpty ? _firmPrintedName : _companyName;

    final rows = <QuotationRowData>[];
    for (final p in _products) {
      final disc = double.tryParse(p.discountCtrl.text) ?? 0;
      final rate = double.tryParse(p.rateCtrl.text) ?? 0;
      final qty  = double.tryParse(p.qtyCtrl.text) ?? 0;
      final String discStr;
      final double amount;
      if (p.discType == 'PER') {
        discStr = '${disc.toStringAsFixed(2)}%';
        amount  = (rate - rate * disc / 100) * qty;
      } else {
        discStr = disc.toStringAsFixed(2);
        amount  = (rate - disc) * qty;
      }
      rows.add(QuotationRowData(
        name:        p.nameCtrl.text.trim(),
        description: p.descCtrl.text.trim(),
        qty:         qty,
        unit:        p.unitCtrl.text.trim(),
        rate:        rate,
        discount:    discStr,
        amount:      amount,
      ));
    }

    return QuotationPdfData(
      quotationNo:     _quotationNo,
      date:            _dateCtrl.text,
      expiryDate:      _expiryCtrl.text,
      customerName:    custNm,
      placeOfSupply:   _selectedState ?? '',
      customerPhone:   _customerPh1,
      companyName:     displayCompany,
      logoBytes:       logoBytes,
      signBytes:       signBytes,
      headerHtml:      _headerHtml,
      termsHtml:       _termsHtml,
      bankHtml:        _bankHtml,
      showQuotationNo: _quoteHistory.toLowerCase() == 'true',
      rows:            rows,
      subTotal:        _preTaxTotal,
      gstFigure:       _buildGstFigure(),
      netTotal:        _netTotal,
      overallDiscAmt:  _calcOverallDiscAmt(),
      totalAmt:        _calcAllTotal(),
    );
  }

  Future<void> _openPdfPreview(QuotationPdfData data) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationPreviewScreen(data: data),
      ),
    );
  }


  // ── history tab ───────────────────────────────────────────────────────────────

  Widget _buildHistoryTab() {
    if (_historyLoading) return const Center(child: CircularProgressIndicator());
    if (_history.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('No quotations yet', style: TextStyle(fontSize: 15, color: Colors.grey)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _buildHistoryCard(_history[i]),
    );
  }

  Widget _buildHistoryCard(_HistoryRecord rec) {
    final displayName = rec.renamedCust.isNotEmpty ? rec.renamedCust : rec.custName;
    final gstLabel = rec.gstFigure == 'IncGst' ? 'Incl. GST'
        : rec.gstFigure == 'ExcGst' ? 'Excl. GST'
        : rec.gstFigure.contains('^') ? '+ GST' : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: _blueSoft, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.description_outlined, color: _blue, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(displayName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
              Text('No. ${rec.qtnNo}  ·  ${rec.date}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${rec.totalAmt.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _blue)),
              if (gstLabel.isNotEmpty)
                Text(gstLabel, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ]),
        ),
        // Details
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Column(children: [
            if (rec.state.isNotEmpty || rec.expiryDate.isNotEmpty)
              Row(children: [
                if (rec.state.isNotEmpty) ...[
                  const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 3),
                  Text(rec.state, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
                if (rec.state.isNotEmpty && rec.expiryDate.isNotEmpty)
                  const Text('  ·  ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                if (rec.expiryDate.isNotEmpty) ...[
                  const Icon(Icons.event_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 3),
                  Text('Expires ${rec.expiryDate}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _historyBtn(
                icon: Icons.edit_outlined,
                label: 'Edit',
                color: _blue,
                onTap: () => _loadForEdit(rec),
              )),
              const SizedBox(width: 8),
              Expanded(child: _historyBtn(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: Colors.red.shade600,
                onTap: () => _confirmDelete(rec.sno),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _historyBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(8),
            color: color.withValues(alpha: 0.05),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      );

  Future<void> _confirmDelete(String sno) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Quotation'),
        content: const Text('This will permanently remove the quotation. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _deleteQuotation(sno);
      final list = await _fetchHistory();
      if (mounted) setState(() => _history = list);
    }
  }

  // ── shared helpers ────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE4E8F0)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54));

  Widget _sectionDivider(String title) => Row(children: [
    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _blue)),
    const SizedBox(width: 8),
    Expanded(child: Container(height: 1, color: Color(0xFFDDE1EA))),
  ]);

  Widget _datePicker(TextEditingController ctrl, {void Function(String)? onPick}) =>
      TextField(
        controller: ctrl,
        readOnly: true,
        decoration: _dec(suffix: const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey)),
        onTap: () async {
          final d = await _pickDate(ctrl.text);
          if (d != null) {
            final s = _fmtDate(d);
            ctrl.text = s;
            onPick?.call(s);
          }
        },
      );

  // ── autocomplete fields ───────────────────────────────────────────────────────

  Widget _productAutocomplete(_ProductRow p) => RawAutocomplete<String>(
    textEditingController: p.nameCtrl,
    focusNode: p.nameFocus,
    optionsBuilder: (tv) async {
      if (tv.text.isEmpty) return const [];
      return _fetchSuggestions(tv.text, 'PROD');
    },
    displayStringForOption: (o) => o,
    fieldViewBuilder: (ctx, ctrl, fn, onEditingComplete) => TextField(
      controller: ctrl, focusNode: fn, onEditingComplete: onEditingComplete,
      decoration: _dec(hint: 'Type to search products...'),
    ),
    optionsViewBuilder: (ctx, onSelected, opts) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180, maxWidth: 260),
          child: ListView(
            padding: EdgeInsets.zero, shrinkWrap: true,
            children: opts.map((o) => ListTile(
              dense: true,
              title: Text(o, style: const TextStyle(fontSize: 13)),
              onTap: () => onSelected(o),
            )).toList(),
          ),
        ),
      ),
    ),
  );

  Widget _unitAutocomplete(_ProductRow p) => RawAutocomplete<String>(
    textEditingController: p.unitCtrl,
    focusNode: p.unitFocus,
    optionsBuilder: (tv) async {
      if (tv.text.isEmpty) return const [];
      return _fetchSuggestions(tv.text, 'UNIT');
    },
    displayStringForOption: (o) => o,
    fieldViewBuilder: (ctx, ctrl, fn, onEditingComplete) => TextField(
      controller: ctrl, focusNode: fn, onEditingComplete: onEditingComplete,
      decoration: _dec(hint: 'e.g. Pcs'),
    ),
    optionsViewBuilder: (ctx, onSelected, opts) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160, maxWidth: 180),
          child: ListView(
            padding: EdgeInsets.zero, shrinkWrap: true,
            children: opts.map((o) => ListTile(
              dense: true,
              title: Text(o, style: const TextStyle(fontSize: 13)),
              onTap: () => onSelected(o),
            )).toList(),
          ),
        ),
      ),
    ),
  );
}
