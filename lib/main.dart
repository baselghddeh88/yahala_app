import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'constants.dart';
import 'firebase_options.dart';
import 'screens/admin_gate_screen.dart';
import 'screens/legal_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    YahalaBootstrap(
      startInAdmin: _isAdminUrl(),
      startLegalPath: _initialLegalPath(),
    ),
  );
}

Future<void> _initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  unawaited(_configureMessagingAfterLaunch());
}

Future<void> _configureMessagingAfterLaunch() async {
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (error) {
    debugPrint('FCM permission request skipped: $error');
    return;
  }

  try {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    NotificationService.listenToTokenRefresh();

    NotificationService.listenToNotificationClicks();

    NotificationService.saveFcmToken();
  } catch (error) {
    debugPrint('FCM setup skipped: $error');
  }
}

bool _isAdminUrl() {
  final uri = Uri.base;
  final host = uri.host.toLowerCase();
  return host == 'admin.yahalaus.com' ||
      uri.path == '/admin' ||
      uri.path.endsWith('/admin') ||
      uri.fragment == '/admin' ||
      uri.fragment.startsWith('/admin');
}

String? _initialLegalPath() {
  final uri = Uri.base;
  final candidates = <String>[uri.path, uri.fragment];
  for (final value in candidates) {
    if (_isPrivacyRoute(value)) {
      return '/privacy';
    }
    if (_isTermsRoute(value)) {
      return '/terms';
    }
  }
  return null;
}

bool _isPrivacyRoute(String value) {
  final route = value.toLowerCase();
  return route == '/privacy' ||
      route.endsWith('/privacy') ||
      route == '/privacy-policy' ||
      route.endsWith('/privacy-policy');
}

bool _isTermsRoute(String value) {
  final route = value.toLowerCase();
  return route == '/terms' ||
      route.endsWith('/terms') ||
      route == '/terms-of-use' ||
      route.endsWith('/terms-of-use');
}

Widget _legalScreenForPath(String path) {
  return LegalScreen(
    isArabic: false,
    isDark: false,
    initialTab: _isPrivacyRoute(path) ? 1 : 0,
  );
}

class YahalaBootstrap extends StatefulWidget {
  final bool startInAdmin;
  final String? startLegalPath;

  const YahalaBootstrap({
    super.key,
    required this.startInAdmin,
    this.startLegalPath,
  });

  @override
  State<YahalaBootstrap> createState() => _YahalaBootstrapState();
}

class _YahalaBootstrapState extends State<YahalaBootstrap> {
  late final Future<void> _startup = _initializeFirebase();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'يا هلا',
            home: StartupSplashScreen(),
          );
        }

        return YahalaApp(
          startInAdmin: widget.startInAdmin,
          startLegalPath: widget.startLegalPath,
        );
      },
    );
  }
}

class StartupSplashScreen extends StatelessWidget {
  const StartupSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: yahalaLightBg,
      body: Center(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 28,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: yahalaLogo(width: 150),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'يا هلا',
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: yahalaGreen,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'جريدة العرب في المهجر',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: yahalaGold,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class YahalaApp extends StatelessWidget {
  final bool startInAdmin;
  final String? startLegalPath;

  const YahalaApp({super.key, this.startInAdmin = false, this.startLegalPath});

  Widget _initialHome() {
    if (startInAdmin) {
      return const AdminGateScreen();
    }
    if (startLegalPath != null) {
      return _legalScreenForPath(startLegalPath!);
    }
    return const SplashScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'يا هلا',
      home: _initialHome(),
      onGenerateRoute: (settings) {
        final routeName = settings.name ?? '';
        if (routeName == '/admin') {
          return MaterialPageRoute(builder: (_) => const AdminGateScreen());
        }
        if (_isPrivacyRoute(routeName) || _isTermsRoute(routeName)) {
          return MaterialPageRoute(
            builder: (_) => _legalScreenForPath(routeName),
          );
        }
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      },
    );
  }
}
