// File: lib/features/client_management/data/models/group_model.dart

class GroupMember {
  final String orgName;
  final String contactPerson;
  final String phone;
  final String email;
  final String lastContact;
  final String status;

  GroupMember({
    required this.orgName,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.lastContact,
    required this.status,
  });
}

class CustomerGroup {
  final String snoArch;
  final String groupName;
  final String city;
  final String mobileNumber;
  final List<GroupMember> members;

  CustomerGroup({
    required this.snoArch,
    required this.groupName,
    required this.city,
    required this.mobileNumber,
    required this.members,
  });
}
