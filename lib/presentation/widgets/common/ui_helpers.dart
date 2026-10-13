import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/leave_models.dart';

/// "2026-10-13" -> "13 Oct". Falls back to the raw text when unparseable.
String formatYmd(String? ymd, {bool withYear = false}) {
  final d = DateTime.tryParse(ymd ?? '');
  if (d == null) return ymd ?? '';
  return DateFormat(withYear ? 'd MMM yyyy' : 'd MMM').format(d);
}

String formatDateRange(String from, String to) =>
    from == to ? formatYmd(from, withYear: true) : '${formatYmd(from)} - ${formatYmd(to, withYear: true)}';

String formatDateTimeShort(DateTime? d) => d == null ? '' : DateFormat('d MMM, h:mm a').format(d);

Color leaveStatusColor(int statusId) {
  switch (statusId) {
    case LeaveStatus.approved:
      return AppColors.success;
    case LeaveStatus.rejected:
      return AppColors.error;
    case LeaveStatus.cancelled:
      return Colors.grey;
    default:
      return AppColors.warning;
  }
}

/// Small coloured status pill.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// White rounded card used across dashboard widgets and list rows.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const SurfaceCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEF1F6)),
            boxShadow: [
              BoxShadow(color: const Color(0xFF1E293B).withOpacity(0.035), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Round avatar with initials (falls back to '?').
class UserAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const UserAvatar({super.key, required this.name, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.length == 1 ? parts.first[0] : parts.first[0] + parts.last[0]).toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryContainer,
      child: Text(initials,
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: radius * 0.8)),
    );
  }
}

/// Rounded-square icon on a tinted background (used by tiles and rows).
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge({super.key, required this.icon, required this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(size * 0.32)),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight)),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
