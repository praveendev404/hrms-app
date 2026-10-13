// End-to-end flows against a FAKE backend (tools/fake_api.dart).
//
//   flutter test tools/e2e/flows_test.dart
//
// Drives the real screens with taps and typing, then asserts on both what the user sees and
// the exact requests the app sent. It proves the app's navigation, forms and request building;
// it does NOT prove the real server accepts those requests (see tools/check_api.py for that).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vectoredge_hrms/core/errors/exceptions.dart';
import 'package:vectoredge_hrms/core/services/location_service.dart';
import 'package:vectoredge_hrms/core/theme/app_theme.dart';
import 'package:vectoredge_hrms/presentation/providers/providers.dart';
import 'package:vectoredge_hrms/presentation/providers/user_profile_provider.dart';
import 'package:vectoredge_hrms/presentation/screens/login/login_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/timesheet/timesheet_entry_screen.dart';
import 'package:vectoredge_hrms/presentation/screens/todo/todo_screen.dart';

import '../fake_api.dart';
import '../test_fonts.dart';

/// No GPS in tests: fail fast, like a phone with location off. The app must still punch.
class _NoLocation extends LocationService {
  @override
  Future<LocationData> getCurrentLocation() async =>
      throw const AppException(message: 'Location unavailable in tests');
}

Future<void> settle(WidgetTester t, {int steps = 8}) async {
  for (var i = 0; i < steps; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

/// Boots the app on [home] with the fake backend; returns it so the test can read its call log.
Future<FakeApiClient> boot(WidgetTester t, Widget home) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);

  final api = FakeApiClient();
  final prefs = await SharedPreferences.getInstance();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(api),
        locationServiceProvider.overrideWithValue(_NoLocation()),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.lightTheme, home: home),
    ),
  );
  await settle(t);
  return api;
}

Future<void> shutdown(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(milliseconds: 100));
}

/// Fills the login form with valid-looking credentials and waits for Home.
Future<void> signIn(WidgetTester t) async {
  await t.enterText(find.byType(TextFormField).at(0), 'devsupport@iqbc.in');
  await t.enterText(find.byType(TextFormField).at(1), 'secret-pass');
  await t.tap(find.widgetWithText(ElevatedButton, 'Login'));
  await settle(t, steps: 12);
}

/// For screens opened on their own: Home normally loads the profile first, so do the same.
Future<void> loadProfile(WidgetTester t) async {
  final container = ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
  await container.read(userProfileProvider.notifier).fetchUserProfile();
  await settle(t, steps: 2);
}

Finder navItem(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

List<({String method, String path, dynamic body})> calls(FakeApiClient api, String method, String suffix) =>
    api.calls.where((c) => c.method == method && c.path.endsWith(suffix)).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadTestFonts();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    // flutter_secure_storage has no plugin in tests; accept every call.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  testWidgets('1. login lands on the dashboard and sends the credentials', (t) async {
    final api = await boot(t, const LoginScreen());

    await t.enterText(find.byType(TextFormField).at(0), 'devsupport@iqbc.in');
    await t.enterText(find.byType(TextFormField).at(1), 'secret-pass');
    await t.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await settle(t, steps: 12);

    final login = calls(api, 'POST', '/api/v1/authorize');
    expect(login, hasLength(1));
    expect(login.first.body, {'userName': 'devsupport@iqbc.in', 'password': 'secret-pass'});

    expect(find.text('Quick actions'), findsOneWidget, reason: 'should be on Home after login');
    expect(calls(api, 'GET', '/api/v1/dashboard/layout'), isNotEmpty, reason: 'home loads its layout from the server');
    await shutdown(t);
  });

  testWidgets('2. drawer shows exactly the modules the server menu grants', (t) async {
    await boot(t, const LoginScreen());
    await signIn(t);

    await t.tap(find.byIcon(Icons.menu).first);
    await settle(t);

    final inDrawer = (String label) => find.descendant(of: find.byType(Drawer), matching: find.text(label));
    for (final label in ['LEAVE MANAGEMENT', 'My Team Approvals', 'HR Approvals', 'My Attendance', 'My Timesheet', 'Payslips', 'HR Analytics']) {
      await t.scrollUntilVisible(inDrawer(label), 120,
          scrollable: find.descendant(of: find.byType(Drawer), matching: find.byType(Scrollable)).first);
      expect(inDrawer(label), findsOneWidget, reason: 'drawer should list "$label"');
    }
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('RECRUITMENT')), findsNothing, reason: 'not granted in the sample menu, so it must not appear');
    await shutdown(t);
  });

  testWidgets('3. check-in posts time + punch type and flips the card', (t) async {
    final api = await boot(t, const LoginScreen());
    await signIn(t);

    await t.tap(find.text('Check in'));
    await settle(t, steps: 12);

    final punch = calls(api, 'POST', '/api/v1/attendence/postlatestwebcheckin');
    expect(punch, hasLength(1));
    final b = punch.first.body as Map;
    expect(b['punchInTypeId'], 1);
    expect(b.keys, containsAll(['date', 'hours', 'minutes', 'seconds']));
    expect(find.text('Check out'), findsOneWidget, reason: 'card should show the checked-in state');
    await shutdown(t);
  });

  testWidgets('4. apply leave: type, dates, server day-count, submit', (t) async {
    final api = await boot(t, const LoginScreen());
    await signIn(t);

    await t.tap(navItem('Leave'));
    await settle(t);
    expect(find.text('Casual Leave'), findsWidgets, reason: 'balances load');

    await t.tap(find.text('Apply'));
    await settle(t);

    await t.tap(find.byType(DropdownButtonFormField<int>).first);
    await settle(t);
    await t.tap(find.text('Casual Leave').last);
    await settle(t);

    await t.tap(find.text('Select').first); // From date
    await settle(t);
    await t.tap(find.text('OK'));
    await settle(t, steps: 12); // debounce + day-count call

    expect(calls(api, 'POST', '/api/v1/leave/daycount'), isNotEmpty, reason: 'days are computed by the server');
    expect(find.textContaining('working day'), findsOneWidget);

    await t.enterText(find.byType(TextField).last, 'Family function');
    await t.tap(find.text('Submit request'));
    await settle(t, steps: 12);

    final submit = calls(api, 'POST', '/api/v1/leave');
    expect(submit, hasLength(1));
    final m = (submit.first.body as Map)['leaveModel'] as Map;
    expect(m['employeeId'], 7);
    expect(m['leaveTypeId'], 1);
    expect(m['noOfDays'], 1);
    expect(m['reason'], 'Family function');
    expect(m['fromDate'], m['toDate']);
    expect(m.keys, containsAll(['fromDayTypeId', 'toDayTypeId']));
    await shutdown(t);
  });

  testWidgets('5. approvals: approve a leave sends the right bulk-action', (t) async {
    final api = await boot(t, const LoginScreen());
    await signIn(t);

    await t.tap(navItem('Approvals'));
    await settle(t);
    expect(find.text('Ravi Kumar'), findsOneWidget);

    await t.tap(find.text('Approve').first);
    await settle(t, steps: 12);

    final act = calls(api, 'POST', '/api/v1/leave/approvals/bulk-action');
    expect(act, hasLength(1));
    expect(act.first.body, {'approvalIds': [11], 'leaveStatusTypeId': 2});
    await shutdown(t);
  });

  testWidgets('6. to-do: add one', (t) async {
    final api = await boot(t, const TodoScreen());
    await loadProfile(t);
    expect(find.text('Submit travel claim'), findsOneWidget);

    await t.tap(find.text('New'));
    await settle(t);
    await t.enterText(find.byType(TextField).first, 'Call the vendor');
    await t.tap(find.text('Save'));
    await settle(t, steps: 12);

    final save = calls(api, 'POST', '/api/v1/todo/upsert');
    expect(save, hasLength(1));
    final b = save.first.body as Map;
    expect(b['title'], 'Call the vendor');
    expect(b['dueDate'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    expect(b.containsKey('id'), isFalse, reason: 'a new to-do carries no id');
    await shutdown(t);
  });

  testWidgets('7. timesheet: log time against a project', (t) async {
    final api = await boot(t, const TimesheetEntryScreen());
    await loadProfile(t);
    expect(find.textContaining('this week'), findsOneWidget);

    await t.tap(find.text('Add'));
    await settle(t);
    expect(find.text('Log time'), findsOneWidget, reason: 'the log form should be open');

    await t.tap(find.byType(DropdownButtonFormField<int>).at(0));
    await settle(t);
    await t.tap(find.text('Atlas Platform').last);
    await settle(t);
    await t.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await settle(t);
    await t.tap(find.text('Regular').last);
    await settle(t);
    expect(find.text('Log time'), findsOneWidget, reason: 'form still open after choosing project and type');
    await t.enterText(find.byType(TextField).last, 'Wrote the report');
    await t.tap(find.text('Save'));
    await settle(t, steps: 12);

    final save = calls(api, 'POST', '/WorkLog');
    expect(save, hasLength(1),
        reason: 'calls made: ${api.calls.map((c) => "${c.method} ${c.path}").join(", ")}; '
            'on screen: ${t.widgetList<Text>(find.byType(Text)).map((e) => e.data).whereType<String>().take(120).join(" | ")}');
    final b = save.first.body as Map;
    expect(b['projectId'], 1);
    expect(b['workLogTypeId'], 1);
    expect(b['duration'], 8);
    expect(b['timesheetId'], 5);
    expect(b['employeeId'], 7);
    expect(b['comments'], 'Wrote the report');
    expect(b['date'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    await shutdown(t);
  });
}
