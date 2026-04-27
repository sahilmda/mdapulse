// File: lib/features/employee_management/presentation/screens/employee_screen.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_drawer.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({super.key});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  int _selectedTabIndex = 0; // 0: Active, 1: Inactive, 2: Teams

  // Pagination State
  int _currentPage = 1;
  final int _totalEntries = 45; // Mock total for demo
  final int _entriesPerPage = 10;

  final List<Map<String, dynamic>> _mockEmployees = [
    {
      'name': 'Admin User',
      'mobile': '9876543210',
      'email': 'admin@mda.com',
      'grade': 'A+',
      'isActive': true,
      'initials': 'AD',
    },
    {
      'name': 'Faizi',
      'mobile': '9876543211',
      'email': 'faizi@mda.com',
      'grade': 'B',
      'isActive': true,
      'initials': 'FZ',
    },
    {
      'name': 'Mudit',
      'mobile': '9876543212',
      'email': 'mudit@mda.com',
      'grade': 'B',
      'isActive': false,
      'initials': 'MD',
    },
  ];

  final List<Map<String, dynamic>> _mockTeams = [
    {
      'teamName': 'Alpha Squad',
      'members': 'Admin User, Faizi',
      'status': 'Pending',
    },
    {'teamName': 'Beta Team', 'members': 'Mudit', 'status': 'Closed'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Employee Management',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(
        currentRoute: 'Employee',
        companyName: 'Demo Company Ltd',
      ),
      floatingActionButton: _buildSmartFAB(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP TABS (Active / Inactive / Teams)
            _buildTopTabs(),
            const SizedBox(height: 16),

            // 2. SEARCH BAR
            TextField(
              decoration: InputDecoration(
                hintText: _selectedTabIndex == 2
                    ? 'Search Teams...'
                    : 'Search Employees...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // 3. MAIN LIST VIEW & PAGINATION
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_selectedTabIndex == 0 || _selectedTabIndex == 1)
                      _buildEmployeeList(),
                    if (_selectedTabIndex == 2) _buildTeamList(),

                    // NEW: Consistent Pagination Footer
                    _buildPaginationFooter(),

                    const SizedBox(height: 80), // Clearance for FAB
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
    if (_selectedTabIndex == 0 || _selectedTabIndex == 1) {
      return FloatingActionButton.extended(
        onPressed: () => _showAddEmployeeDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
        backgroundColor: mdaPrimaryBlue,
        foregroundColor: Colors.white,
      );
    }
    if (_selectedTabIndex == 2) {
      return FloatingActionButton.extended(
        onPressed: () => _showAddTeamDialog(),
        icon: const Icon(Icons.group_add),
        label: const Text('Add Team'),
        backgroundColor: mdaPrimaryBlue,
        foregroundColor: Colors.white,
      );
    }
    return null;
  }

  Widget _buildTopTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabItem('Active', Icons.verified_user, 0)),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(child: _buildTabItem('Inactive', Icons.no_accounts, 1)),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          Expanded(child: _buildTabItem('Teams', Icons.groups, 2)),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, IconData icon, int index) {
    final bool isActive = _selectedTabIndex == index;
    return InkWell(
      // Reset pagination when switching tabs
      onTap: () => setState(() {
        _selectedTabIndex = index;
        _currentPage = 1;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? mdaPrimaryBlue.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: index == 0 ? const Radius.circular(8) : Radius.zero,
            right: index == 2 ? const Radius.circular(8) : Radius.zero,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? mdaPrimaryBlue : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isActive ? mdaPrimaryBlue : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Shared Pagination Footer
  Widget _buildPaginationFooter() {
    int startEntry = ((_currentPage - 1) * _entriesPerPage) + 1;
    int endEntry = _currentPage * _entriesPerPage;
    if (endEntry > _totalEntries) endEntry = _totalEntries;
    if (_totalEntries == 0) {
      startEntry = 0;
      endEntry = 0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Showing $startEntry to $endEntry of $_totalEntries entries',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  minimumSize: const Size(0, 36),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Prev',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: mdaPrimaryBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_currentPage',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => setState(() => _currentPage++),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  minimumSize: const Size(0, 36),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Next',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    final bool showActive = _selectedTabIndex == 0;
    final filteredEmployees = _mockEmployees
        .where((emp) => emp['isActive'] == showActive)
        .toList();

    if (filteredEmployees.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text(
          'No employees found.',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredEmployees.length,
      itemBuilder: (context, index) {
        final emp = filteredEmployees[index];
        return Card(
          color: Colors.white,
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: mdaPrimaryBlue.withOpacity(0.1),
                  child: Text(
                    emp['initials'],
                    style: const TextStyle(
                      color: mdaPrimaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            emp['mobile'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            emp['email'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Grade ${emp['grade']}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[900],
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit, color: mdaPrimaryBlue),
                            title: Text('Edit'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: ListTile(
                            leading: Icon(
                              showActive ? Icons.person_off : Icons.person_add,
                              color: showActive ? Colors.red : Colors.green,
                            ),
                            title: Text(showActive ? 'Deactivate' : 'Activate'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeamList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _mockTeams.length,
      itemBuilder: (context, index) {
        final team = _mockTeams[index];
        return Card(
          color: Colors.white,
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      team['teamName'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: mdaPrimaryBlue,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        team['status'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(height: 1),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        team['members'],
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                      ),
                    ),
                    InkWell(
                      onTap: () {},
                      child: const Icon(
                        Icons.edit,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () {},
                      child: const Icon(
                        Icons.delete,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // MODALS
  // ==========================================

  void _showAddEmployeeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: mdaPrimaryBlue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Employee',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildTextField('Name', Icons.person),
                  const SizedBox(height: 16),
                  _buildTextField('Password', Icons.lock, isPassword: true),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Mobile', Icons.phone)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField('Initials', Icons.short_text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Email Address', Icons.email),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildDropdown('Grade')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDropdown('Department')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown('Reporting To'),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text(
                      'Auto allot customer when adding new',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: true,
                    activeColor: mdaPrimaryBlue,
                    onChanged: (val) {},
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mdaPrimaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save Employee',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTeamDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: mdaPrimaryBlue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Team',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildTextField('Team Name', Icons.groups),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildDropdown('Linked Status')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDropdown('Next Status')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select Team Members',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ..._mockEmployees.map(
                    (emp) => CheckboxListTile(
                      title: Text(emp['name']),
                      subtitle: Text(emp['grade']),
                      value: false,
                      activeColor: mdaPrimaryBlue,
                      onChanged: (val) {},
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mdaPrimaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save Team',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon, {
    bool isPassword = false,
  }) {
    return TextField(
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDropdown(String label) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: const [DropdownMenuItem(value: '1', child: Text('Option 1'))],
      onChanged: (val) {},
    );
  }
}
