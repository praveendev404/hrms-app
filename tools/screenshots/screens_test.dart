// Renders the app's real screens with SAMPLE data and writes PNGs to ./out/.
//
//   flutter test tools/screenshots/screens_test.dart --update-goldens
//
// No network and no login: a fake ApiClient answers every call with canned JSON shaped like
// the real API. This is a layout/visual check, not a contract test - field names in the
// sample data are what the app assumes (see tools/check_api.py for the real shapes).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../fake_api.dart';
import '../test_fonts.dart';
import 'package:vectoredge_hrms/core/theme/app_theme.dart';
import 'package:vectoredge_hrms/presentation/providers/providers.dart';
import 'package:vectoredge_hrms/presentation/screens/analytics/hr_analytics_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/approvals/approvals_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/attendance/my_attendance_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/feed/feed_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/finance/my_finance_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/leave/apply_leave_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/leave/leave_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/notifications/notifications_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/payslips/payslips_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/performance/performance_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/profile/user_profile_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/recognition/recognition_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/timesheet/timesheet_entry_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/todo/todo_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestFonts();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> shot(WidgetTester tester, String name, Widget screen, {double height = 844}) async {
    tester.view.physicalSize = Size(390 * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiClientProvider.overrideWithValue(FakeApiClient()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: RepaintBoundary(child: screen),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
    // Tear the tree down so periodic timers are cancelled.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('home', (t) => shot(t, '01_home', const DashboardScreen(), height: 1500));
  testWidgets('leave', (t) => shot(t, '02_leave', const Scaffold(body: LeaveScreen()), height: 1000));
  testWidgets('apply leave', (t) => shot(t, '03_apply_leave', const ApplyLeaveScreen()));
  testWidgets('approvals', (t) => shot(t, '04_approvals', const Scaffold(body: ApprovalsScreen()), height: 1100));
  testWidgets('alerts', (t) => shot(t, '05_alerts', const Scaffold(body: NotificationsScreen())));
  testWidgets('my attendance', (t) => shot(t, '06_my_attendance', const MyAttendanceScreen(), height: 1300));
  testWidgets('payslips', (t) => shot(t, '07_payslips', const PayslipsScreen()));
  testWidgets('timesheet', (t) => shot(t, '08_timesheet', const TimesheetEntryScreen()));
  testWidgets('performance', (t) => shot(t, '09_performance', const PerformanceScreen()));
  testWidgets('finance', (t) => shot(t, '10_finance', const MyFinanceScreen()));
  testWidgets('todo', (t) => shot(t, '11_todo', const TodoScreen()));
  testWidgets('feed', (t) => shot(t, '12_feed', const FeedScreen()));
  testWidgets('recognition', (t) => shot(t, '13_recognition', const RecognitionScreen()));
  testWidgets('analytics', (t) => shot(t, '14_analytics', const HrAnalyticsScreen(), height: 1900));
  testWidgets('profile', (t) => shot(t, '15_profile', const Scaffold(body: UserProfileScreen())));
}
