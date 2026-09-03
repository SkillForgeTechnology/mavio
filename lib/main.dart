import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'core/services/background_location_service.dart';
import 'core/theme/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/landing_page.dart';
import 'screens/privacy_policy_page.dart';
import 'screens/account_deletion_page.dart';
import 'screens/admin/admin_portal_page.dart';
import 'screens/not_found_page.dart';
import 'core/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await BackgroundLocationService.initialize();
  await PushNotificationService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'MAVIO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      onGenerateRoute: (settings) {
        final rawName = settings.name ?? '/';
        final name = (rawName.length > 1 && rawName.endsWith('/'))
            ? rawName.substring(0, rawName.length - 1)
            : rawName;

        switch (name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) =>
                  kIsWeb ? const MavioLandingPage() : const SplashScreen(),
              settings: settings,
            );
          case '/privacy':
            return MaterialPageRoute(
              builder: (_) => const PrivacyPolicyPage(),
              settings: settings,
            );
          case '/delete-account':
            return MaterialPageRoute(
              builder: (_) => const AccountDeletionPage(),
              settings: settings,
            );
          case '/sf-mavio-ad':
            return MaterialPageRoute(
              builder: (_) => const AdminPortalPage(),
              settings: settings,
            );
          default:
            return MaterialPageRoute(
              builder: (_) => const NotFoundPage(),
              settings: settings,
            );
        }
      },
    );
  }
}
