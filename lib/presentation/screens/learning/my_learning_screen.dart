import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/extras_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// My courses + a catalog to self-enroll from.
class MyLearningScreen extends ConsumerWidget {
  const MyLearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Learning'),
          bottom: const TabBar(tabs: [Tab(text: 'My courses'), Tab(text: 'Catalog')]),
        ),
        body: const TabBarView(children: [_MyCourses(), _Catalog()]),
      ),
    );
  }
}

class _MyCourses extends ConsumerWidget {
  const _MyCourses();

  Color _color(int s) {
    switch (s) {
      case EnrollmentStatus.completed:
        return AppColors.success;
      case EnrollmentStatus.inProgress:
        return AppColors.warning;
      case EnrollmentStatus.dropped:
        return Colors.grey;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myEnrollmentsProvider);
        await ref.read(myEnrollmentsProvider.future);
      },
      child: AsyncValueView<List<CourseEnrollment>>(
        value: ref.watch(myEnrollmentsProvider),
        onRetry: () => ref.invalidate(myEnrollmentsProvider),
        builder: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              EmptyStateWidget(
                title: 'No courses yet',
                subtitle: 'Browse the Catalog tab to enroll.',
                icon: Icons.school_outlined,
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final c = list[i];
              final url = c.externalUrl;
              return SurfaceCard(
                onTap: url == null || url.isEmpty
                    ? null
                    : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                      StatusChip(label: EnrollmentStatus.label(c.statusId), color: _color(c.statusId)),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (c.progress / 100).clamp(0, 1),
                        minHeight: 6,
                        backgroundColor: AppColors.primaryContainer,
                        color: AppColors.tertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      [
                        '${c.progress.toStringAsFixed(0)}%',
                        if (c.courseTypeName != null) c.courseTypeName!,
                        if (c.dueDate != null) 'Due ${formatYmd(c.dueDate, withYear: true)}',
                      ].join('  ·  '),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Catalog extends ConsumerWidget {
  const _Catalog();

  Future<void> _enroll(BuildContext context, WidgetRef ref, CatalogCourse c) async {
    try {
      final r = await ref.read(extrasDataSourceProvider).selfEnroll(c.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.message.isNotEmpty ? r.message : (r.success ? 'Enrolled' : 'Could not enroll')),
          backgroundColor: r.success ? Colors.green : Colors.red,
        ));
      }
      ref.invalidate(myEnrollmentsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AsyncValueView.messageOf(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrolled = (ref.watch(myEnrollmentsProvider).valueOrNull ?? []).map((e) => e.courseId).toSet();
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(courseCatalogProvider);
        await ref.read(courseCatalogProvider.future);
      },
      child: AsyncValueView<List<CatalogCourse>>(
        value: ref.watch(courseCatalogProvider),
        onRetry: () => ref.invalidate(courseCatalogProvider),
        builder: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              EmptyStateWidget(title: 'No courses available', icon: Icons.menu_book_outlined),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final c = list[i];
              final done = enrolled.contains(c.id);
              return SurfaceCard(
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          [
                            if (c.courseTypeName != null) c.courseTypeName!,
                            if (c.durationHours != null) '${c.durationHours}h',
                          ].join('  ·  '),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  done
                      ? const StatusChip(label: 'Enrolled', color: AppColors.success)
                      : OutlinedButton(onPressed: () => _enroll(context, ref, c), child: const Text('Enroll')),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
