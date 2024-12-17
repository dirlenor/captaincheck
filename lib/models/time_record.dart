class TimeRecord {
  final String userId;
  final DateTime workDate;
  final String shiftType;
  final double workHours;
  final double otHours;
  final double totalAmount;
  final DateTime createdAt;

  TimeRecord({
    required this.userId,
    required this.workDate,
    required this.shiftType,
    required this.workHours,
    required this.otHours,
    required this.totalAmount,
    required this.createdAt,
  });

  factory TimeRecord.fromJson(Map<String, dynamic> json) {
    return TimeRecord(
      userId: json['user_id'] as String,
      workDate: DateTime.parse(json['work_date'] as String),
      shiftType: json['shift_type'] as String,
      workHours: (json['work_hours'] as num).toDouble(),
      otHours: (json['ot_hours'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'work_date': workDate.toIso8601String(),
    'shift_type': shiftType,
    'work_hours': workHours,
    'ot_hours': otHours,
    'total_amount': totalAmount,
    'created_at': createdAt.toIso8601String(),
  };
} 