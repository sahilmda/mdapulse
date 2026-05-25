import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:mda_crm/shared/widgets/app_drawer.dart';
import 'package:mda_crm/shared/widgets/app_main_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

// Section metadata: label + color
const _sectionLabels = {1: 'Overdue', 2: 'Due Today', 3: 'Update Today - Pre Sale', 4: 'Update Today - Post Sale', 5: 'Update Today - Rejection'};
const _pcSectionLabels = {1: 'Overdue', 2: 'Due Today', 3: 'Due Later'};
const _sectionColors = {
  1: Color(0xFFD32F2F),
  2: Color(0xFFF57C00),
  3: Color(0xFF1565C0),
  4: Color(0xFF2E7D32),
  5: Color(0xFF6A1B9A),
};

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedMainTab = 0;
  int _selectedSubTab = 0;
  String _periodType = 'Month';
  String _companyName = '';

  // Employee performance state
  bool _isLoading = false;
  String _errorMessage = '';
  List<_EmpRow> _rows = [];
  final Set<String> _expandedEmployees = {};
  List<Map<String, String>> _activities = [];
  List<Map<String, String>> _products = [];
  String _selectedActivity = '0';
  String _selectedProduct = '0';

  // Daily Report state
  List<Map<String, String>> _executives = [];
  String _selectedExCode = '0';
  List<_DailyRow> _dailyRows = [];
  bool _isDailyLoading = false;
  String _dailyError = '';
  final Set<String> _expandedDailySections = {};

  // Custom Report state
  List<Map<String, String>> _sources = [];
  final TextEditingController _crFromDateCtrl = TextEditingController();
  final TextEditingController _crToDateCtrl = TextEditingController();
  String _crExCode = '0';
  String _crActivity = '0';
  String _crSource = '0';
  String _crGroupBy = 'Product';
  String _crType = 'All';
  bool _isCrLoading = false;
  String _crError = '';
  bool _crHasData = false;
  List<_SummaryRow> _crSummaryRows = [];
  List<_CallRow> _crOngoingRows = [];
  List<_CallRow> _crSaleRows = [];
  List<_CallRow> _crRejectRows = [];
  List<_BarData> _crBarData = [];
  int _crPieOngoing = 0;
  int _crPieSale = 0;
  int _crPieReject = 0;
  // show-status modal data: list of {product, status, count}
  List<Map<String, String>> _crStatusData = [];

  // Pending Customers state
  String _pcExCode = '0';
  bool _isPcLoading = false;
  bool _pcHasFetched = false;
  String _pcError = '';
  List<_DailyRow> _pcRows = [];
  // Only these 3 are toggleable; Due Date / Status / Remark are always shown
  Set<String> _pcVisibleCols = {'startDate', 'activity', 'product'};
  final Map<String, String> _pcColLabels = {
    'startDate': 'Start Date',
    'activity':  'Activity',
    'product':   'Product',
  };

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
    _crFromDateCtrl.text = today;
    _crToDateCtrl.text = today;
    _loadInitial();
  }

  @override
  void dispose() {
    _crFromDateCtrl.dispose();
    _crToDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _companyName = prefs.getString('O_Name') ?? '');
    await Future.wait([_fetchDropdowns(), _fetchReport(), _fetchSources()]);
  }

  Future<void> _fetchDropdowns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? '';
      final db = prefs.getString('D_Database') ?? '';
      final sno = int.tryParse(prefs.getString('sno') ?? '1') ?? 1;

      final results = await Future.wait([
        http.post(
          Uri.parse('https://webservices.mdapulse.com/Customer.aspx/Fill_DropDown'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'ClientId': clientId, 'chk': 'TypeOfCall', 'sno': sno, 'DB': db}),
        ),
        http.post(
          Uri.parse('https://webservices.mdapulse.com/Customer.aspx/Fill_DropDown'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'ClientId': clientId, 'chk': 'Product', 'sno': sno, 'DB': db}),
        ),
        http.post(
          Uri.parse('https://webservices.mdapulse.com/Customer.aspx/Fill_DropDown'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'ClientId': clientId, 'chk': 'Emp', 'sno': sno, 'DB': db}),
        ),
      ]);

      List<Map<String, String>> parseDropdown(http.Response res) {
        final list = <Map<String, String>>[];
        if (res.statusCode != 200) return list;
        final raw = (jsonDecode(res.body)['d'] ?? '').toString();
        for (final r in raw.split('#')) {
          final p = r.split('~');
          if (p.length >= 2 && p[0].isNotEmpty) list.add({'val': p[0], 'text': p[1]});
        }
        return list;
      }

      if (mounted) {
        setState(() {
          _activities = parseDropdown(results[0]);
          _products = parseDropdown(results[1]);
          _executives = parseDropdown(results[2]);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchReport() async {
    if (_selectedMainTab != 0) return;
    setState(() { _isLoading = true; _errorMessage = ''; _rows = []; _expandedEmployees.clear(); });
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? '';
      final db = prefs.getString('D_Database') ?? '';
      final sno = int.tryParse(prefs.getString('sno') ?? '1') ?? 1;
      final enablePrePost = int.tryParse(prefs.getString('Enable_PrePostSale') ?? '0') ?? 0;

      final response = await http.post(
        Uri.parse('https://mdapulse.com/Reports.aspx/fillEmpPerformReport'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'X-Requested-With': 'XMLHttpRequest',
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Referer': 'https://mdapulse.com/Reports.aspx',
        },
        body: jsonEncode({
          'ClientId': clientId, 'sno': sno, 'DB': db, 'EnablePrePost': enablePrePost,
          'type': _periodType, 'Product': _selectedProduct,
          'Activity': int.tryParse(_selectedActivity) ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final raw = (jsonDecode(response.body)['d'] ?? '').toString().trim();
        if (raw.isEmpty || raw == 'Something went wrong !') {
          if (mounted) setState(() { _isLoading = false; _errorMessage = raw.isEmpty ? 'No data available.' : raw; });
          return;
        }
        final parsed = <_EmpRow>[];
        for (final chunk in raw.split('#')) {
          final p = chunk.split('^');
          if (p.length >= 7) {
            // enablePrePost=1: period^emp^oldOngoing^newCalls^PreSale^PostSale^Reject
            parsed.add(_EmpRow(period: p[0], employee: p[1], oldOngoing: p[2], newCalls: p[3], sale: p[5], reject: p[6]));
          } else if (p.length >= 5) {
            // enablePrePost=0: period^emp^oldOngoing^newCalls^Sale^Reject
            parsed.add(_EmpRow(period: p[0], employee: p[1], oldOngoing: p[2], newCalls: p[3], sale: p[4], reject: p.length > 5 ? p[5] : '0'));
          }
        }
        if (mounted) setState(() { _isLoading = false; _rows = parsed; });
      } else {
        if (mounted) setState(() { _isLoading = false; _errorMessage = 'Server error (${response.statusCode}).'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = 'Connection error: $e'; });
    }
  }

  Future<void> _fetchDailyReport() async {
    if (_selectedMainTab != 1) return;
    setState(() { _isDailyLoading = true; _dailyError = ''; _dailyRows = []; _expandedDailySections.clear(); });
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? '';
      final db = prefs.getString('D_Database') ?? '';
      final sno = prefs.getString('sno') ?? '1';
      final snoInt = int.tryParse(sno) ?? 1;

      final now = DateTime.now();
      final today = '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

      // 3 parallel calls:
      // [0] Overdue   → Calling.aspx/fillList Type=OD
      // [1] Due Today → Calling.aspx/fillList Type=DU
      // [2] Update Today → Reports.aspx/fillReport with today's date range
      const callingHeaders = {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': 'https://mdapulse.com/Calling.aspx',
      };
      final results = await Future.wait([
        http.post(
          Uri.parse('https://mdapulse.com/Calling.aspx/fillList'),
          headers: callingHeaders,
          body: jsonEncode({'ClientId': clientId, 'Type': 'OD', 'sno': sno, 'DB': db, 'showAllC': 1, 'WorkViewType': 'Team'}),
        ),
        http.post(
          Uri.parse('https://mdapulse.com/Calling.aspx/fillList'),
          headers: callingHeaders,
          body: jsonEncode({'ClientId': clientId, 'Type': 'DU', 'sno': sno, 'DB': db, 'showAllC': 1, 'WorkViewType': 'Team'}),
        ),
        http.post(
          Uri.parse('https://mdapulse.com/Reports.aspx/fillReport'),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'X-Requested-With': 'XMLHttpRequest',
            'Referer': 'https://mdapulse.com/Reports.aspx',
          },
          body: jsonEncode({
            'ClientId': clientId,
            'sno': snoInt,
            'rdata': '$today^$today^$_selectedExCode^0^All^0',
            'DB': db,
          }),
        ),
      ]);

      final parsed = <_DailyRow>[];

      // Name of the selected executive for client-side filtering (lowercased for case-insensitive match)
      final selExecName = _selectedExCode != '0'
          ? (_executives.firstWhere((e) => e['val'] == _selectedExCode, orElse: () => {})['text']?.trim().toLowerCase() ?? '')
          : '';

      // fillList format (confirmed from Calling.aspx.cs):
      // [0]sno [1]CustID [2]u_id [3]lastRemarkLine [4]CustName [5]UName
      // [6]NdateOnly [7]Status [8]Stage [9]ActivityCode [10]StateName(activity)
      // ... [18]Product [19]Call_CL_PN
      void parseFillList(http.Response res, int section) {
        if (res.statusCode != 200) return;
        final raw = (jsonDecode(res.body)['d'] ?? '').toString().trim();
        if (!raw.contains('^')) return;
        for (final chunk in raw.split('#')) {
          final p = chunk.split('^');
          if (p.length < 11) continue;
          final execName = p[5].trim();
          if (execName.toLowerCase() == 'whatsapp') continue;
          if (selExecName.isNotEmpty && execName.toLowerCase() != selExecName) continue;
          // p[3] is formatted "dd-mm-yyyy --- actual remark text"
          final remarkRaw = p[3];
          String startDate = '';
          String lastRemark = remarkRaw;
          final sepIdx = remarkRaw.indexOf(' --- ');
          if (sepIdx > 0) {
            final datePart = remarkRaw.substring(0, sepIdx).trim();
            if (datePart.length == 10 && datePart[2] == '-' && datePart[5] == '-') {
              startDate = datePart;
              lastRemark = remarkRaw.substring(sepIdx + 5).trim();
            }
          }
          parsed.add(_DailyRow(
            execName: execName,
            section: section,
            custName: p[4],
            startDate: startDate,
            dueDate: p[6],
            status: p[7],
            product: p.length > 18 ? p[18] : '',
            activity: p[10],
            lastRemark: lastRemark,
          ));
        }
      }

      parseFillList(results[0], 1); // Overdue
      parseFillList(results[1], 2); // Due Today

      // fillReport format (confirmed from Reports.aspx.cs):
      // [0]sno [1]CName [2]Remark1 [3]CustName [4]ExecName [5]Status
      // [6]Stage [7]TypeOfCallCode [8]Activity(StatName) [9]Product
      // [10]Call_cl_pn [11]saleRej [12]NdateOnly [13]CurrdateOnly
      if (results[2].statusCode == 200) {
        final raw = (jsonDecode(results[2].body)['d'] ?? '').toString().trim();
        if (raw.contains('^')) {
          for (final chunk in raw.split('#')) {
            final p = chunk.split('^');
            if (p.length < 11) continue;
            final reportExecName = p[4].trim();
            if (reportExecName.toLowerCase() == 'whatsapp') continue;
            if (selExecName.isNotEmpty && reportExecName.toLowerCase() != selExecName) continue;
            final callPn = p[10];
            final saleRej = p.length > 11 ? p[11] : '';
            final int section;
            if (callPn == 'Pending') {
              section = 3; // Update Today - Pre Sale
            } else if (callPn == 'Close' && saleRej == 'Sale') {
              section = 4; // Update Today - Post Sale
            } else if (callPn == 'Close' && (saleRej == 'Reject' || saleRej == 'Rejection')) {
              section = 5; // Update Today - Rejection
            } else {
              continue;
            }
            parsed.add(_DailyRow(
              execName: reportExecName,
              section: section,
              custName: p[3],
              startDate: p.length > 13 ? p[13] : '',
              dueDate: p.length > 12 ? p[12] : '',
              status: p[5],
              product: p.length > 9 ? p[9] : '',
              activity: p.length > 8 ? p[8] : '',
              lastRemark: p[2],
            ));
          }
        }
      }

      if (mounted) setState(() { _isDailyLoading = false; _dailyRows = parsed; });
    } catch (e) {
      if (mounted) setState(() { _isDailyLoading = false; _dailyError = 'Error: $e'; });
    }
  }

  Future<void> _fetchSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? '';
      final db = prefs.getString('D_Database') ?? '';
      final res = await http.post(
        Uri.parse('https://mdapulse.com/Reports.aspx/fillSource'),
        headers: {'Content-Type': 'application/json; charset=utf-8', 'X-Requested-With': 'XMLHttpRequest', 'Referer': 'https://mdapulse.com/Reports.aspx'},
        body: jsonEncode({'ClientId': clientId, 'DB': db}),
      );
      if (res.statusCode == 200) {
        final raw = (jsonDecode(res.body)['d'] ?? '').toString();
        final list = <Map<String, String>>[];
        for (final r in raw.split('#')) {
          final p = r.split('~');
          if (p.length >= 2 && p[1].isNotEmpty) list.add({'val': p[1], 'text': p[1]});
        }
        if (mounted) setState(() => _sources = list);
      }
    } catch (_) {}
  }

  Future<void> _fetchPendingCustomers() async {
    if (_selectedMainTab != 3) return;
    setState(() { _isPcLoading = true; _pcHasFetched = false; _pcError = ''; _pcRows = []; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? '';
      final db = prefs.getString('D_Database') ?? '';
      final sno = prefs.getString('sno') ?? '1';

      final selExecName = _pcExCode != '0'
          ? (_executives.firstWhere((e) => e['val'] == _pcExCode, orElse: () => {})['text']?.trim().toLowerCase() ?? '')
          : '';

      final showAllC = int.tryParse(prefs.getString('showAllCustomer') ?? '1') ?? 1;
      const callingHeaders = {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': 'https://mdapulse.com/Calling.aspx',
      };

      final results = await Future.wait([
        http.post(
          Uri.parse('https://mdapulse.com/Calling.aspx/fillList'),
          headers: callingHeaders,
          body: jsonEncode({'ClientId': clientId, 'Type': 'OD', 'sno': sno, 'DB': db, 'showAllC': showAllC, 'WorkViewType': 'Team'}),
        ),
        http.post(
          Uri.parse('https://mdapulse.com/Calling.aspx/fillList'),
          headers: callingHeaders,
          body: jsonEncode({'ClientId': clientId, 'Type': 'DU', 'sno': sno, 'DB': db, 'showAllC': showAllC, 'WorkViewType': 'Team'}),
        ),
        http.post(
          Uri.parse('https://mdapulse.com/Calling.aspx/fillList'),
          headers: callingHeaders,
          body: jsonEncode({'ClientId': clientId, 'Type': 'DL', 'sno': sno, 'DB': db, 'showAllC': showAllC, 'WorkViewType': 'Team'}),
        ),
      ]);

      final parsed = <_DailyRow>[];
      void parseFillList(http.Response res, int section) {
        if (res.statusCode != 200) return;
        final raw = (jsonDecode(res.body)['d'] ?? '').toString().trim();
        if (!raw.contains('^')) return;
        for (final chunk in raw.split('#')) {
          final p = chunk.split('^');
          if (p.length < 11) continue;
          final execName = p[5].trim();
          if (execName.toLowerCase() == 'whatsapp') continue;
          if (selExecName.isNotEmpty && execName.toLowerCase() != selExecName) continue;
          // p[3] is formatted "dd-mm-yyyy --- actual remark text"
          final remarkRaw = p[3];
          String startDate = '';
          String lastRemark = remarkRaw;
          final sepIdx = remarkRaw.indexOf(' --- ');
          if (sepIdx > 0) {
            final datePart = remarkRaw.substring(0, sepIdx).trim();
            if (datePart.length == 10 && datePart[2] == '-' && datePart[5] == '-') {
              startDate = datePart;
              lastRemark = remarkRaw.substring(sepIdx + 5).trim();
            }
          }
          parsed.add(_DailyRow(
            execName: execName,
            section: section,
            custName: p[4],
            startDate: startDate,
            dueDate: p[6],
            status: p[7],
            product: p.length > 18 ? p[18] : '',
            activity: p[10],
            lastRemark: lastRemark,
          ));
        }
      }
      parseFillList(results[0], 1); // Overdue
      parseFillList(results[1], 2); // Due Today
      parseFillList(results[2], 3); // Due Later

      if (mounted) setState(() { _isPcLoading = false; _pcHasFetched = true; _pcRows = parsed; });
    } catch (e) {
      if (mounted) setState(() { _isPcLoading = false; _pcHasFetched = true; _pcError = 'Error: $e'; });
    }
  }

  Future<void> _fetchCustomReport() async {
    final fromDate = _crFromDateCtrl.text.trim();
    final toDate = _crToDateCtrl.text.trim();
    if (fromDate.isEmpty || toDate.isEmpty) return;
    setState(() {
      _isCrLoading = true; _crError = ''; _crHasData = false;
      _crSummaryRows = []; _crOngoingRows = []; _crSaleRows = []; _crRejectRows = [];
      _crBarData = []; _crPieOngoing = 0; _crPieSale = 0; _crPieReject = 0; _crStatusData = [];
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? '';
      final db = prefs.getString('D_Database') ?? '';
      final sno = int.tryParse(prefs.getString('sno') ?? '1') ?? 1;

      final headers = {'Content-Type': 'application/json; charset=utf-8', 'X-Requested-With': 'XMLHttpRequest', 'Referer': 'https://mdapulse.com/Reports.aspx'};
      final rSummary  = '$fromDate^$toDate^$_crExCode^$_crActivity^$_crType^$_crGroupBy^$_crSource';
      final rChart    = '$fromDate^$toDate^$_crExCode^$_crActivity^$_crType^$_crSource';
      final rPending  = '$fromDate^$toDate^$_crExCode^$_crActivity^Pending^$_crSource';
      final rClose    = '$fromDate^$toDate^$_crExCode^$_crActivity^Close^$_crSource';

      final results = await Future.wait([
        http.post(Uri.parse('https://mdapulse.com/Reports.aspx/fillSummary'),
            headers: headers, body: jsonEncode({'ClientId': clientId, 'sno': sno, 'rdata': rSummary, 'DB': db})),
        http.post(Uri.parse('https://mdapulse.com/Reports.aspx/fillReport'),
            headers: headers, body: jsonEncode({'ClientId': clientId, 'sno': sno, 'rdata': rPending, 'DB': db})),
        http.post(Uri.parse('https://mdapulse.com/Reports.aspx/fillReport'),
            headers: headers, body: jsonEncode({'ClientId': clientId, 'sno': sno, 'rdata': rClose, 'DB': db})),
        http.post(Uri.parse('https://mdapulse.com/Reports.aspx/filBarChart'),
            headers: headers, body: jsonEncode({'ClientId': clientId, 'sno': sno, 'rdata': rChart, 'DB': db})),
        http.post(Uri.parse('https://mdapulse.com/Reports.aspx/filPieChart'),
            headers: headers, body: jsonEncode({'ClientId': clientId, 'sno': sno, 'rdata': rChart, 'DB': db})),
        http.post(Uri.parse('https://mdapulse.com/Reports.aspx/fillshowStatus'),
            headers: headers, body: jsonEncode({'ClientId': clientId, 'sno': sno, 'rdata': rSummary, 'DB': db})),
      ]);

      // Summary
      final summaryRows = <_SummaryRow>[];
      if (results[0].statusCode == 200) {
        final raw = (jsonDecode(results[0].body)['d'] ?? '').toString();
        if (raw.contains('^')) {
          for (final chunk in raw.split('#')) {
            final p = chunk.split('^');
            if (p.length >= 5) summaryRows.add(_SummaryRow(label: p[0], newCalls: p[1], ongoing: p[2], sale: p[3], reject: p[4]));
          }
        }
      }

      // Ongoing calls
      final ongoingRows = <_CallRow>[];
      if (results[1].statusCode == 200) {
        final raw = (jsonDecode(results[1].body)['d'] ?? '').toString();
        if (raw.contains('^')) {
          for (final chunk in raw.split('#')) {
            final p = chunk.split('^');
            if (p.length < 11) continue;
            ongoingRows.add(_CallRow(clientName: p[3], executive: p[4], activity: p.length > 8 ? p[8] : '', product: p.length > 9 ? p[9] : '', status: p[5], lastRemark: p[2], date: p.length > 12 ? p[12] : ''));
          }
        }
      }

      // Close calls → split into sale / reject
      final saleRows = <_CallRow>[];
      final rejectRows = <_CallRow>[];
      if (results[2].statusCode == 200) {
        final raw = (jsonDecode(results[2].body)['d'] ?? '').toString();
        if (raw.contains('^')) {
          for (final chunk in raw.split('#')) {
            final p = chunk.split('^');
            if (p.length < 11) continue;
            final saleRej = p.length > 11 ? p[11] : '';
            final row = _CallRow(clientName: p[3], executive: p[4], activity: p.length > 8 ? p[8] : '', product: p.length > 9 ? p[9] : '', status: p[5], lastRemark: p[2], date: p.length > 13 ? p[13] : '');
            if (saleRej == 'Sale') saleRows.add(row);
            else if (saleRej == 'Reject' || saleRej == 'Rejection') rejectRows.add(row);
          }
        }
      }

      // Bar chart — StatName^PendTot^CLOSE
      final barData = <_BarData>[];
      if (results[3].statusCode == 200) {
        final raw = (jsonDecode(results[3].body)['d'] ?? '').toString();
        if (raw.contains('^')) {
          for (final chunk in raw.split('#')) {
            final p = chunk.split('^');
            if (p.length >= 3 && p[0].isNotEmpty) {
              barData.add(_BarData(label: p[0], pending: int.tryParse(p[1]) ?? 0, closed: int.tryParse(p[2]) ?? 0));
            }
          }
        }
      }

      // Pie chart — Call_CL_PN^saleRej^pendingTot^CloseCount
      int pieOngoing = 0, pieSale = 0, pieReject = 0;
      if (results[4].statusCode == 200) {
        final raw = (jsonDecode(results[4].body)['d'] ?? '').toString();
        if (raw.contains('^')) {
          for (final chunk in raw.split('#')) {
            final p = chunk.split('^');
            if (p.length < 3) continue;
            pieOngoing += int.tryParse(p[2]) ?? 0;
            if (p.length > 3) {
              if (p[1] == 'Sale') pieSale += int.tryParse(p[3]) ?? 0;
              else if (p[1] == 'Reject') pieReject += int.tryParse(p[3]) ?? 0;
            }
          }
        }
      }

      // Show-status data — Product^Status^Count
      final statusData = <Map<String, String>>[];
      if (results[5].statusCode == 200) {
        final raw = (jsonDecode(results[5].body)['d'] ?? '').toString();
        if (raw.contains('^')) {
          for (final chunk in raw.split('#')) {
            final p = chunk.split('^');
            if (p.length >= 3) statusData.add({'product': p[0], 'status': p[1], 'count': p[2]});
          }
        }
      }

      summaryRows.sort((a, b) => a.label.trim().toLowerCase().compareTo(b.label.trim().toLowerCase()));
      ongoingRows.sort((a, b) => a.clientName.trim().toLowerCase().compareTo(b.clientName.trim().toLowerCase()));
      saleRows.sort((a, b) => a.clientName.trim().toLowerCase().compareTo(b.clientName.trim().toLowerCase()));
      rejectRows.sort((a, b) => a.clientName.trim().toLowerCase().compareTo(b.clientName.trim().toLowerCase()));

      if (mounted) setState(() {
        _isCrLoading = false;
        _crHasData = true;
        _crSummaryRows = summaryRows;
        _crOngoingRows = ongoingRows;
        _crSaleRows = saleRows;
        _crRejectRows = rejectRows;
        _crBarData = barData;
        _crPieOngoing = pieOngoing;
        _crPieSale = pieSale;
        _crPieReject = pieReject;
        _crStatusData = statusData;
      });
    } catch (e) {
      if (mounted) setState(() { _isCrLoading = false; _crError = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppMainScaffold(
      title: 'Reports',
      drawer: AppDrawer(currentRoute: 'Reports', companyName: _companyName),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: _buildMainTab(0, 'Employee -\nperformance', Icons.person, cs)),
              const SizedBox(width: 4),
              Expanded(child: _buildMainTab(1, 'Daily\nReport', Icons.today, cs)),
              const SizedBox(width: 4),
              Expanded(child: _buildMainTab(2, 'Custom\nReport', Icons.show_chart, cs)),
              const SizedBox(width: 4),
              Expanded(child: _buildMainTab(3, 'Pending\nCustomers', Icons.pending_actions, cs)),
            ]),
            const SizedBox(height: 12),

            if (_selectedMainTab == 0) ...[
              Row(children: [
                Expanded(child: _buildSubTab(0, 'Lead Generation', cs)),
                const SizedBox(width: 12),
                Expanded(child: _buildSubTab(1, 'Conversion Rate', cs)),
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Activity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 4),
                          _buildDropdown(_activities, _selectedActivity, (v) => setState(() => _selectedActivity = v ?? '0')),
                        ],
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Product', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 4),
                          _buildDropdown(_products, _selectedProduct, (v) => setState(() => _selectedProduct = v ?? '0')),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _fetchReport,
                      style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                      child: const Text('Show', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _buildPeriodBtn('Month', cs),
                const SizedBox(width: 8),
                _buildPeriodBtn('Quarter', cs),
              ]),
              const SizedBox(height: 10),
            ],

            if (_selectedMainTab == 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(children: [
                  const Text('Executive Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDropdown(_executives, _selectedExCode, (v) => setState(() => _selectedExCode = v ?? '0'), allLabel: '-------All-------')),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _fetchDailyReport,
                    style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                    child: const Text('Show', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
            ],

            if (_selectedMainTab == 3) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Executive Name', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  _buildDropdown(_executives, _pcExCode, (v) => setState(() => _pcExCode = v ?? '0'), allLabel: '-------All-------'),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    OutlinedButton.icon(
                      onPressed: _showChangeColumnsDialog,
                      icon: const Icon(Icons.view_column_outlined, size: 15),
                      label: const Text('Change columns', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: mdaPrimaryBlue,
                        side: const BorderSide(color: mdaPrimaryBlue),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _fetchPendingCustomers,
                      style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                      child: const Text('Show', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),
            ],

            Expanded(child: _buildContent(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(List<Map<String, String>> items, String value, ValueChanged<String?> onChanged, {String allLabel = 'Select'}) {
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(value: '0', child: Text(allLabel, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
        ...items.map((e) => DropdownMenuItem(value: e['val'], child: Text(e['text'] ?? '', style: const TextStyle(fontSize: 12)))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildPeriodBtn(String period, ColorScheme cs) {
    final isActive = _periodType == period;
    return InkWell(
      onTap: () {
        if (_periodType == period) return;
        setState(() => _periodType = period);
        _fetchReport();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? mdaPrimaryBlue : cs.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? mdaPrimaryBlue : cs.outlineVariant),
        ),
        child: Text(period, style: TextStyle(color: isActive ? Colors.white : cs.onSurface, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _buildContent(ColorScheme cs) {
    if (_selectedMainTab == 0) return _buildEmpPerformContent(cs);
    if (_selectedMainTab == 1) return _buildDailyContent(cs);
    if (_selectedMainTab == 3) return _buildPendingCustomersContent(cs);
    return _buildCustomContent(cs);
  }

  Widget _buildPendingCustomersContent(ColorScheme cs) {
    if (_isPcLoading) return const Center(child: CircularProgressIndicator());
    if (_pcError.isNotEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 48, color: cs.error),
          const SizedBox(height: 12),
          Text(_pcError, style: TextStyle(color: cs.error, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchPendingCustomers,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white),
          ),
        ]),
      ));
    }
    if (!_pcHasFetched) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.pending_actions, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text('Loading pending customers...', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
      ]));
    }

    // Group by executive; always include all 3 sections
    final byExec = <String, Map<int, List<_DailyRow>>>{};
    for (final r in _pcRows) {
      byExec.putIfAbsent(r.execName, () => {1: [], 2: [], 3: []});
      (byExec[r.execName]![r.section] ??= []).add(r);
    }
    if (byExec.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.pending_actions, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text('No pending customers found', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
      ]));
    }

    final sortedExecs = byExec.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ListView.builder(
      itemCount: sortedExecs.length,
      itemBuilder: (_, i) => _buildPcEmployeeBlock(sortedExecs[i], byExec[sortedExecs[i]]!, cs),
    );
  }

  Widget _buildPcEmployeeBlock(String execName, Map<int, List<_DailyRow>> sections, ColorScheme cs) {
    final initial = execName.isNotEmpty ? execName[0].toUpperCase() : '?';
    final total = (sections[1]?.length ?? 0) + (sections[2]?.length ?? 0) + (sections[3]?.length ?? 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [mdaPrimaryBlue, mdaPrimaryBlue.withValues(alpha: 0.85)]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          CircleAvatar(radius: 15, backgroundColor: Colors.white.withValues(alpha: 0.25),
              child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(width: 10),
          Expanded(child: Text(execName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Text('$total pending', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      _buildPcSection(1, sections[1] ?? [], cs),
      _buildPcSection(2, sections[2] ?? [], cs),
      _buildPcSection(3, sections[3] ?? [], cs),
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildPcSection(int sectionNum, List<_DailyRow> rows, ColorScheme cs) {
    final label = _pcSectionLabels[sectionNum] ?? 'Section $sectionNum';
    final color = _sectionColors[sectionNum] ?? mdaPrimaryBlue;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: EdgeInsets.zero,
          iconColor: color,
          collapsedIconColor: color,
          title: Row(children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            RichText(text: TextSpan(children: [
              TextSpan(text: '$sectionNum. ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
              TextSpan(text: label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
              TextSpan(text: ' (${rows.length} records)', style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
            ])),
          ]),
          children: [
            Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                child: Text('No records', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
              )
            else
              _buildPcDataTable(rows, color, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildPcDataTable(List<_DailyRow> rows, Color sectionColor, ColorScheme cs) {
    return Column(
      children: rows.asMap().entries.map((e) => _buildPcRowItem(e.key, e.value, sectionColor, cs)).toList(),
    );
  }

  Widget _buildPcRowItem(int index, _DailyRow row, Color sectionColor, ColorScheme cs) {
    final show = _pcVisibleCols;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: index.isOdd ? cs.surfaceContainerLowest : cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25), width: 0.5)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 22,
          child: Text('${index + 1}',
              style: TextStyle(color: sectionColor, fontWeight: FontWeight.bold, fontSize: 12),
              textAlign: TextAlign.center),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Customer name (full width, prominent)
          Text(row.custName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              overflow: TextOverflow.ellipsis, maxLines: 2),
          const SizedBox(height: 6),

          // Start Date (configurable) + Due Date (always shown) side by side
          Row(children: [
            if (show.contains('startDate')) ...[
              Expanded(child: _pcField(_pcColLabels['startDate']!, row.startDate.isEmpty ? '—' : row.startDate, cs)),
              const SizedBox(width: 12),
            ],
            Expanded(child: _pcField('Due Date', row.dueDate.isEmpty ? '—' : row.dueDate, cs, valueColor: sectionColor)),
          ]),

          // Status (always shown)
          const SizedBox(height: 4),
          _pcField('Status', row.status.isEmpty ? '—' : row.status, cs),

          // Product + Activity side by side (both configurable)
          if (show.contains('product') || show.contains('activity')) ...[
            const SizedBox(height: 4),
            Row(children: [
              if (show.contains('product'))
                Expanded(child: _pcField(_pcColLabels['product']!, row.product.isEmpty ? '—' : row.product, cs)),
              if (show.contains('product') && show.contains('activity'))
                const SizedBox(width: 12),
              if (show.contains('activity'))
                Expanded(child: _pcField(_pcColLabels['activity']!, row.activity.isEmpty ? '—' : row.activity, cs)),
            ]),
          ],

          // Last Remark (always shown, italic value)
          const SizedBox(height: 4),
          _pcField('Remark', row.lastRemark.isEmpty ? '—' : row.lastRemark, cs, italic: true, maxLines: 2),
        ])),
      ]),
    );
  }

  Widget _pcField(String label, String value, ColorScheme cs, {Color? valueColor, bool italic = false, int maxLines = 1}) {
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 11),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: valueColor ?? cs.onSurface,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _showChangeColumnsDialog() {
    // key → default display name (only the 3 configurable columns)
    const colDefs = [
      ('startDate', 'First Date'),
      ('activity',  'Activity'),
      ('product',   'Product'),
    ];

    // Pre-fill rename controllers: only show custom text if it differs from default
    final controllers = {
      for (final c in colDefs)
        c.$1: TextEditingController(
          text: _pcColLabels[c.$1] != c.$2 ? (_pcColLabels[c.$1] ?? '') : '',
        )
    };

    final localVisible = Set<String>.from(_pcVisibleCols);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          return AlertDialog(
            title: const Text('Change columns',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade300),
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 44,
                        child: Text('Show', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    const Expanded(flex: 2,
                        child: Text('Column Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    const Expanded(flex: 3,
                        child: Text('Rename', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  ]),
                ),
                // Column rows
                ...colDefs.map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(children: [
                    SizedBox(
                      width: 44,
                      child: Checkbox(
                        value: localVisible.contains(c.$1),
                        activeColor: mdaPrimaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                        onChanged: (v) => setDialog(() {
                          if (v == true) localVisible.add(c.$1); else localVisible.remove(c.$1);
                        }),
                      ),
                    ),
                    Expanded(flex: 2,
                        child: Text(c.$2, style: const TextStyle(fontSize: 13))),
                    const SizedBox(width: 8),
                    Expanded(flex: 3, child: TextField(
                      controller: controllers[c.$1],
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Rename...',
                        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                    )),
                  ]),
                )),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  for (final c in controllers.values) c.dispose();
                  Navigator.pop(ctx);
                },
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _pcVisibleCols = localVisible;
                    for (final c in colDefs) {
                      final custom = controllers[c.$1]?.text.trim() ?? '';
                      _pcColLabels[c.$1] = custom.isNotEmpty ? custom : c.$2;
                    }
                  });
                  for (final c in controllers.values) c.dispose();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mdaPrimaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Employee Performance ────────────────────────────────────────────────

  Widget _buildEmpPerformContent(ColorScheme cs) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage.isNotEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage, style: TextStyle(color: cs.error), textAlign: TextAlign.center)));
    }
    if (_rows.isEmpty) return Center(child: Text('No data available.', style: TextStyle(color: cs.onSurfaceVariant)));

    final grouped = <String, List<_EmpRow>>{};
    for (final row in _rows) { grouped.putIfAbsent(row.employee, () => []).add(row); }
    final employees = grouped.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final isConversion = _selectedSubTab == 1;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: isConversion
          ? [_legend('Post Sale %', Colors.green.shade700), _legendSep(), _legend('Reject %', Colors.red.shade700)]
          : [_legend('Old Ongoing', Colors.amber.shade700), _legendSep(), _legend('New Calls', Colors.blue.shade700), _legendSep(), _legend('Sale', Colors.green.shade700), _legendSep(), _legend('Reject', Colors.red.shade700)],
        ),
      ),
      Expanded(
        child: ListView.builder(
          itemCount: employees.length,
          itemBuilder: (_, i) => _buildEmployeeCard(employees[i], grouped[employees[i]]!, cs, isConversion: isConversion),
        ),
      ),
    ]);
  }

  Widget _legend(String label, Color color) => Row(children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  ]);

  Widget _legendSep() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Text('|', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
  );

  Widget _buildEmployeeCard(String employee, List<_EmpRow> months, ColorScheme cs, {bool isConversion = false}) {
    final isExpanded = _expandedEmployees.contains(employee);
    final displayMonths = isExpanded ? months : <_EmpRow>[];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          borderRadius: BorderRadius.vertical(top: const Radius.circular(10), bottom: !isExpanded ? const Radius.circular(10) : Radius.zero),
          onTap: () => setState(() { if (isExpanded) { _expandedEmployees.remove(employee); } else { _expandedEmployees.add(employee); } }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mdaPrimaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.vertical(top: const Radius.circular(10), bottom: !isExpanded ? const Radius.circular(10) : Radius.zero),
            ),
            child: Row(children: [
              CircleAvatar(radius: 14, backgroundColor: mdaPrimaryBlue.withValues(alpha: 0.15), child: Text(employee.isNotEmpty ? employee[0].toUpperCase() : '?', style: const TextStyle(color: mdaPrimaryBlue, fontWeight: FontWeight.bold, fontSize: 13))),
              const SizedBox(width: 10),
              Expanded(child: Text(employee, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: mdaPrimaryBlue))),
              Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 18, color: cs.onSurfaceVariant),
            ]),
          ),
        ),
        ...displayMonths.asMap().entries.map((entry) {
          final i = entry.key;
          final r = entry.value;
          final isLast = i == displayMonths.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: i.isEven ? cs.surface : cs.surfaceContainerLowest,
              borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(10)) : null,
            ),
            child: Row(children: [
              SizedBox(width: 90, child: Text(r.period, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500))),
              const SizedBox(width: 8),
              Expanded(child: isConversion
                ? _buildConversionStats(r)
                : Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _statValue(r.oldOngoing, Colors.amber.shade700), _divider(),
                    _statValue(r.newCalls, Colors.blue.shade700), _divider(),
                    _statValue(r.sale, Colors.green.shade700), _divider(),
                    _statValue(r.reject, Colors.red.shade700),
                  ])),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _statValue(String value, Color color) => Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color));
  Widget _divider() => Text(' | ', style: TextStyle(color: Colors.grey.shade300, fontSize: 13));

  Widget _buildConversionStats(_EmpRow r) {
    final nCall  = double.tryParse(r.newCalls) ?? 0.0;
    final sale   = double.tryParse(r.sale)     ?? 0.0;
    final reject = double.tryParse(r.reject)   ?? 0.0;
    String pct(double v) {
      if (nCall == 0) return v == 0 ? '0%' : 'Infinity%';
      final p = v / nCall * 100;
      return '${p % 1 == 0 ? p.toInt() : p.toStringAsFixed(2)}%';
    }
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _statValue(pct(sale),   Colors.green.shade700),
      _divider(),
      _statValue(pct(reject), Colors.red.shade700),
    ]);
  }

  // ─── Daily Report ────────────────────────────────────────────────────────

  Widget _buildDailyContent(ColorScheme cs) {
    if (_isDailyLoading) return const Center(child: CircularProgressIndicator());
    if (_dailyError.isNotEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 48, color: cs.error),
          const SizedBox(height: 12),
          Text(_dailyError, style: TextStyle(color: cs.error, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchDailyReport,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white),
          ),
        ]),
      ));
    }
    if (_dailyRows.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 56, color: cs.onSurfaceVariant),
        const SizedBox(height: 12),
        Text('Tap Show to load daily report', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
      ]));
    }

    // Group: execName → section → rows, sorted alphabetically
    final byExec = <String, Map<int, List<_DailyRow>>>{};
    for (final r in _dailyRows) {
      byExec.putIfAbsent(r.execName, () => {});
      byExec[r.execName]!.putIfAbsent(r.section, () => []).add(r);
    }
    // Sort employees A→Z; sort customers A→Z within each section
    final sortedExecs = byExec.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    for (final sections in byExec.values) {
      for (final rows in sections.values) {
        rows.sort((a, b) => a.custName.toLowerCase().compareTo(b.custName.toLowerCase()));
      }
    }

    return ListView.builder(
      itemCount: sortedExecs.length,
      itemBuilder: (_, i) {
        final execName = sortedExecs[i];
        final sections = byExec[execName]!;
        return _buildDailyEmployeeBlock(execName, sections, cs);
      },
    );
  }

  Widget _buildDailyEmployeeBlock(String execName, Map<int, List<_DailyRow>> sections, ColorScheme cs) {
    final initial = execName.isNotEmpty ? execName[0].toUpperCase() : '?';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Employee header bar
      Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [mdaPrimaryBlue, mdaPrimaryBlue.withValues(alpha: 0.85)]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          CircleAvatar(radius: 15, backgroundColor: Colors.white.withValues(alpha: 0.25), child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
          const SizedBox(width: 10),
          Text(execName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ),
      // Sections in order 1..5
      ...List.generate(5, (idx) {
        final sectionNum = idx + 1;
        final rows = sections[sectionNum] ?? [];
        return _buildDailySection(sectionNum, rows, cs);
      }),
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildDailySection(int sectionNum, List<_DailyRow> rows, ColorScheme cs) {
    final label = _sectionLabels[sectionNum] ?? 'Section $sectionNum';
    final color = _sectionColors[sectionNum] ?? mdaPrimaryBlue;
    final key = '$sectionNum';
    final isExpanded = _expandedDailySections.contains(key);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Section header
        InkWell(
          borderRadius: BorderRadius.vertical(top: const Radius.circular(6), bottom: !isExpanded ? const Radius.circular(6) : Radius.zero),
          onTap: () => setState(() {
            if (isExpanded) { _expandedDailySections.remove(key); }
            else { _expandedDailySections.add(key); }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(children: [
              Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(text: TextSpan(children: [
                  TextSpan(text: '$sectionNum. ', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                  TextSpan(text: label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                  TextSpan(text: ' (${rows.length} records)', style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
                ])),
              ),
              Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: cs.onSurfaceVariant),
            ]),
          ),
        ),
        // Customer rows
        if (isExpanded && rows.isNotEmpty) ...[
          Divider(height: 1, thickness: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
          ...rows.asMap().entries.map((entry) => _buildDailyCustomerRow(entry.key, entry.value, color, cs, entry.key == rows.length - 1)),
        ],
        if (isExpanded && rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Text('No records.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontStyle: FontStyle.italic)),
          ),
      ]),
    );
  }

  Widget _buildDailyCustomerRow(int index, _DailyRow row, Color sectionColor, ColorScheme cs, bool isLast) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: index.isEven ? cs.surfaceContainerLowest : cs.surface,
        borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(6)) : null,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Index badge
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: sectionColor.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sectionColor))),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Customer name + due date
          Row(children: [
            Expanded(child: Text(row.custName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
            if (row.dueDate.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today, size: 10, color: sectionColor),
                const SizedBox(width: 3),
                Text(row.dueDate, style: TextStyle(fontSize: 11, color: sectionColor, fontWeight: FontWeight.w500)),
              ]),
          ]),
          if (row.startDate.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.event_note, size: 10, color: cs.onSurfaceVariant),
              const SizedBox(width: 3),
              Text('Start: ${row.startDate}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
          ],
          const SizedBox(height: 4),
          // Status + Product + Activity chips
          Wrap(spacing: 4, runSpacing: 4, children: [
            if (row.status.isNotEmpty) _chip(row.status, cs.primaryContainer, cs.onPrimaryContainer),
            if (row.product.isNotEmpty) _chip(row.product, cs.secondaryContainer, cs.onSecondaryContainer),
            if (row.activity.isNotEmpty) _chip(row.activity, cs.tertiaryContainer, cs.onTertiaryContainer),
          ]),
          if (row.lastRemark.isNotEmpty) ...[
            const SizedBox(height: 5),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.chat_bubble_outline, size: 11, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(child: Text(row.lastRemark, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ])),
      ]),
    );
  }

  // ─── Custom Report ──────────────────────────────────────────────────────

  Widget _buildCustomContent(ColorScheme cs) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildCustomFilters(cs),
        const SizedBox(height: 10),
        if (_isCrLoading)
          const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 48), child: CircularProgressIndicator()))
        else if (_crError.isNotEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text(_crError, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: _fetchCustomReport, icon: const Icon(Icons.refresh), label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white)),
            ]),
          ))
        else if (!_crHasData)
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.bar_chart, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text('Set filters above and tap Show', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15), textAlign: TextAlign.center),
            ]),
          ))
        else ...[
          _buildSummarySection(cs),
          const SizedBox(height: 10),
          _buildChartsSection(cs),
          const SizedBox(height: 10),
          if (_crType == 'All' || _crType == 'Pending') ...[
            _PaginatedCallSection(title: 'Ongoing Calls Details', rows: _crOngoingRows, isNextDate: true, accentColor: mdaPrimaryBlue, cs: cs),
            const SizedBox(height: 10),
          ],
          if (_crType == 'All' || _crType == 'Close') ...[
            _PaginatedCallSection(title: 'Sale Calls Detail', rows: _crSaleRows, isNextDate: false, accentColor: const Color(0xFF2E7D32), cs: cs),
            const SizedBox(height: 10),
            _PaginatedCallSection(title: 'Reject Calls Detail', rows: _crRejectRows, isNextDate: false, accentColor: const Color(0xFFC62828), cs: cs),
            const SizedBox(height: 10),
          ],
        ],
      ]),
    );
  }

  Widget _buildCustomFilters(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.outlineVariant)),
      child: LayoutBuilder(builder: (_, constraints) {
        final wide = constraints.maxWidth > 520;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _crFilterRow(wide, _crDateField('From', _crFromDateCtrl, true), _crDateField('To Last Date', _crToDateCtrl, false)),
          const SizedBox(height: 8),
          _crFilterRow(wide,
            _crLabeledDropdown('Executive Name', _executives, _crExCode, (v) => setState(() => _crExCode = v ?? '0')),
            _crLabeledDropdown('Activity', _activities, _crActivity, (v) => setState(() => _crActivity = v ?? '0'))),
          const SizedBox(height: 8),
          _crFilterRow(wide,
            _crLabeledDropdown('Source', _sources, _crSource, (v) => setState(() => _crSource = v ?? '0')),
            _crGroupByWidget()),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Wrap(spacing: 0, children: [
              _crRadioBtn('All', 'All'),
              _crRadioBtn('Ongoing', 'Pending'),
              _crRadioBtn('Closed', 'Close'),
            ])),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _fetchCustomReport,
              style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              child: const Text('Show', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ]);
      }),
    );
  }

  Widget _crFilterRow(bool wide, Widget a, Widget b) {
    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: a), const SizedBox(width: 12), Expanded(child: b),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, const SizedBox(height: 8), b]);
  }

  Widget _crDateField(String label, TextEditingController controller, bool isFrom) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'dd-mm-yyyy',
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade400)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade400)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: mdaPrimaryBlue)),
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today, size: 16, color: mdaPrimaryBlue),
            onPressed: () => _crPickDate(isFrom),
          ),
        ),
      ),
    ]);
  }

  Widget _crLabeledDropdown(String label, List<Map<String, String>> items, String value, ValueChanged<String?> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      _buildDropdown(items, value, onChanged),
    ]);
  }

  Widget _crGroupByWidget() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Group By', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Row(children: [
        _crToggleBtn('Product', _crGroupBy == 'Product', () => setState(() => _crGroupBy = 'Product')),
        const SizedBox(width: 8),
        _crToggleBtn('Status', _crGroupBy == 'Status', () => setState(() => _crGroupBy = 'Status')),
      ]),
    ]);
  }

  Widget _crToggleBtn(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? mdaPrimaryBlue : Colors.transparent,
          border: Border.all(color: active ? mdaPrimaryBlue : Colors.grey.shade400),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: active ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _crRadioBtn(String label, String value) {
    final selected = _crType == value;
    return GestureDetector(
      onTap: () => setState(() => _crType = value),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 18, height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: selected ? mdaPrimaryBlue : Colors.grey.shade400, width: 2),
          ),
          child: selected
              ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: mdaPrimaryBlue)))
              : null,
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 13, color: selected ? mdaPrimaryBlue : null, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
        const SizedBox(width: 10),
      ]),
    );
  }

  Future<void> _crPickDate(bool isFrom) async {
    DateTime initial;
    try {
      final p = (isFrom ? _crFromDateCtrl.text : _crToDateCtrl.text).split('-');
      initial = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
    } catch (_) {
      initial = DateTime.now();
    }
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2020), lastDate: DateTime(2030));
    if (picked != null && mounted) {
      final f = '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
      setState(() {
        if (isFrom) { _crFromDateCtrl.text = f; } else { _crToDateCtrl.text = f; }
      });
    }
  }

  Widget _buildChartsSection(ColorScheme cs) {
    return LayoutBuilder(builder: (_, constraints) {
      final wide = constraints.maxWidth > 560;
      final barCard = _buildChartCard('Activity Distribution', _buildActivityBarChart(cs), cs);
      final pieCard = _buildChartCard('Open Call Reason', _buildOpenCallPie(cs), cs);
      if (wide) {
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(flex: 2, child: barCard),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: pieCard),
          ]),
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        barCard, const SizedBox(height: 10), pieCard,
      ]);
    });
  }

  Widget _buildChartCard(String title, Widget content, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        content,
      ]),
    );
  }

  Widget _buildActivityBarChart(ColorScheme cs) {
    if (_crBarData.isEmpty) {
      return SizedBox(height: 120, child: Center(child: Text('No data', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))));
    }
    final maxVal = _crBarData.map((b) => b.pending + b.closed).fold(0, math.max);
    const chartH = 140.0;
    const maxBarH = 120.0;
    const barW = 36.0;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: chartH,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _crBarData.map((bar) {
              final total = bar.pending + bar.closed;
              final pendingH = maxVal == 0 ? 0.0 : (bar.pending / maxVal) * maxBarH;
              final closedH  = maxVal == 0 ? 0.0 : (bar.closed  / maxVal) * maxBarH;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (total > 0) Text('$total', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  if (closedH  > 0) Container(width: barW, height: closedH,  color: const Color(0xFF1565C0)),
                  if (pendingH > 0) Container(width: barW, height: pendingH, color: const Color(0xFF64B5F6)),
                ]),
              );
            }).toList(),
          ),
        ),
      ),
      const SizedBox(height: 4),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _crBarData.map((bar) => SizedBox(
            width: barW + 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(bar.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          )).toList(),
        ),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _chartLegendDot(const Color(0xFF64B5F6)), const SizedBox(width: 4),
        const Text('Ongoing', style: TextStyle(fontSize: 10)),
        const SizedBox(width: 12),
        _chartLegendDot(const Color(0xFF1565C0)), const SizedBox(width: 4),
        const Text('Closed', style: TextStyle(fontSize: 10)),
      ]),
    ]);
  }

  Widget _chartLegendDot(Color color) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _buildOpenCallPie(ColorScheme cs) {
    final total = _crPieOngoing + _crPieSale + _crPieReject;
    if (total == 0) {
      return SizedBox(height: 120, child: Center(child: Text('No data', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))));
    }
    return Column(children: [
      SizedBox(
        height: 130,
        child: CustomPaint(
          painter: _PieChartPainter(ongoing: _crPieOngoing, sale: _crPieSale, reject: _crPieReject),
          child: const SizedBox.expand(),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 4, alignment: WrapAlignment.center, children: [
        _pieLegend('Ongoing', const Color(0xFFFFD54F), _crPieOngoing),
        _pieLegend('Sale',    const Color(0xFF66BB6A), _crPieSale),
        _pieLegend('Reject',  const Color(0xFFEF5350), _crPieReject),
      ]),
    ]);
  }

  Widget _pieLegend(String label, Color color, int count) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text('$label ($count)', style: const TextStyle(fontSize: 10)),
  ]);

  void _showStatusModal(ColorScheme cs) {
    if (_crStatusData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No status data available.')));
      return;
    }
    // Build product × status matrix
    final products  = <String>{};
    final statuses  = <String>{};
    final matrix    = <String, Map<String, int>>{};
    for (final row in _crStatusData) {
      final prod = row['product'] ?? '';
      final stat = row['status'] ?? '';
      final cnt  = int.tryParse(row['count'] ?? '0') ?? 0;
      products.add(prod);
      statuses.add(stat);
      matrix.putIfAbsent(prod, () => {})[stat] = cnt;
    }
    final prodList = products.toList()..sort((a, b) => a.trim().toLowerCase().compareTo(b.trim().toLowerCase()));
    final statList = statuses.toList()..sort((a, b) => a.trim().toLowerCase().compareTo(b.trim().toLowerCase()));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, sc) => Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(children: [
              const Expanded(child: Text('Summary — Product × Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              controller: sc,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: prodList.length,
              itemBuilder: (context, index) {
                final prod = prodList[index];
                final stats = matrix[prod]!;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: cs.outlineVariant)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: mdaPrimaryBlue)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: statList.where((s) => (stats[s] ?? 0) > 0).map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$s: ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                  Text('${stats[s]}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSummarySection(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 2),
          child: Row(children: [
            const Expanded(child: Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            TextButton.icon(
              onPressed: () => _showStatusModal(cs),
              icon: const Icon(Icons.table_chart_outlined, size: 14),
              label: const Text('Show Status', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: mdaPrimaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            TextButton.icon(
              onPressed: () => _exportSummaryToCsv(),
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Export', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Text('Note: Tickets with multiple products show in each product — counts may appear inflated.',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
        ),
        if (_crSummaryRows.isEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text('No data.', style: TextStyle(color: cs.onSurfaceVariant), textAlign: TextAlign.center))
        else
          LayoutBuilder(builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(mdaPrimaryBlue.withValues(alpha: 0.08)),
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: mdaPrimaryBlue),
                  dataTextStyle: const TextStyle(fontSize: 12),
                  columnSpacing: 16,
                  horizontalMargin: 12,
              columns: [
                DataColumn(label: Text(_crGroupBy == 'Status' ? 'Status' : 'Product')),
                const DataColumn(label: Text('New Calls'), numeric: true),
                const DataColumn(label: Text('Ongoing'), numeric: true),
                const DataColumn(label: Text('Sale'), numeric: true),
                const DataColumn(label: Text('Reject'), numeric: true),
              ],
              rows: _crSummaryRows.asMap().entries.map((e) {
                final i = e.key; final r = e.value;
                return DataRow(
                  color: WidgetStateProperty.resolveWith((_) => i.isEven ? cs.surfaceContainerLowest : cs.surface),
                  cells: [
                    DataCell(Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(r.newCalls)),
                    DataCell(Text(r.ongoing)),
                    DataCell(Text(r.sale, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold))),
                    DataCell(Text(r.reject, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold))),
                  ],
                );
              }).toList(),
            ),
          ),
          );
        }),
      ]),
    );
  }

  Future<void> _exportSummaryToCsv() async {
    if (_crSummaryRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export.')));
      return;
    }
    try {
      List<List<dynamic>> csvData = [
        [_crGroupBy == 'Status' ? 'Status' : 'Product', 'New Calls', 'Ongoing', 'Sale', 'Reject'],
      ];
      for (final row in _crSummaryRows) {
        csvData.add([row.label, row.newCalls, row.ongoing, row.sale, row.reject]);
      }
      
      String csv = csvData.map((row) {
        return row.map((cell) {
          String val = cell.toString();
          return '"${val.replaceAll('"', '""')}"';
        }).join(',');
      }).join('\n');
      
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
      } else {
        directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/Summary_Report_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csv);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Report saved to Downloads as Summary_Report_$timestamp.csv'),
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
      }
    }
  }

  // Removed _buildCallSection

  Widget _chip(String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w500)),
  );

  // ─── Shared UI ───────────────────────────────────────────────────────────

  Widget _buildMainTab(int index, String title, IconData icon, ColorScheme cs) {
    final isActive = _selectedMainTab == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedMainTab = index);
        if (index == 0) { _fetchReport(); }
        else if (index == 1) { _fetchDailyReport(); }
        else if (index == 3) { _fetchPendingCustomers(); }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isActive ? mdaPrimaryBlue : cs.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? mdaPrimaryBlue : cs.outlineVariant),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: isActive ? Colors.white : mdaPrimaryBlue, size: 18),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title,
              style: TextStyle(color: isActive ? Colors.white : cs.onSurface, fontWeight: FontWeight.bold, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildSubTab(int index, String title, ColorScheme cs) {
    final isActive = _selectedSubTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedSubTab = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? mdaPrimaryBlue : cs.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isActive ? mdaPrimaryBlue : cs.outlineVariant),
        ),
        child: Text(title, style: TextStyle(color: isActive ? Colors.white : cs.onSurface, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
      ),
    );
  }
}

// ─── Models ──────────────────────────────────────────────────────────────────

class _EmpRow {
  final String period, employee, oldOngoing, newCalls, sale, reject;
  const _EmpRow({required this.period, required this.employee, required this.oldOngoing, required this.newCalls, required this.sale, required this.reject});
}

class _DailyRow {
  final String execName, custName, startDate, dueDate, status, product, activity, lastRemark;
  final int section;
  const _DailyRow({required this.execName, required this.section, required this.custName, required this.startDate, required this.dueDate, required this.status, required this.product, required this.activity, required this.lastRemark});
}

class _SummaryRow {
  final String label, newCalls, ongoing, sale, reject;
  const _SummaryRow({required this.label, required this.newCalls, required this.ongoing, required this.sale, required this.reject});
}

class _CallRow {
  final String clientName, executive, activity, product, status, lastRemark, date;
  const _CallRow({required this.clientName, required this.executive, required this.activity, required this.product, required this.status, required this.lastRemark, required this.date});
}

class _BarData {
  final String label;
  final int pending, closed;
  const _BarData({required this.label, required this.pending, required this.closed});
}

// ─── Pie Chart Painter ────────────────────────────────────────────────────────

class _PieChartPainter extends CustomPainter {
  final int ongoing, sale, reject;
  const _PieChartPainter({required this.ongoing, required this.sale, required this.reject});

  @override
  void paint(Canvas canvas, Size size) {
    final total = ongoing + sale + reject;
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..style = PaintingStyle.fill;
    double startAngle = -math.pi / 2;
    for (final entry in [
      (ongoing, const Color(0xFFFFD54F)),
      (sale,    const Color(0xFF66BB6A)),
      (reject,  const Color(0xFFEF5350)),
    ]) {
      final count = entry.$1;
      final color = entry.$2;
      if (count == 0) continue;
      final sweep = 2 * math.pi * count / total;
      paint.color = color;
      canvas.drawArc(rect, startAngle, sweep, true, paint);
      startAngle += sweep;
    }
    // white border between slices
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter old) =>
      ongoing != old.ongoing || sale != old.sale || reject != old.reject;
}

class _PaginatedCallSection extends StatefulWidget {
  final String title;
  final List<_CallRow> rows;
  final bool isNextDate;
  final Color accentColor;
  final ColorScheme cs;

  const _PaginatedCallSection({
    required this.title,
    required this.rows,
    required this.isNextDate,
    required this.accentColor,
    required this.cs,
  });

  @override
  State<_PaginatedCallSection> createState() => _PaginatedCallSectionState();
}

class _PaginatedCallSectionState extends State<_PaginatedCallSection> {
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  @override
  void didUpdateWidget(covariant _PaginatedCallSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows != widget.rows) {
      _currentPage = 0;
    }
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    List<Widget> buttons = [];
    Widget buildPageBtn(int pageIndex) {
      final isSelected = _currentPage == pageIndex;
      return InkWell(
        onTap: isSelected ? null : () => setState(() => _currentPage = pageIndex),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? widget.accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSelected ? widget.accentColor : widget.cs.outlineVariant),
          ),
          child: Text(
            '${pageIndex + 1}',
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : widget.cs.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    Widget buildEllipsis() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text('...', style: TextStyle(fontSize: 12, color: widget.cs.onSurfaceVariant)),
      );
    }

    if (totalPages <= 5) {
      for (int i = 0; i < totalPages; i++) {
        buttons.add(buildPageBtn(i));
      }
    } else {
      if (_currentPage < 3) {
        for (int i = 0; i < 4; i++) { buttons.add(buildPageBtn(i)); }
        buttons.add(buildEllipsis());
        buttons.add(buildPageBtn(totalPages - 1));
      } else if (_currentPage > totalPages - 4) {
        buttons.add(buildPageBtn(0));
        buttons.add(buildEllipsis());
        for (int i = totalPages - 4; i < totalPages; i++) { buttons.add(buildPageBtn(i)); }
      } else {
        buttons.add(buildPageBtn(0));
        buttons.add(buildEllipsis());
        buttons.add(buildPageBtn(_currentPage - 1));
        buttons.add(buildPageBtn(_currentPage));
        buttons.add(buildPageBtn(_currentPage + 1));
        buttons.add(buildEllipsis());
        buttons.add(buildPageBtn(totalPages - 1));
      }
    }
    return buttons;
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: widget.cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: widget.cs.onSurfaceVariant)),
              Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final totalItems = rows.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    
    // Ensure current page is valid when rows length changes dynamically
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = math.min(startIndex + _itemsPerPage, totalItems);
    final currentRows = rows.sublist(startIndex, endIndex);

    return Container(
      decoration: BoxDecoration(color: widget.cs.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.cs.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.07), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            Container(width: 4, height: 16, decoration: BoxDecoration(color: widget.accentColor, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: widget.accentColor))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: widget.accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Text('${widget.rows.length}', style: TextStyle(fontSize: 12, color: widget.accentColor, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        if (rows.isEmpty)
          Padding(padding: const EdgeInsets.all(16),
            child: Text('No records.', style: TextStyle(color: widget.cs.onSurfaceVariant, fontStyle: FontStyle.italic), textAlign: TextAlign.center))
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: currentRows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = currentRows[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            r.clientName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        if (r.status.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              r.status,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: widget.accentColor),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildDetailItem(Icons.person_outline, 'Executive', r.executive)),
                        Expanded(child: _buildDetailItem(Icons.local_activity_outlined, 'Activity', r.activity)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildDetailItem(Icons.inventory_2_outlined, 'Product', r.product)),
                        Expanded(child: _buildDetailItem(Icons.calendar_today_outlined, widget.isNextDate ? 'Next Date' : 'Last Date', r.date)),
                      ],
                    ),
                    if (r.lastRemark.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes, size: 14, color: widget.cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              r.lastRemark,
                              style: TextStyle(fontSize: 12, color: widget.cs.onSurfaceVariant, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text('Showing ${startIndex + 1} to $endIndex of $totalItems entries', style: TextStyle(fontSize: 12, color: widget.cs.onSurfaceVariant)),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          iconSize: 20,
                          visualDensity: VisualDensity.compact,
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                        ),
                        ..._buildPageNumbers(totalPages),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          iconSize: 20,
                          visualDensity: VisualDensity.compact,
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ]),
    );
  }
}
