import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

final _money = NumberFormat.decimalPatternDigits(locale: 'en_IN', decimalDigits: 0);

/// Recruiter view: open positions with their candidates, and offers. Read-only on mobile;
/// scheduling, moving stages and creating offers stay on the web.
class RecruitmentScreen extends ConsumerWidget {
  final int initialTab;
  const RecruitmentScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Recruitment'),
          bottom: const TabBar(tabs: [Tab(text: 'Openings'), Tab(text: 'Offers')]),
        ),
        body: const TabBarView(children: [_Openings(), _Offers()]),
      ),
    );
  }
}

class _Openings extends ConsumerWidget {
  const _Openings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(jobOpeningsProvider);
        await ref.read(jobOpeningsProvider.future);
      },
      child: AsyncValueView<List<JobOpening>>(
        value: ref.watch(jobOpeningsProvider),
        onRetry: () => ref.invalidate(jobOpeningsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              EmptyStateWidget(title: 'No open positions', icon: Icons.work_outline_rounded),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final j = list[i];
              return SurfaceCard(
                onTap: j.uniqueId.isEmpty
                    ? null
                    : () => Navigator.push(context, MaterialPageRoute(builder: (_) => _CandidatesScreen(job: j))),
                child: Row(children: [
                  const IconBadge(icon: Icons.work_outline_rounded, color: Color(0xFF00897B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(j.name.isEmpty ? j.position : j.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text([j.position, j.location].where((e) => e.isNotEmpty).join(' · '),
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                      if (j.driveStart != null)
                        Text('Drive ${formatYmd(j.driveStart)}${j.driveEnd != null ? ' – ${formatYmd(j.driveEnd, withYear: true)}' : ''}',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                    ]),
                  ),
                  StatusChip(label: '${j.openings} open', color: AppColors.primary),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _CandidatesScreen extends ConsumerWidget {
  final JobOpening job;
  const _CandidatesScreen({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(jobCandidatesProvider(job.uniqueId));
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: Text(job.name.isEmpty ? 'Candidates' : job.name)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(jobCandidatesProvider(job.uniqueId));
          await ref.read(jobCandidatesProvider(job.uniqueId).future);
        },
        child: AsyncValueView<List<JobCandidate>>(
          value: data,
          onRetry: () => ref.invalidate(jobCandidatesProvider(job.uniqueId)),
          builder: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyStateWidget(title: 'No candidates yet', icon: Icons.groups_outlined),
              ]);
            }
            // Best match first when scores exist.
            final sorted = [...list]..sort((a, b) => (b.score ?? -1).compareTo(a.score ?? -1));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final c = sorted[i];
                return SurfaceCard(
                  child: Row(children: [
                    UserAvatar(name: c.name, radius: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(c.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        if (c.expectedCtc != null)
                          Text('Expects ${_money.format(c.expectedCtc)}${c.currentCtc != null ? '  ·  Now ${_money.format(c.currentCtc)}' : ''}',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                      ]),
                    ),
                    if (c.score != null)
                      StatusChip(
                        label: c.score!.toStringAsFixed(0),
                        color: c.score! >= 70 ? AppColors.success : (c.score! >= 40 ? AppColors.warning : AppColors.error),
                      ),
                    if ((c.phone ?? '').isNotEmpty)
                      IconButton(
                        tooltip: 'Call',
                        icon: const Icon(Icons.call_outlined, size: 20),
                        onPressed: () => launchUrl(Uri.parse('tel:${c.phone}')),
                      ),
                  ]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Offers extends ConsumerWidget {
  const _Offers();

  Color _color(String s) {
    final t = s.toLowerCase();
    if (t.contains('accept')) return AppColors.success;
    if (t.contains('declin') || t.contains('revok') || t.contains('expire')) return AppColors.error;
    if (t.contains('sent') || t.contains('view')) return AppColors.info;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(offersProvider);
        await ref.read(offersProvider.future);
      },
      child: AsyncValueView<List<OfferItem>>(
        value: ref.watch(offersProvider),
        onRetry: () => ref.invalidate(offersProvider),
        builder: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              EmptyStateWidget(title: 'No offers', icon: Icons.mail_outline_rounded),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final o = list[i];
              return SurfaceCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(o.candidate, style: const TextStyle(fontWeight: FontWeight.w700))),
                    StatusChip(label: o.statusName, color: _color(o.statusName)),
                  ]),
                  const SizedBox(height: 4),
                  Text([o.position, if ((o.department ?? '').isNotEmpty) o.department!].join(' · '),
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('${o.code}  ·  CTC ${_money.format(o.ctc)}  ·  Joins ${formatYmd(o.joiningDate, withYear: true)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  Text('Valid until ${formatYmd(o.validUntil, withYear: true)}',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
