// File: lib/features/client_management/presentation/screens/customer_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mda_crm/features/client_management/presentation/screens/customer_detail_screen.dart';
import 'package:mda_crm/features/client_management/presentation/widgets/grouping_list_view.dart' show GroupingListView, GroupingDialog;
import 'package:mda_crm/features/client_management/data/models/group_model.dart';
import 'package:mda_crm/features/client_management/presentation/widgets/add_customer_dialog.dart';
import 'package:mda_crm/features/client_management/presentation/widgets/merge_customer_dialog.dart';
import 'package:mda_crm/shared/widgets/app_drawer.dart';
import 'package:mda_crm/shared/widgets/app_user_menu.dart';
import 'package:mda_crm/shared/utils/app_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mda_crm/features/client_management/presentation/widgets/edit_customer_dialog.dart';
import 'package:mda_crm/features/client_management/presentation/widgets/delete_customer_dialog.dart';
import 'package:mda_crm/features/client_management/presentation/widgets/add_ticket_dialog.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = [
    'All Customers',
    'Customer Allotment',
    'Grouping',
  ];

  String _companyName = '';

  // State for Allotment Tab
  bool _showNotAlloted = true;
  final Set<String> _selectedAllotmentIndices = {};
  final ScrollController _scrollController = ScrollController();

  // Dropdown Data for Allotment Modal
  List<Map<String, String>> _executives = [];
  List<Map<String, String>> _products = [];
  bool _isLoadingDropdowns = false;

  // State for All Customers Tab (null = All, 'Old' = Old, 'New' = New)
  String? _customerType; 
  String _searchQuery = '';

  // API Data State
  bool _isLoading = true;
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _displayedCustomers = [];
  List<CustomerGroup> _groupingData = [];

  // Pagination State
  int _currentPage = 1;
  int _totalEntries = 0;
  final int _entriesPerPage = 10;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fetchCustomers();
    _fetchAllotmentDropdowns();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _companyName = prefs.getString('O_Name') ?? '';
      });
    }
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    _allCustomers.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      final String clientId = prefs.getString('CLIENTID') ?? 'demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      final int grade = int.tryParse(prefs.getString('Grade') ?? '0') ?? 0;
      final String sno7 = prefs.getString('sno') ?? '0';
      final int showAllC = int.tryParse(prefs.getString('showAllCustomer') ?? '0') ?? 0;

      String endpoint = '';
      Map<String, dynamic> payload = {};

      if (_selectedFilterIndex == 0) {
        endpoint = 'https://webservices.mdapulse.com/Customer.aspx/fillCustomerList';
        String chkValue = 'P1';
        if (_customerType == 'Old') chkValue = 'A1'; 
        if (_customerType == 'New') chkValue = 'N1'; 
        
        payload = {"ClientId": clientId, "chk": chkValue, "DB": db, "Grade": grade, "sno_7": sno7, "showAllC": showAllC};
      } else if (_selectedFilterIndex == 1) {
        endpoint = 'https://webservices.mdapulse.com/Customer.aspx/fillCustomerAllotment';
        payload = {"ClientId": clientId, "chk": _showNotAlloted ? 'NotAllot' : 'Allot', "DB": db, "Grade": grade, "sno_7": sno7, "showAllC": showAllC};
      } else if (_selectedFilterIndex == 2) {
        endpoint = 'https://webservices.mdapulse.com/Customer.aspx/fillARch';
        payload = {"ClientId": clientId, "DB": db};
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String rawData = responseData['d'] ?? '';

        List<Map<String, dynamic>> parsedList = [];

        if (rawData.isNotEmpty) {
          List<String> rows = rawData.split('#');
          for (String row in rows) {
            if (row.trim().isEmpty) continue;
            List<String> cols = row.split('^');
            
            if (_selectedFilterIndex == 0 && cols.length >= 7) {
              parsedList.add({
                'sno': cols[0], 'orgName': cols[1].trim(), 'contactPerson': cols[2].trim(), 'phone': cols[3].trim(), 'email': cols[4].trim(), 'lastContact': cols[5].trim(), 'status': cols[6].trim(),
              });
            } else if (_selectedFilterIndex == 1 && cols.length >= 10) {
              parsedList.add({
                'sno': cols[0], 'orgName': cols[1].trim(), 'contactPerson': cols[2].trim(), 'phone': cols[3].trim(), 'email': cols[4].trim(), 'custID': cols[5].trim(), 'dateAdded': cols[6].trim(), 'product': cols[7].trim(), 'uCode': cols[8].trim(), 'uName': cols[9].trim(),
              });
            } else if (_selectedFilterIndex == 2 && cols.length >= 4) {
              parsedList.add({
                'snoArch': cols[0],
                'archName': cols[1].trim(),
                'archMobile': cols[2].trim(),
                'archCity': cols[3].trim(),
                'snoCst': cols.length > 4 ? cols[4] : '0',
                'custName': cols.length > 5 ? cols[5].trim() : '',
                'cPerson': cols.length > 6 ? cols[6].trim() : '',
                'cstMobile': cols.length > 7 ? cols[7].trim() : '',
                'cstEmail': cols.length > 8 ? cols[8].trim() : '',
                'cDate': cols.length > 9 ? cols[9].trim() : '',
                'status': cols.length > 10 ? cols[10].trim() : '',
              });
            }
          }
        }

        if (_selectedFilterIndex == 2) {
          final Map<String, List<GroupMember>> membersByArch = {};
          final Map<String, Map<String, String>> archInfo = {};
          for (final row in parsedList) {
            final snoArch = row['snoArch'] as String;
            archInfo.putIfAbsent(snoArch, () => {
              'name': row['archName'] as String,
              'city': row['archCity'] as String,
              'mobile': row['archMobile'] as String,
            });
            membersByArch.putIfAbsent(snoArch, () => []);
            final String snoCst = row['snoCst'] as String;
            if (snoCst.isNotEmpty && snoCst != '0') {
              membersByArch[snoArch]!.add(GroupMember(
                orgName: row['custName'] as String,
                contactPerson: row['cPerson'] as String,
                phone: row['cstMobile'] as String,
                email: row['cstEmail'] as String,
                lastContact: row['cDate'] as String,
                status: row['status'] as String,
              ));
            }
          }
          if (mounted) {
            setState(() {
              _groupingData = archInfo.entries.map((e) => CustomerGroup(
                snoArch: e.key,
                groupName: e.value['name']!,
                city: e.value['city']!,
                mobileNumber: e.value['mobile']!,
                members: membersByArch[e.key] ?? [],
              )).toList();
              _isLoading = false;
            });
          }
          return;
        }

        parsedList.sort((a, b) => (a['orgName'] ?? '').toString().toLowerCase().compareTo((b['orgName'] ?? '').toString().toLowerCase()));
        setState(() {
          _allCustomers = parsedList;
          _isLoading = false;
        });

        _applyFiltersAndPagination();
      }
    } catch (e) {
      debugPrint("Error fetching customers: $e");
      setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndPagination() {
    List<Map<String, dynamic>> filtered = _allCustomers;

    if (_searchQuery.isNotEmpty) {
      final search = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final org = (c['orgName'] ?? '').toString().toLowerCase();
        final person = (c['contactPerson'] ?? '').toString().toLowerCase();
        final phone = (c['phone'] ?? '').toString().toLowerCase();
        return org.contains(search) || person.contains(search) || phone.contains(search);
      }).toList();
    }

    filtered.sort((a, b) {
      final aName = (a['orgName'] ?? a['contactPerson'] ?? '').toString().toLowerCase();
      final bName = (b['orgName'] ?? b['contactPerson'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });

    _totalEntries = filtered.length;

    int startIndex = (_currentPage - 1) * _entriesPerPage;
    int endIndex = startIndex + _entriesPerPage;
    if (startIndex >= filtered.length) {
      startIndex = 0; _currentPage = 1; endIndex = _entriesPerPage;
    }
    if (endIndex > filtered.length) endIndex = filtered.length;

    setState(() {
      _displayedCustomers = filtered.sublist(startIndex, endIndex);
    });
  }

  Future<void> _fetchAllotmentDropdowns() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      final int sno = int.tryParse(prefs.getString('sno') ?? '1') ?? 1;

      // 1. Fetch all Executives (EMP1 + sno=0 returns all employees, not just logged-in user)
      final empResponse = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/Fill_DropDown'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "chk": "EMP1", "sno": 0, "DB": db}),
      );

      // 2. Fetch Products
      final prodResponse = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/Fill_DropDown'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({"ClientId": clientId, "chk": "Product", "sno": sno, "DB": db}),
      );

      if (empResponse.statusCode == 200 && prodResponse.statusCode == 200) {
        final empRaw = jsonDecode(empResponse.body)['d'] ?? '';
        final prodRaw = jsonDecode(prodResponse.body)['d'] ?? '';

        List<Map<String, String>> empList = [];
        List<Map<String, String>> prodList = [];

        // Parse format: val~text#
        for (String row in empRaw.split('#')) {
          if (row.trim().isEmpty) continue;
          List<String> parts = row.split('~');
          if (parts.length >= 2) empList.add({'val': parts[0], 'text': parts[1]});
        }

        for (String row in prodRaw.split('#')) {
          if (row.trim().isEmpty) continue;
          List<String> parts = row.split('~');
          if (parts.length >= 2) prodList.add({'val': parts[0], 'text': parts[1]}); // Note: for product, text is saved in DB
        }

        setState(() {
          _executives = empList;
          _products = prodList;
          _isLoadingDropdowns = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching dropdowns: $e");
      setState(() => _isLoadingDropdowns = false);
    }
  }

  Future<bool> _saveAllotment(String selectedUCode, String selectedProduct) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final String db = prefs.getString('D_Database') ?? 'mdapulse';
      final String loginName = prefs.getString('UName') ?? 'Admin';

      // Build the sno_ucode string (e.g., "120~2^121~2")
      List<String> combinations = [];
      for (String sno in _selectedAllotmentIndices) {
        combinations.add("$sno~$selectedUCode");
      }
      final String snoUcodeStr = combinations.join('^');

      final response = await http.post(
        Uri.parse('https://webservices.mdapulse.com/Customer.aspx/Save_AllotCustomer'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          "ClientId": clientId,
          "sno_ucode": snoUcodeStr,
          "ucode": selectedUCode,
          "Product": selectedProduct,
          "TypeOfCall": 0,
          "DB": db,
          "LoginName": loginName
        }),
      );

      if (response.statusCode == 200) {
        final String result = jsonDecode(response.body)['d']?.toString() ?? '';
        if (result == '1') {
          _selectedAllotmentIndices.clear();
          _fetchCustomers();
          return true; // Success!
        } else {
          if (!mounted) return false;
          await showAppDialog(context, type: DialogType.warning, title: 'Allotment Failed', message: 'Server returned: $result');
          return false;
        }
      } else {
        // FIXED: Added error handling so it never fails silently again
        if (!mounted) return false;
        await showAppDialog(context, type: DialogType.error, title: 'Server Error', message: 'Status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      await showAppDialog(context, type: DialogType.error, title: 'Network Error', message: 'Could not connect to server. Check your internet connection.');
      return false;
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        actions: const [AppUserMenu()],
      ),
      drawer: AppDrawer(currentRoute: 'Customer', companyName: _companyName),
      floatingActionButton: _buildSmartFAB(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(_filters.length, (index) {
                final isSelected = _selectedFilterIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFilterIndex = index;
                      _selectedAllotmentIndices.clear();
                      _currentPage = 1;
                    });
                    _fetchCustomers(); 
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? mdaPrimaryBlue : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? mdaPrimaryBlue : Theme.of(context).colorScheme.outline),
                      boxShadow: isSelected ? [BoxShadow(color: mdaPrimaryBlue.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))] : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _filters[index],
                          style: TextStyle(color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14),
                        ),
                        if (isSelected) const Icon(Icons.check_circle, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            if (_selectedFilterIndex == 0) ...[
              Row(
                children: [
                  const Spacer(),
                  _buildOldNewToggle(),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Merge Customers',
                    icon: const Icon(Icons.compress, color: mdaPrimaryBlue),
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const MergeCustomerDialog(),
                      ).then((v) { if (v == true) _fetchCustomers(); });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedFilterIndex == 1) ...[
              Center(child: _buildAllotmentToggle()),
              const SizedBox(height: 16),
            ],

            TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (val) {
                _searchQuery = val;
                _currentPage = 1;
                _applyFiltersAndPagination();
              },
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: mdaPrimaryBlue))
                : SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      children: [
                        Builder(
                          builder: (context) {
                            switch (_selectedFilterIndex) {
                              case 1:
                                return _buildAllotmentList();
                              case 2:
                                return GroupingListView(groups: _groupingData, searchQuery: _searchQuery, onRefresh: _fetchCustomers);
                              case 0:
                              default:
                                return _buildStandardCustomerList();
                            }
                          },
                        ),
                        if (_selectedFilterIndex != 2 && _displayedCustomers.isNotEmpty) 
                          _buildPaginationFooter(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildSmartFAB() {
    if (_selectedFilterIndex == 0) {
      return FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AddCustomerDialog(isOldCustomer: _customerType == 'Old'),
          ).then((value) { if (value == true) _fetchCustomers(); });
        },
        icon: const Icon(Icons.add),
        label: Text(_customerType == 'Old' ? 'Add Old Customer' : 'Add New Customer'),
        backgroundColor: mdaPrimaryBlue,
        foregroundColor: Colors.white,
      );
    }
    if (_selectedFilterIndex == 1) {
      return FloatingActionButton.extended(
        onPressed: _selectedAllotmentIndices.isEmpty ? null : () => _showAllotToDialog(),
        icon: const Icon(Icons.check_circle),
        label: const Text('Allot To'),
        backgroundColor: _selectedAllotmentIndices.isEmpty ? mdaPrimaryBlue.withValues(alpha: 0.4) : mdaPrimaryBlue,
        foregroundColor: Colors.white,
      );
    }
    if (_selectedFilterIndex == 2) {
      return FloatingActionButton.extended(
        onPressed: () async {
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const GroupingDialog(),
          );
          if (result == true) _fetchCustomers();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Grouping'),
        backgroundColor: mdaPrimaryBlue,
        foregroundColor: Colors.white,
      );
    }
    return null;
  }

  Widget _buildOldNewToggle() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: mdaPrimaryBlue), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleBtn('Old Customer', _customerType == 'Old', () {
            setState(() { _customerType = _customerType == 'Old' ? null : 'Old'; _currentPage = 1; });
            _fetchCustomers();
          }),
          _buildToggleBtn('New Customer', _customerType == 'New', () {
            setState(() { _customerType = _customerType == 'New' ? null : 'New'; _currentPage = 1; });
            _fetchCustomers();
          }),
        ],
      ),
    );
  }

  Widget _buildAllotmentToggle() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: mdaPrimaryBlue), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleBtn('Not Alloted', _showNotAlloted, () {
            setState(() { _showNotAlloted = true; _selectedAllotmentIndices.clear(); _currentPage = 1; });
            _fetchCustomers();
          }),
          _buildToggleBtn('Alloted', !_showNotAlloted, () {
            setState(() { _showNotAlloted = false; _selectedAllotmentIndices.clear(); _currentPage = 1; });
            _fetchCustomers();
          }),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String text, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? mdaPrimaryBlue : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.horizontal(
            left: text.contains('Old') || text == 'Not Alloted' ? const Radius.circular(5) : Radius.zero,
            right: text.contains('New') || text == 'Alloted' ? const Radius.circular(5) : Radius.zero,
          ),
        ),
        child: Text(text, style: TextStyle(color: isActive ? Colors.white : mdaPrimaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    int startEntry = ((_currentPage - 1) * _entriesPerPage) + 1;
    int endEntry = _currentPage * _entriesPerPage;
    if (endEntry > _totalEntries) endEntry = _totalEntries;
    if (_totalEntries == 0) { startEntry = 0; endEntry = 0; }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        children: [
          Text('Showing $startEntry to $endEntry of $_totalEntries entries', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _currentPage > 1 ? () { _currentPage--; _applyFiltersAndPagination(); if (_scrollController.hasClients) _scrollController.jumpTo(0); } : null,
                child: const Text('Prev'),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: mdaPrimaryBlue, borderRadius: BorderRadius.circular(8)),
                child: Text('$_currentPage', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _currentPage < (_totalEntries / _entriesPerPage).ceil() ? () { _currentPage++; _applyFiltersAndPagination(); if (_scrollController.hasClients) _scrollController.jumpTo(0); } : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandardCustomerList() {
    if (_displayedCustomers.isEmpty) {
      return Padding(padding: const EdgeInsets.all(32.0), child: Center(child: Text('No customers found.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _displayedCustomers.length,
      itemBuilder: (context, index) {
        final cs = Theme.of(context).colorScheme;
        final cust = _displayedCustomers[index];
        final String currentStatus = cust['status'] ?? '';
        final String orgName = cust['orgName'].toString().isNotEmpty ? cust['orgName'] : 'Unknown Organization';
        final String contactPerson = cust['contactPerson'].toString().isNotEmpty ? cust['contactPerson'] : 'No Contact';

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CustomerDetailScreen(customerSno: cust['sno'].toString(), contactName: contactPerson, orgName: orgName, status: currentStatus, mobileNo: cust['phone'].toString())),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(orgName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: mdaPrimaryBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(contactPerson, style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (currentStatus.isNotEmpty)
                        Flexible(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.amber[400], borderRadius: BorderRadius.circular(6)),
                            child: Text(currentStatus, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(Icons.more_vert, color: cs.onSurfaceVariant),
                       onSelected: (value) {
                          final String customerSno = cust['sno'].toString();
                          final String customerName = cust['contactPerson'].toString();
                          if (value == 'edit') {
                            // Extract the customer Sno to pass to the Edit Dialog
                            final String customerSno = cust['sno'].toString();
                            
                            showDialog(
                              context: context, 
                              barrierDismissible: false,
                              builder: (context) => EditCustomerDialog(customerSno: customerSno)
                            ).then((wasUpdated) {
                              // If the dialog returns true, refresh the customer list!
                              if (wasUpdated == true) {
                                _fetchCustomers();
                              }
                            });
                          } else if (value == 'delete') {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => DeleteCustomerDialog(
                                customerSno: customerSno,
                                customerName: customerName.isNotEmpty ? customerName : 'this customer',
                              )
                            ).then((wasDeleted) {
                              if (wasDeleted == true) {
                                if (!mounted) return;
                                showAppDialog(context, type: DialogType.success, title: 'Deleted', message: 'Customer has been deleted successfully.'); // ignore: use_build_context_synchronously
                                _fetchCustomers();
                              }
                            });
                          } else if (value == 'ticket') {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => AddTicketDialog(
                                customerSno: customerSno,
                                customerName: customerName.isNotEmpty ? customerName : cust['orgName'].toString(),
                                mobileNumber: cust['phone'].toString(),
                              ),
                            );
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'ticket', child: ListTile(leading: Icon(Icons.confirmation_number_outlined, color: mdaPrimaryBlue), title: Text('Add Ticket'), contentPadding: EdgeInsets.zero)),
                          const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: mdaPrimaryBlue), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
                          const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
                        ],
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(height: 1)),
                  Row(
                    children: [
                      Expanded(child: _buildDetailRow(Icons.phone, 'Phone', cust['phone'].toString().isNotEmpty ? cust['phone'] : 'N/A')),
                      Expanded(child: _buildDetailRow(Icons.calendar_today, 'Last Contact', cust['lastContact'].toString().isNotEmpty ? cust['lastContact'] : 'N/A')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllotmentList() {
    if (_displayedCustomers.isEmpty) {
      return Padding(padding: const EdgeInsets.all(32.0), child: Center(child: Text('No customers found.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _displayedCustomers.length,
      itemBuilder: (context, index) {
        final cs = Theme.of(context).colorScheme;
        final cust = _displayedCustomers[index];
        final String sno = cust['sno'].toString();
        final bool isSelected = _selectedAllotmentIndices.contains(sno);
        final String orgName = cust['orgName'].toString().isNotEmpty ? cust['orgName'] : 'Unknown Organization';
        final String contactPerson = cust['contactPerson'].toString().isNotEmpty ? cust['contactPerson'] : 'No Contact';
        final String phone = cust['phone'].toString().isNotEmpty ? cust['phone'] : '--';
        final String execName = cust['uName'].toString().isNotEmpty ? cust['uName'] : 'Not Assigned';
        final String product = cust['product'].toString().isNotEmpty ? cust['product'] : 'N/A';

        return Card(
          color: isSelected ? mdaPrimaryBlue.withValues(alpha: 0.05) : null,
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? mdaPrimaryBlue.withValues(alpha: 0.5) : Colors.transparent, width: 1)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => isSelected ? _selectedAllotmentIndices.remove(sno) : _selectedAllotmentIndices.add(sno)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: mdaPrimaryBlue,
                    onChanged: (bool? value) => setState(() => value == true ? _selectedAllotmentIndices.add(sno) : _selectedAllotmentIndices.remove(sno)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(orgName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: mdaPrimaryBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person, size: 14, color: cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(child: Text(contactPerson, style: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        if (phone != '--') ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 14, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(phone, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                            ],
                          ),
                        ],
                        const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 1)),
                        Row(
                          children: [
                            Expanded(child: _buildDetailRow(Icons.assignment_ind, 'Executive', execName)),
                            if (!_showNotAlloted)
                              Expanded(child: _buildDetailRow(Icons.inventory_2, 'Product', product)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: cs.onSurface, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }


  // ==========================================
  // ALLOTMENT MODAL (UPDATED WITH DYNAMIC DATA)
  // ==========================================
  Future<void> _showAllotToDialog() async {
    if (_isLoadingDropdowns) {
      showAppDialog(context, type: DialogType.info, title: 'Please Wait', message: 'Loading executives and products, try again in a moment.');
      return;
    }
    if (_executives.isEmpty || _products.isEmpty) {
      showAppDialog(context, type: DialogType.warning, title: 'No Data', message: 'No executives or products are available in the database.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final String myUcode = prefs.getString('UCode') ?? '';
    if (!mounted) return;
    final defaultExec = _executives.firstWhere(
      (e) => e['val'] == myUcode,
      orElse: () => _executives[0],
    );
    String selectedExecVal = defaultExec['val']!;
    String selectedProdVal = _products[0]['text']!; 
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( 
          builder: (context, setModalState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(color: mdaPrimaryBlue, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Customer Allotment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), InkWell(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.white, size: 20))])),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Executive Name', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedExecVal,
                              items: _executives.map((Map<String, String> exec) { 
                                return DropdownMenuItem<String>(value: exec['val'], child: Text(exec['text']!)); 
                              }).toList(),
                              onChanged: (val) { if (val != null) setModalState(() => selectedExecVal = val); },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text('Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedProdVal,
                              items: _products.map((Map<String, String> prod) { 
                                return DropdownMenuItem<String>(value: prod['text'], child: Text(prod['text']!)); 
                              }).toList(),
                              onChanged: (val) { if (val != null) setModalState(() => selectedProdVal = val); },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), style: TextButton.styleFrom(foregroundColor: Colors.grey[600]), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        isSaving 
                          ? const CircularProgressIndicator(color: mdaPrimaryBlue)
                          : ElevatedButton(
                              onPressed: () async {
                                setModalState(() => isSaving = true);
                                
                                bool success = await _saveAllotment(selectedExecVal, selectedProdVal);
                                
                                if (success) {
                                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                                  if (!mounted) return;
                                  showAppDialog(this.context, type: DialogType.success, title: 'Allotted Successfully', message: 'Selected customers have been allotted successfully.');
                                } else {
                                  if (!mounted) return;
                                  setModalState(() => isSaving = false);
                                }
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
                              child: const Text('Save'),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }
}

