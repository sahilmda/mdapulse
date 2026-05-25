// File: lib/features/task_management/data/models/task_model.dart

class CallDetail {
  final String date;
  final String remark;
  final String status;

  CallDetail({required this.date, required this.remark, required this.status});
}

class TaskModel {
  final String sno;      // u_id — used as uid in fillCallDetail
  final String sno14;    // P_CID_14.sno — used as sno_14 in FillEditModal
  final String sno11;    // P_CID_11.sno — customer sno for CustomerListBySno
  final String custId11; // CustID11 — MDA customer ID, used to load MDA firm detail
  final String clientPrefix;
  final String clientName;
  final String activity;
  final String executive;
  final String firstDate; // extracted from remark prefix "dd-mm-yyyy --- ..."
  final String nextDate;
  final String status;
  final String callStatus; // 'Pending' (Ongoing) or 'Close' (Closed) from API
  final String product;
  final String remark;
  final List<CallDetail> callDetails;
  final bool isApprovalPending; // arr1[20]
  final String nDateTime;       // arr1[21] — due date/time when set

  TaskModel({
    required this.sno,
    this.sno14 = '',
    this.sno11 = '',
    this.custId11 = '',
    required this.clientPrefix,
    required this.clientName,
    required this.activity,
    required this.executive,
    this.firstDate = '',
    required this.nextDate,
    required this.status,
    required this.callStatus,
    this.product = '',
    this.remark = '',
    this.callDetails = const [],
    this.isApprovalPending = false,
    this.nDateTime = '',
  });

  bool get isProspect => clientPrefix.toUpperCase().contains('P');

  // Maps API values 'Pending'/'Close' to display labels
  String get displayCallStatus {
    if (callStatus.toLowerCase() == 'pending') return 'Ongoing';
    if (callStatus.toLowerCase() == 'close') return 'Closed';
    return callStatus;
  }
}
