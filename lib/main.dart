import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/background_location_service.dart';
import 'core/theme/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/privacy_policy_page.dart';
import 'screens/account_deletion_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundLocationService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MAVIO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/privacy': (context) => const PrivacyPolicyPage(),
        '/delete-account': (context) => const AccountDeletionPage(),
      },
    );
  }
}
