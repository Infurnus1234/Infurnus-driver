
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_state.dart';
import 'providers/driver_session.dart';
import 'router/app_router.dart';
import 'core/theme.dart';
import 'services/startup_permissions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    debugPrint('FCM TOKEN: $token');
  } catch (e) {
    debugPrint('Firebase initialization / FCM error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => DriverSession()..restore()),
      ],
      child: const InfurnusApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      await requestStartupLocation();
    } catch (_) {
      debugPrint('Startup location permission unavailable');
    }
  });
}

class InfurnusApp extends StatelessWidget {
  const InfurnusApp({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<DriverSession>();
    WidgetsBinding.instance.addPostFrameCallback((_) => appRouter.refresh());

    return MaterialApp.router(
      title: 'Infurnus Logistics & Fleet',
      debugShowCheckedModeBanner: false,
      theme: InfurnusTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
