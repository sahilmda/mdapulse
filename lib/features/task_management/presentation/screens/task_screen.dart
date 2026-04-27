// File: lib/features/task_management/presentation/screens/task_screen.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_drawer.dart';
import 'package:mda_crm/features/task_management/data/models/task_model.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  // Main Filter State
  int _selectedFilterIndex = 0;

  // Sub-Filter State (For 'All tasks' tab)
  String _selectedSubFilter = 'All';

  // Pagination State
  int _currentPage = 1;
  final int _entriesPerPage = 10;

  // Column Visibility State
  final Map<String, bool> _columnVisibility = {
    'Client': true,
    'Activity': true,
    'Executive': true,
    'Next Date': true,
    'Status': true,
    'Product': true,
    'Remark': true,
  };

  final List<Map<String, dynamic>> _filters = [
    {'title': 'Overdue', 'icon': Icons.error_outline},
    {'title': 'Due Today', 'icon': Icons.sensors},
    {'title': 'Due later', 'icon': Icons.calendar_today},
    {'title': 'All tasks', 'icon': Icons.check_circle},
  ];

  // Updated Mock Data to match Calling.aspx.cs columns
  final List<TaskModel> _mockTasks = [
    TaskModel(
      clientPrefix: 'P - ',
      clientName: '--',
      activity: 'Sale',
      executive: 'Admin',
      nextDate: '28-03-2026',
      status: 'will be decide',
      callStatus: 'Ongoing',
      callDetails: [
        CallDetail(
          date: '27-03-2026 02:33 PM',
          remark: 'customer id entry remaks',
          status: 'will be decide',
        ),
        CallDetail(
          date: '29-01-2026 05:06 PM',
          remark: 'new remark add for this customer',
          status: 'will be decide',
        ),
      ],
    ),
    TaskModel(
      clientPrefix: 'P - ',
      clientName: 'abc',
      activity: 'Complaint',
      executive: 'Admin',
      nextDate: '19-04-2026',
      status: 'Pending',
      callStatus: 'Ongoing',
    ),
    TaskModel(
      clientPrefix: 'C - ',
      clientName: 'Abhinay pandey',
      activity: 'Complaint',
      executive: 'Faizi',
      nextDate: '10-04-2026',
      status: 'Measurement taken',
      callStatus: 'Ongoing',
    ),
    TaskModel(
      clientPrefix: 'C - ',
      clientName: 'Zeeshan Ansari',
      activity: 'Sale',
      executive: 'Mudit',
      nextDate: '09-04-2026',
      status: 'Finalisation',
      callStatus: 'Closed',
    ),
  ];

  List<TaskModel> get _filteredTasks {
    if (_selectedFilterIndex == 3 && _selectedSubFilter != 'All') {
      return _mockTasks.where((t) => t.callStatus == _selectedSubFilter).toList();
    }
    return _mockTasks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Task Management',
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
        currentRoute: 'Tasks',
        companyName: 'Demo Company Ltd',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Add Ticket'),
        backgroundColor: mdaPrimaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. PINNED DASHBOARD CARDS
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.2,
              ),
              itemCount: _filters.length,
              itemBuilder: (context, index) => _buildDashboardFilterCard(index),
            ),
            const SizedBox(height: 16),

            // 2. DYNAMIC ONGOING/CLOSED SUB-FILTERS
            if (_selectedFilterIndex == 3) ...[
              Center(child: _buildSubFilters()),
              const SizedBox(height: 16),
            ],

            // 3. SEARCH & CHANGE COLUMNS BUTTON
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search...',
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
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => _showChangeColumnsModal(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    side: const BorderSide(color: mdaPrimaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Icon(Icons.view_column, color: mdaPrimaryBlue),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. SCROLLABLE LIST & PAGINATION
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredTasks.length,
                      itemBuilder: (context, index) =>
                          _buildTaskCard(_filteredTasks[index]),
                    ),
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

  Widget _buildDashboardFilterCard(int index) {
    final bool isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedFilterIndex = index;
        _currentPage = 1;
        _selectedSubFilter = 'All';
      }),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? mdaPrimaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? mdaPrimaryBlue : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: mdaPrimaryBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _filters[index]['icon'],
              color: isSelected ? Colors.white : Colors.black87,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              _filters[index]['title'],
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubFilters() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: mdaPrimaryBlue),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleBtn(
            'All',
            _selectedSubFilter == 'All',
            () => setState(() {
              _selectedSubFilter = 'All';
              _currentPage = 1;
            }),
            isFirst: true,
          ),
          _buildToggleBtn(
            'Ongoing',
            _selectedSubFilter == 'Ongoing',
            () => setState(() {
              _selectedSubFilter = 'Ongoing';
              _currentPage = 1;
            }),
          ),
          _buildToggleBtn(
            'Closed',
            _selectedSubFilter == 'Closed',
            () => setState(() {
              _selectedSubFilter = 'Closed';
              _currentPage = 1;
            }),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(
    String text,
    bool isActive,
    VoidCallback onTap, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? mdaPrimaryBlue : Colors.white,
          borderRadius: BorderRadius.horizontal(
            left: isFirst ? const Radius.circular(5) : Radius.zero,
            right: isLast ? const Radius.circular(5) : Radius.zero,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : mdaPrimaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final bool isClosed = task.callStatus == 'Closed';

    return Card(
      color: Colors.white,
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showCallDetailsDialog(context, task),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER ROW
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          task.clientPrefix,
                          style: TextStyle(
                            color: task.isProspect
                                ? Colors.red
                                : mdaPrimaryBlue,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            task.clientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ONGOING / CLOSED BADGE
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isClosed ? Colors.grey[200] : Colors.green[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      task.callStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isClosed ? Colors.grey[700] : Colors.green[800],
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(height: 1),
              ),
              // DATA ROWS (Aligned with Calling.aspx)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          Icons.assignment,
                          'Activity',
                          task.activity,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.person,
                          'Executive',
                          task.executive,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow(
                          Icons.event_available,
                          'Next Date',
                          task.nextDate,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          Icons.info_outline,
                          'Status',
                          task.status,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationFooter() {
    final int totalEntries = _filteredTasks.length;
    int startEntry = ((_currentPage - 1) * _entriesPerPage) + 1;
    int endEntry = _currentPage * _entriesPerPage;
    if (endEntry > totalEntries) endEntry = totalEntries;
    if (totalEntries == 0) {
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
            'Showing $startEntry to $endEntry of $totalEntries entries',
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
                onPressed: _currentPage < (_filteredTasks.length / _entriesPerPage).ceil()
                    ? () => setState(() => _currentPage++)
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

  // ==========================================
  // MODALS
  // ==========================================

  void _showCallDetailsDialog(BuildContext context, TaskModel task) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: mdaPrimaryBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Call Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              if (task.callDetails.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'No call details found.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: task.callDetails.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final detail = task.callDetails[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                detail.date,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  detail.status,
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            detail.remark,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangeColumnsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Change Columns',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text(
                      'Select which columns to display or rename them:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: _columnVisibility.keys.map((col) =>
                          _buildColumnSettingRow(col, setModalState)
                        ).toList(),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {}); // refresh main screen with updated visibility
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mdaPrimaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Save Columns',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColumnSettingRow(String columnName, StateSetter setModalState) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Checkbox(
            value: _columnVisibility[columnName] ?? true,
            activeColor: mdaPrimaryBlue,
            onChanged: (val) {
              setModalState(() => _columnVisibility[columnName] = val ?? true);
            },
          ),
          SizedBox(
            width: 80,
            child: Text(
              columnName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rename $columnName...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
