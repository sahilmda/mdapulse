// File: lib/features/client_management/presentation/widgets/grouping_list_view.dart

import 'package:flutter/material.dart';
import 'package:mda_crm/features/client_management/data/models/group_model.dart';

const Color mdaPrimaryBlue = Color(0xFF0257E6);

class GroupingListView extends StatefulWidget {
  const GroupingListView({super.key});

  @override
  State<GroupingListView> createState() => _GroupingListViewState();
}

class _GroupingListViewState extends State<GroupingListView> {
  int _currentPage = 1;
  final int _totalEntries = 2;
  final int _entriesPerPage = 10;

  // Mock data representing the "Architect" grouping logic from your database
  final List<CustomerGroup> _groups = [
    CustomerGroup(
      groupName: 'Demo Architect',
      city: 'AMRAVATI',
      mobileNumber: '9797979797',
      members: [],
    ),
    CustomerGroup(
      groupName: 'Group Leader 1',
      city: 'ALMORA',
      mobileNumber: '8787878787',
      members: [
        GroupMember(
          orgName: 'Organization Alpha',
          contactPerson: 'John Doe',
          phone: '9632581475',
          email: '--',
          lastContact: '06-04-2026',
          status: 'Complete',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _groups.length,
          itemBuilder: (context, index) {
            return GroupCard(group: _groups[index]);
          },
        ),
        _buildPaginationFooter(),
      ],
    );
  }

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
}

class GroupCard extends StatefulWidget {
  final CustomerGroup group;
  const GroupCard({super.key, required this.group});
  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final bool hasMembers = widget.group.members.isNotEmpty;

    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PARENT ROW (Architect/Group Leader)
          InkWell(
            onTap: hasMembers
                ? () => setState(() => _isExpanded = !_isExpanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                top: 12.0,
                bottom: 12.0,
                right: 4.0,
              ),
              child: Row(
                children: [
                  Icon(
                    hasMembers
                        ? (_isExpanded
                              ? Icons.arrow_drop_down
                              : Icons.play_arrow)
                        : Icons.play_arrow_outlined,
                    color: hasMembers
                        ? (_isExpanded ? Colors.red : Colors.grey[700])
                        : Colors.grey[300],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.groupName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: mdaPrimaryBlue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_city,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.group.city,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    widget.group.mobileNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                      fontSize: 13,
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
                          title: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // CHILD ROWS (Nested Customers)
          if (_isExpanded && hasMembers)
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.only(
                left: 48.0,
                right: 16.0,
                top: 12.0,
                bottom: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.group.members
                    .map(
                      (member) => Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    member.orgName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        member.status == 'Complete' ||
                                            member.status == 'Work Done'
                                        ? Colors.green[100]
                                        : Colors.amber[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    member.status,
                                    style: TextStyle(
                                      color:
                                          member.status == 'Complete' ||
                                              member.status == 'Work Done'
                                          ? Colors.green[800]
                                          : Colors.black87,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    member.contactPerson,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (member.phone != '--' ||
                                member.email != '--') ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (member.phone != '--') ...[
                                    Icon(
                                      Icons.phone,
                                      size: 14,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      member.phone,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  if (member.email != '--') ...[
                                    Icon(
                                      Icons.email,
                                      size: 14,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        member.email,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
