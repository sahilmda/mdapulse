// File: lib/features/client_management/presentation/screens/customer_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mda_crm/features/authentication/presentation/screens/login_screen.dart';
import 'package:mda_crm/features/client_management/presentation/screens/customer_detail_screen.dart';
import 'package:mda_crm/features/client_management/presentation/widgets/grouping_list_view.dart';
import 'package:mda_crm/shared/widgets/app_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mda_crm/features/client_management/presentation/widgets/add_customer_dialog.dart';

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

  // State for Allotment Tab
  bool _showNotAlloted = true;
  final Set<int> _selectedAllotmentIndices = {};

  // State for All Customers Tab (null = All, 'Old' = Old, 'New' = New)
  String? _customerType; 
  String _searchQuery = '';

  // API Data State
  bool _isLoading = true;
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _displayedCustomers = [];

  // Pagination State
  int _currentPage = 1;
  int _totalEntries = 0;
  final int _entriesPerPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchCustomers(); 
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
        // Tab 1: All Customers
        endpoint = 'https://mdapulse.com/Customer.aspx/fillCustomerList';
        String chkValue = 'P1';
        if (_customerType == 'Old') chkValue = 'A1'; // Active/Old
        if (_customerType == 'New') chkValue = 'N1'; // New
        
        payload = {
          "ClientId": clientId,
          "chk": chkValue,
          "DB": db,
          "Grade": grade,
          "sno_7": sno7,
          "showAllC": showAllC
        };
      } else if (_selectedFilterIndex == 1) {
        // Tab 2: Customer Allotment
        endpoint = 'https://mdapulse.com/Customer.aspx/fillCustomerAllotment';
        payload = {
          "ClientId": clientId,
          "chk": _showNotAlloted ? 'NotAllot' : 'Allot',
          "DB": db,
          "Grade": grade,
          "sno_7": sno7,
          "showAllC": showAllC
        };
      } else if (_selectedFilterIndex == 2) {
        // Tab 3: Grouping / Architect
        endpoint = 'https://mdapulse.com/Customer.aspx/fillARch';
        payload = {
          "ClientId": clientId,
          "DB": db
        };
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
                'sno': cols[0],
                'orgName': cols[1].trim(),
                'contactPerson': cols[2].trim(),
                'phone': cols[3].trim(),
                'email': cols[4].trim(),
                'lastContact': cols[5].trim(),
                'status': cols[6].trim(),
              });
            } else if (_selectedFilterIndex == 1 && cols.length >= 10) {
              parsedList.add({
                'sno': cols[0],
                'orgName': cols[1].trim(),
                'contactPerson': cols[2].trim(),
                'phone': cols[3].trim(),
                'email': cols[4].trim(),
                'custID': cols[5].trim(),
                'dateAdded': cols[6].trim(),
                'product': cols[7].trim(),
                'uCode': cols[8].trim(),
                'uName': cols[9].trim(),
              });
            } else if (_selectedFilterIndex == 2) {
              // Grouping logic will process the raw hierarchical string later
              parsedList.add({'raw': row});
            }
          }
        }

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

    _totalEntries = filtered.length;

    int startIndex = (_currentPage - 1) * _entriesPerPage;
    int endIndex = startIndex + _entriesPerPage;
    if (startIndex >= filtered.length) {
      startIndex = 0;
      _currentPage = 1;
      endIndex = _entriesPerPage;
    }
    if (endIndex > filtered.length) {
      endIndex = filtered.length;
    }

    setState(() {
      _displayedCustomers = filtered.sublist(startIndex, endIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Customer', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text('Admin', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(width: 8),
                  Icon(Icons.account_circle, size: 32, color: Colors.black87),
                  Icon(Icons.arrow_drop_down, color: Colors.grey),
                ],
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'dark_mode', child: Row(children: [Icon(Icons.dark_mode_outlined, color: Colors.black87, size: 20), SizedBox(width: 12), Text('Dark Mode')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'change_password', child: Row(children: [Icon(Icons.lock_outline, color: Colors.black87, size: 20), SizedBox(width: 12), Text('Change Password')])),
              const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.black87, size: 20), SizedBox(width: 12), Text('Logout')])),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
              }
            },
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'Customer', companyName: 'Demo Company Ltd'),
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
                    _fetchCustomers(); // Fetch data for the new tab
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? mdaPrimaryBlue : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? mdaPrimaryBlue : Colors.grey.shade300),
                      boxShadow: isSelected ? [BoxShadow(color: mdaPrimaryBlue.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))] : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _filters[index],
                          style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14),
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
              Center(child: _buildOldNewToggle()),
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
                fillColor: Colors.white,
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
                    child: Column(
                      children: [
                        Builder(
                          builder: (context) {
                            switch (_selectedFilterIndex) {
                              case 1:
                                return _buildAllotmentList();
                              case 2:
                                return const GroupingListView();
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

  // ==========================================
  // WIDGET BUILDERS
  // ==========================================

  Widget? _buildSmartFAB() {
    if (_selectedFilterIndex == 0) {
      return FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false, // User must tap the 'X' to close
            builder: (context) => const AddCustomerDialog(),
          );
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
        backgroundColor: _selectedAllotmentIndices.isEmpty ? mdaPrimaryBlue.withOpacity(0.4) : mdaPrimaryBlue,
        foregroundColor: Colors.white,
      );
    }
    if (_selectedFilterIndex == 2) {
      return FloatingActionButton.extended(
        onPressed: () {},
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
          _buildToggleBtn(
            'Old Customer',
            _customerType == 'Old',
            () {
              setState(() {
                _customerType = _customerType == 'Old' ? null : 'Old';
                _currentPage = 1;
              });
              _fetchCustomers(); 
            },
          ),
          _buildToggleBtn(
            'New Customer',
            _customerType == 'New',
            () {
              setState(() {
                _customerType = _customerType == 'New' ? null : 'New'; 
                _currentPage = 1;
              });
              _fetchCustomers(); 
            },
          ),
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
          color: isActive ? mdaPrimaryBlue : Colors.white,
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
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text('Showing $startEntry to $endEntry of $_totalEntries entries', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _currentPage > 1 ? () {
                  _currentPage--;
                  _applyFiltersAndPagination();
                } : null,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20), minimumSize: const Size(0, 36), side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Prev', style: TextStyle(color: Colors.black87)),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: mdaPrimaryBlue, borderRadius: BorderRadius.circular(8)),
                child: Text('$_currentPage', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _currentPage < (_totalEntries / _entriesPerPage).ceil() ? () {
                  _currentPage++;
                  _applyFiltersAndPagination();
                } : null,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20), minimumSize: const Size(0, 36), side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('Next', style: TextStyle(color: Colors.black87)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandardCustomerList() {
    if (_displayedCustomers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(child: Text('No customers found.', style: TextStyle(color: Colors.grey.shade600))),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _displayedCustomers.length,
      itemBuilder: (context, index) {
        final cust = _displayedCustomers[index];
        final String currentStatus = cust['status'] ?? '';
        final String orgName = cust['orgName'].toString().isNotEmpty ? cust['orgName'] : 'Unknown Organization';
        final String contactPerson = cust['contactPerson'].toString().isNotEmpty ? cust['contactPerson'] : 'No Contact';

        return Card(
          color: Colors.white,
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomerDetailScreen(
                    contactName: contactPerson,
                    orgName: orgName,
                    status: currentStatus,
                  ),
                ),
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
                            Text(contactPerson, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
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
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, color: mdaPrimaryBlue), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
                          const PopupMenuItem(value: 'merge', child: ListTile(leading: Icon(Icons.compress, color: Colors.orange), title: Text('Merge'), contentPadding: EdgeInsets.zero)),
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
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(child: Text('No customers found.', style: TextStyle(color: Colors.grey.shade600))),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _displayedCustomers.length,
      itemBuilder: (context, index) {
        final cust = _displayedCustomers[index];
        final bool isSelected = _selectedAllotmentIndices.contains(index);
        final String orgName = cust['orgName'].toString().isNotEmpty ? cust['orgName'] : 'Unknown Organization';
        final String contactPerson = cust['contactPerson'].toString().isNotEmpty ? cust['contactPerson'] : 'No Contact';
        final String phone = cust['phone'].toString().isNotEmpty ? cust['phone'] : '--';
        final String execName = cust['uName'].toString().isNotEmpty ? cust['uName'] : 'Not Assigned';
        final String product = cust['product'].toString().isNotEmpty ? cust['product'] : 'N/A';

        return Card(
          color: isSelected ? mdaPrimaryBlue.withOpacity(0.05) : Colors.white,
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSelected ? mdaPrimaryBlue.withOpacity(0.5) : Colors.transparent, width: 1)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => isSelected ? _selectedAllotmentIndices.remove(index) : _selectedAllotmentIndices.add(index)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: isSelected,
                    activeColor: mdaPrimaryBlue,
                    onChanged: (bool? value) => setState(() => value == true ? _selectedAllotmentIndices.add(index) : _selectedAllotmentIndices.remove(index)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(orgName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: mdaPrimaryBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(child: Text(contactPerson, style: TextStyle(color: Colors.grey[800], fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        if (phone != '--') ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(phone, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ],
                        if (!_showNotAlloted) ...[
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 1)),
                          Row(
                            children: [
                              Expanded(child: _buildDetailRow(Icons.assignment_ind, 'Executive', execName)),
                              Expanded(child: _buildDetailRow(Icons.inventory_2, 'Product', product)),
                            ],
                          ),
                        ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // MODALS
  // ==========================================
  void _showAllotToDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                      child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: 'Admin', items: <String>['Admin', 'Faizi', 'Mudit'].map((String value) { return DropdownMenuItem<String>(value: value, child: Text(value)); }).toList(), onChanged: (_) {})),
                    ),
                    const SizedBox(height: 20),
                    const Text('Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: 'Accounting Software', items: <String>['Accounting Software', 'CRM Tool', 'GST Tool'].map((String value) { return DropdownMenuItem<String>(value: value, child: Text(value)); }).toList(), onChanged: (_) {})),
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
                    TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(foregroundColor: Colors.grey[600]), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: () { Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: mdaPrimaryBlue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))), child: const Text('Save')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}