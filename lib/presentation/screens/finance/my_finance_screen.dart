import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

final _money = NumberFormat.decimalPatternDigits(locale: 'en_IN', decimalDigits: 0);
String _fmt(double v) => _money.format(v);

/// My loans and salary. Salary amounts are hidden until you tap the eye, so a glance
/// over your shoulder doesn't show them.
class MyFinanceScreen extends ConsumerWidget {
  const MyFinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('My finance'),
          bottom: const TabBar(tabs: [Tab(text: 'Salary'), Tab(text: 'Loans'), Tab(text: 'Form 16')]),
        ),
        body: const TabBarView(children: [_SalaryTab(), _LoansTab(), _Form16Tab()]),
      ),
    );
  }
}

class _SalaryTab extends ConsumerStatefulWidget {
  const _SalaryTab();

  @override
  ConsumerState<_SalaryTab> createState() => _SalaryTabState();
}

class _SalaryTabState extends ConsumerState<_SalaryTab> {
  bool _visible = false;
  int? _expandedId;

  String _show(double v) => _visible ? _fmt(v) : '••••••';

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(mySalariesProvider);
        await ref.read(mySalariesProvider.future);
      },
      child: AsyncValueView<List<SalaryRecord>>(
        value: ref.watch(mySalariesProvider),
        onRetry: () => ref.invalidate(mySalariesProvider),
        builder: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              EmptyStateWidget(title: 'No salary details yet', icon: Icons.payments_outlined),
            ]);
          }
          final sorted = [...list]..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
          final current = sorted.first;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Annual CTC', style: TextStyle(color: Colors.white.withOpacity(0.85))),
                      const Spacer(),
                      IconButton(
                        tooltip: _visible ? 'Hide amounts' : 'Show amounts',
                        onPressed: () => setState(() => _visible = !_visible),
                        icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white),
                      ),
                    ]),
                    Text(_show(current.ctc),
                        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Effective ${formatYmd(current.effectiveFrom, withYear: true)}',
                        style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                    if (current.bonus > 0)
                      Text('Bonus ${_show(current.bonus)}', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader('Salary structure'),
              const SizedBox(height: 6),
              for (final s in sorted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SurfaceCard(
                    onTap: () => setState(() => _expandedId = _expandedId == s.id ? null : s.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('From ${formatYmd(s.effectiveFrom, withYear: true)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('CTC ${_show(s.ctc)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            ]),
                          ),
                          if (s.isActive) const StatusChip(label: 'Current', color: AppColors.success),
                          Icon(_expandedId == s.id ? Icons.expand_less : Icons.expand_more),
                        ]),
                        if (_expandedId == s.id) _Breakup(id: s.id, show: _show),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Breakup extends ConsumerWidget {
  final int id;
  final String Function(double) show;
  const _Breakup({required this.id, required this.show});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<SalaryComponent>>(
      compact: true,
      value: ref.watch(salaryBreakupProvider(id)),
      onRetry: () => ref.invalidate(salaryBreakupProvider(id)),
      builder: (comps) {
        final earnings = comps.where((c) => c.isEarning && !c.excludeFromPayslip).toList();
        final deductions = comps.where((c) => !c.isEarning).toList();
        Widget block(String title, List<SalaryComponent> items, Color color) {
          if (items.isEmpty) return const SizedBox.shrink();
          final total = items.fold<double>(0, (a, c) => a + c.amount);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              for (final c in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: Text(c.name)),
                    Text(show(c.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              const Divider(height: 14),
              Row(children: [
                const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700))),
                Text(show(total), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ]),
            ],
          );
        }

        if (comps.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No breakup available.', style: TextStyle(color: Colors.grey.shade600)),
          );
        }
        return Column(children: [
          block('EARNINGS (per month)', earnings, AppColors.success),
          block('DEDUCTIONS', deductions, AppColors.error),
        ]);
      },
    );
  }
}

class _LoansTab extends ConsumerWidget {
  const _LoansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myLoansProvider);
        await ref.read(myLoansProvider.future);
      },
      child: AsyncValueView<List<LoanItem>>(
        value: ref.watch(myLoansProvider),
        onRetry: () => ref.invalidate(myLoansProvider),
        builder: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              EmptyStateWidget(
                title: 'No loans',
                subtitle: 'Loans or advances given to you will show here.',
                icon: Icons.account_balance_outlined,
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final l = list[i];
              return SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(l.payType.isEmpty ? 'Loan' : l.payType,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                      StatusChip(
                        label: l.balance <= 0 ? 'Closed' : (l.isActive ? 'Active' : 'Inactive'),
                        color: l.balance <= 0 ? Colors.grey : AppColors.info,
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('Taken ${formatYmd(l.takenOn, withYear: true)}  ·  ${l.percentage}% interest',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: l.repaidRatio,
                        minHeight: 8,
                        backgroundColor: AppColors.primaryContainer,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      _Cell('Amount', _fmt(l.amount)),
                      _Cell('Paid', _fmt(l.totalPaid)),
                      _Cell('Balance', _fmt(l.balance)),
                    ]),
                    if (l.emi > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'EMI ${_fmt(l.emi)}${l.emiFrom == null ? '' : ' from ${formatYmd(l.emiFrom, withYear: true)}'}',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                        ),
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

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  const _Cell(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _Form16Tab extends ConsumerStatefulWidget {
  const _Form16Tab();

  @override
  ConsumerState<_Form16Tab> createState() => _Form16TabState();
}

class _Form16TabState extends ConsumerState<_Form16Tab> {
  int? _busyFy;

  Future<void> _open(int empId, Form16Item f) async {
    setState(() => _busyFy = f.fyId);
    try {
      final path = await ref.read(requestDataSourceProvider).downloadForm16(empId, f);
      final res = await OpenFilex.open(path);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No app available to open PDF files (${res.message}).'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AsyncValueView.messageOf(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busyFy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empId = ref.watch(userProfileProvider).profile?.employeeId;
    if (empId == null) {
      return const Center(child: Text('Your account is not linked to an employee record.'));
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(form16Provider(empId));
        await ref.read(form16Provider(empId).future);
      },
      child: AsyncValueView<List<Form16Item>>(
        value: ref.watch(form16Provider(empId)),
        onRetry: () => ref.invalidate(form16Provider(empId)),
        builder: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              EmptyStateWidget(
                title: 'No Form 16 yet',
                subtitle: 'Your Form 16 appears here once payroll publishes it for a financial year.',
                icon: Icons.description_outlined,
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final f = list[i];
              final busy = _busyFy == f.fyId;
              return SurfaceCard(
                onTap: busy ? null : () => _open(empId, f),
                child: Row(children: [
                  const IconBadge(icon: Icons.description_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('TDS deducted ${_fmt(f.tdsDeducted)}${f.isProjected ? ' (projected)' : ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      if (f.publishedOn != null)
                        Text('Published ${formatDateTimeShort(f.publishedOn)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ]),
                  ),
                  busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_outlined, color: Colors.grey),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
