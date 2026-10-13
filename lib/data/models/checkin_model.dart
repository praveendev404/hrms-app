/// Web check-in models

class CheckInRequest {
  final String date;
  final int hours;
  final int minutes;
  final int seconds;
  final int punchInTypeId;
  final double? latitude;
  final double? longitude;

  CheckInRequest({
    required this.date,
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.punchInTypeId,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'hours': hours,
      'minutes': minutes,
      'seconds': seconds,
      'punchInTypeId': punchInTypeId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }
}

class CheckInResponse {
  final int empAttId;
  final int hour;
  final int minute;
  final int second;
  final int punchTypeId;
  final String date;

  CheckInResponse({
    required this.empAttId,
    required this.hour,
    required this.minute,
    required this.second,
    required this.punchTypeId,
    required this.date,
  });

  factory CheckInResponse.fromJson(Map<String, dynamic> json) {
    return CheckInResponse(
      empAttId: json['empAttId'] as int,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      second: json['second'] as int,
      punchTypeId: json['punchTypeId'] as int,
      date: json['date'] as String,
    );
  }

  /// Check if this is a check-in (punch type 1) or check-out (punch type 2)
  bool get isCheckedIn => punchTypeId == 1;

  /// Get the full date-time from date and time components
  DateTime get dateTime {
    final dateParts = date.split('-');
    return DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
      hour,
      minute,
      second,
    );
  }
}
