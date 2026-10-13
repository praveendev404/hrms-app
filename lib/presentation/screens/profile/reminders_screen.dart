import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/services/reminder_service.dart';
import '../../widgets/common/ui_helpers.dart';

/// Phone-only reminders: check-in / check-out on weekdays and an alert for new notifications.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  ReminderSettings? _s;

  @override
  void initState() {
    super.initState();
    ReminderService.load().then((v) {
      if (mounted) setState(() => _s = v);
    });
  }

  Future<void> _save(ReminderSettings next) async {
    // Switching anything on needs the notification permission first.
    final turningOn = (next.checkIn && !_s!.checkIn) || (next.checkOut && !_s!.checkOut) || (next.alerts && !_s!.alerts);
    if (turningOn && !await ReminderService.requestPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Allow notifications for HRMS in the phone settings to use reminders.'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    setState(() => _s = next);
    try {
      await ReminderService.apply(next);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not set the reminder: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _pick(bool isIn) async {
    final cur = isIn ? _s!.inTime : _s!.outTime;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur.hour, minute: cur.minute));
    if (t == null) return;
    final v = TimeOfDayLite(t.hour, t.minute);
    await _save(isIn ? _s!.copyWith(inTime: v) : _s!.copyWith(outTime: v));
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Reminders & alerts')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const SectionHeader('Attendance reminders'),
              const SizedBox(height: 6),
              SurfaceCard(
                child: Column(children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Check-in reminder'),
                    subtitle: Text('Monday to Friday at ${s.inTime.label}'),
                    value: s.checkIn,
                    onChanged: (v) => _save(s.copyWith(checkIn: v)),
                  ),
                  if (s.checkIn)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _pick(true),
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('Change time'),
                      ),
                    ),
                  const Divider(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Check-out reminder'),
                    subtitle: Text('Monday to Friday at ${s.outTime.label}'),
                    value: s.checkOut,
                    onChanged: (v) => _save(s.copyWith(checkOut: v)),
                  ),
                  if (s.checkOut)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _pick(false),
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('Change time'),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 18),
              const SectionHeader('Notifications'),
              const SizedBox(height: 6),
              SurfaceCard(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Alert me about new notifications'),
                  subtitle: Text(Platform.isAndroid
                      ? 'The app checks for new approvals, leave decisions and announcements about every 15 minutes, even when closed.'
                      : 'Only available on Android.'),
                  value: s.alerts,
                  onChanged: Platform.isAndroid ? (v) => _save(s.copyWith(alerts: v)) : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Reminders can arrive a few minutes late when the phone is saving battery, and they do not know about your holidays or leave. They stop when you sign out.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ]),
    );
  }
}
