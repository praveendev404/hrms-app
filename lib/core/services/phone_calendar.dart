import 'package:add_2_calendar/add_2_calendar.dart';

/// Hands an all-day event to the phone's own calendar app, which shows it for the
/// user to confirm. Nothing is written without that confirmation, and no permission is needed.
Future<bool> addAllDayToPhoneCalendar({
  required String title,
  required DateTime from,
  DateTime? to,
  String? description,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime((to ?? from).year, (to ?? from).month, (to ?? from).day);
  return Add2Calendar.addEvent2Cal(Event(
    title: title,
    description: description,
    startDate: start,
    endDate: end.add(const Duration(days: 1)).subtract(const Duration(minutes: 1)),
    allDay: true,
  ));
}
