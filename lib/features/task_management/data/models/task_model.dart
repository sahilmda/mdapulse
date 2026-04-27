// File: lib/features/task_management/data/models/task_model.dart

class CallDetail {
  final String date;
  final String remark;
  final String status;

  CallDetail({required this.date, required this.remark, required this.status});
}

class TaskModel {
  final String clientPrefix;
  final String clientName;
  final String activity;
  final String executive;
  final String nextDate; // Replaced firstDate/dueDate to match Calling.cs
  final String status; // e.g., 'Measurement taken', 'Finalisation'
  final String callStatus; // e.g., 'Ongoing', 'Closed'
  final List<CallDetail> callDetails;

  TaskModel({
    required this.clientPrefix,
    required this.clientName,
    required this.activity,
    required this.executive,
    required this.nextDate,
    required this.status,
    required this.callStatus,
    this.callDetails = const [],
  });

  bool get isProspect => clientPrefix.toUpperCase().contains('P');
}
