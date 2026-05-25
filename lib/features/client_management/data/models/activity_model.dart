// File: lib/features/client_management/data/models/activity_model.dart

class ActivityRemark {
  final String date;
  final String remarkText;
  final String status;

  ActivityRemark({
    required this.date,
    required this.remarkText,
    required this.status,
  });
}

class ActivityLog {
  final String activityType;
  final String executive;
  final String nextDate;
  final String statusBadge;
  final String progress;
  final List<ActivityRemark> remarks;
  final String sno;
  final String uid;
  final String product;

  ActivityLog({
    required this.activityType,
    required this.executive,
    required this.nextDate,
    required this.statusBadge,
    required this.progress,
    required this.remarks,
    this.sno = '',
    this.uid = '',
    this.product = '',
  });
}
