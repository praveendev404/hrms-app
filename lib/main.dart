import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/response_cache.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/providers.dart';
import 'presentation/screens/splash/splash_screen.dart';

/// Global navigation key for accessing navigation context from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Main entry point of the application
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Run app with Riverpod
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const HRMSApp(),
    ),
  );
}

/// Root application widget
class HRMSApp extends StatelessWidget {
  const HRMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HRMS',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,

      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Screens are designed on light surfaces (white cards, light backgrounds); following the
      // phone's dark mode made default text near-white on them, so content looked empty.
      themeMode: ThemeMode.light,

      // Offline banner: shown while answers are coming from the saved copy.
      builder: (context, child) => ValueListenableBuilder<DateTime?>(
        valueListenable: ResponseCache.servingSavedData,
        builder: (context, savedAt, _) {
          final content = child ?? const SizedBox.shrink();
          if (savedAt == null) return content;
          final hh = savedAt.hour.toString().padLeft(2, '0');
          final mm = savedAt.minute.toString().padLeft(2, '0');
          return Column(
            children: [
              Material(
                color: const Color(0xFFFFF3E0),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(children: [
                      const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFE65100)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are offline. Showing data saved at $hh:$mm.',
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFFE65100), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              // The banner already covers the status bar, so screens below it must not pad again.
              Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: content)),
            ],
          );
        },
      ),

      // Initial screen
      home: const SplashScreen(),
    );
  }
}

