import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/checkin_provider.dart';

/// Hero card for the day: live clock, status, working-hours timer and one big action.
class CheckInCard extends StatefulWidget {
  final CheckInState checkInState;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  const CheckInCard({
    super.key,
    required this.checkInState,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  @override
  State<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<CheckInCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // One tick per second drives both the clock and the working-hours counter.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.checkInState;
    final now = DateTime.now();
    final checkedIn = s.isCheckedIn;

    final gradient = checkedIn
        ? const [Color(0xFF0F9D7A), Color(0xFF16B88F)]
        : const [AppColors.primaryDark, AppColors.primary];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: gradient.first.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(checkedIn ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(checkedIn ? 'Working' : 'Not checked in',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
              const Spacer(),
              Text(DateFormat('EEE, d MMM').format(now),
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            DateFormat('hh:mm').format(now),
            style: const TextStyle(
                color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800, height: 1.0, letterSpacing: -1),
          ),
          Text(DateFormat('a').format(now), style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
          if (checkedIn && s.checkInTime != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              _Metric(label: 'Checked in', value: DateFormat('hh:mm a').format(s.checkInTime!)),
              const SizedBox(width: 12),
              _Metric(label: 'Working hours', value: s.formattedElapsedTime),
            ]),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: s.isLoading ? null : (checkedIn ? widget.onCheckOut : widget.onCheckIn),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: checkedIn ? const Color(0xFFD64545) : AppColors.primaryDark,
                disabledBackgroundColor: Colors.white70,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: s.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Icon(checkedIn ? Icons.logout_rounded : Icons.fingerprint_rounded, size: 24),
              label: Text(
                s.isLoading ? 'Please wait…' : (checkedIn ? 'Check out' : 'Check in'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11.5)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
