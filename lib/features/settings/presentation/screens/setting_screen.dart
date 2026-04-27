// File: lib/features/settings/presentation/screens/setting_screen.dart

import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_drawer.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  int _selectedTabIndex = 0;

  final List<Map<String, dynamic>> _tabs = [
    {'title': 'Call Status', 'icon': Icons.phone_in_talk},
    {'title': 'Products', 'icon': Icons.shopping_cart},
    {'title': 'Activities', 'icon': Icons.task},
    {'title': 'Categories', 'icon': Icons.category},
    {'title': 'Sources', 'icon': Icons.link},
    {'title': 'Theme', 'icon': Icons.palette},
  ];

  // Mock Data
  final List<Map<String, dynamic>> _mockStatuses = [
    {
      'name': 'Measurement taken',
      'type': 'Pending',
      'color': Colors.amber.shade100,
    },
    {'name': 'Finalisation', 'type': 'Close', 'color': Colors.green.shade100},
    {'name': 'Not Interested', 'type': 'Close', 'color': Colors.red.shade100},
  ];

  final List<String> _mockProducts = [
    'Accounting Software',
    'GST Tool',
    'CRM Tool',
  ];
  final List<String> _mockActivities = ['Call', 'Visit', 'Email'];
  final List<String> _mockCategories = ['Retail', 'Manufacturing', 'Service'];
  final List<String> _mockSources = ['Google', 'Reference', 'Facebook'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Settings',
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
        currentRoute: 'Settings',
        companyName: 'Demo Company Ltd',
      ),
      floatingActionButton: _buildSmartFAB(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. DASHBOARD GRID TABS (2 Columns x 3 Rows)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio:
                    2.6, // Makes the cards rectangular like buttons
              ),
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final bool isSelected = _selectedTabIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTabIndex = index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? mdaPrimaryBlue : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? mdaPrimaryBlue
                            : Colors.grey.shade300,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: mdaPrimaryBlue.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _tabs[index]['icon'],
                          color: isSelected ? Colors.white : mdaPrimaryBlue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _tabs[index]['title'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // 2. DYNAMIC CONTENT AREA
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildTabContent(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGET BUILDERS
  // ==========================================

  Widget? _buildSmartFAB() {
    if (_selectedTabIndex == 5) return null; // No FAB for Theme settings

    String label = 'Add ';
    IconData icon = Icons.add;
    VoidCallback action = () =>
        _showGenericAddDialog(_tabs[_selectedTabIndex]['title']);

    if (_selectedTabIndex == 0) {
      label += 'Status';
      action = _showAddStatusDialog;
    } else if (_selectedTabIndex == 1) {
      label += 'Product';
    } else if (_selectedTabIndex == 2) {
      label += 'Activity';
    } else if (_selectedTabIndex == 3) {
      label += 'Category';
    } else if (_selectedTabIndex == 4) {
      label += 'Source';
    }

    return FloatingActionButton.extended(
      onPressed: action,
      icon: Icon(icon),
      label: Text(label),
      backgroundColor: mdaPrimaryBlue,
      foregroundColor: Colors.white,
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildStatusList();
      case 1:
        return _buildGenericList(_mockProducts, showMergeButton: true);
      case 2:
        return _buildGenericList(_mockActivities);
      case 3:
        return _buildGenericList(_mockCategories);
      case 4:
        return _buildGenericList(_mockSources);
      case 5:
        return _buildThemeSettings();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusList() {
    return ListView.builder(
      itemCount: _mockStatuses.length,
      itemBuilder: (context, index) {
        final status = _mockStatuses[index];
        return Card(
          color: Colors.white,
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: status['color'], radius: 16),
            title: Text(
              status['name'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Type: ${status['type']}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            trailing: _buildActionMenu(),
          ),
        );
      },
    );
  }

  Widget _buildGenericList(List<String> items, {bool showMergeButton = false}) {
    return Column(
      children: [
        if (showMergeButton)
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () {}, // Merge logic placeholder
              icon: const Icon(Icons.merge_type, size: 18),
              label: const Text('Merge Products'),
              style: OutlinedButton.styleFrom(
                foregroundColor: mdaPrimaryBlue,
                side: const BorderSide(color: mdaPrimaryBlue),
              ),
            ),
          ),
        if (showMergeButton) const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Card(
                color: Colors.white,
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  title: Text(
                    items[index],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: _buildActionMenu(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionMenu() {
    return PopupMenuButton<String>(
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
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSettings() {
    return SingleChildScrollView(
      child: Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Theme Customization',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: mdaPrimaryBlue,
                ),
              ),
              const Divider(height: 30),

              const Text(
                'Appearance Mode',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.dark_mode, color: Colors.black87),
                label: const Text(
                  'Toggle Dark Mode',
                  style: TextStyle(color: Colors.black87),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size(double.infinity, 0),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Sidebar Color',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildColorSwatch(mdaPrimaryBlue, isActive: true),
                  _buildColorSwatch(Colors.green),
                  _buildColorSwatch(Colors.red),
                  _buildColorSwatch(Colors.black87),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Top Bar Color',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildColorSwatch(
                    Colors.white,
                    isActive: true,
                    isBordered: true,
                  ),
                  _buildColorSwatch(Colors.lightBlue),
                  _buildColorSwatch(Colors.amber),
                  _buildColorSwatch(Colors.black87),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorSwatch(
    Color color, {
    bool isActive = false,
    bool isBordered = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? Colors.black
              : (isBordered ? Colors.grey.shade300 : Colors.transparent),
          width: isActive ? 2 : 1,
        ),
      ),
      child: isActive
          ? Icon(
              Icons.check,
              color: color == Colors.white ? Colors.black : Colors.white,
            )
          : null,
    );
  }

  // ==========================================
  // MODALS
  // ==========================================

  void _showAddStatusDialog() {
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
                      'Add Status',
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
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModalTextField('Status Name'),
                    const SizedBox(height: 16),
                    _buildModalDropdown('Close / Pending', [
                      'Select',
                      'Close',
                      'Pending',
                    ]),
                    const SizedBox(height: 16),
                    _buildModalDropdown('Colour', [
                      'Select',
                      'Yellow',
                      'Green',
                      'Red',
                    ]),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mdaPrimaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGenericAddDialog(String itemType) {
    final String singularName = itemType.endsWith('ies')
        ? itemType.replaceFirst('ies', 'y')
        : itemType.substring(0, itemType.length - 1);

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
                    Text(
                      'Add $singularName',
                      style: const TextStyle(
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
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildModalTextField('$singularName Name'),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mdaPrimaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModalTextField(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModalDropdown(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: items[0],
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      ],
    );
  }
}
