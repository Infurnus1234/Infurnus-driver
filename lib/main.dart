import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'providers/driver_session.dart';
import 'router/app_router.dart';
import 'core/operations_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    debugPrint('Firebase initialization unavailable.');
  }
  // Complete secure restoration behind the native launch splash. The first
  // Flutter frame is the real destination, never a restoration/error page.
  final session = DriverSession();
  await session.restore();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider.value(value: session),
      ],
      child: const InfurnusApp(),
    ),
  );
}

class InfurnusApp extends StatefulWidget {
  const InfurnusApp({super.key});
  @override
  State<InfurnusApp> createState() => _InfurnusAppState();
}

class _InfurnusAppState extends State<InfurnusApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = context.read<DriverSession>();
    if (state == AppLifecycleState.resumed &&
        !session.busy &&
        !session.restoring) {
      if (session.restorationNeedsRetry) {
        session.restore();
      } else if (session.authenticated) {
        session.refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    final notificationRoute = session.pendingNotificationRoute;
    if (notificationRoute != null && session.authenticated) {
      session.pendingNotificationRoute = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (session.authenticated) appRouter.go(notificationRoute);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => appRouter.refresh());
    return MaterialApp.router(
      title: 'Infurnus Logistics & Fleet',
      debugShowCheckedModeBanner: false,
      theme: Ops.theme,
      routerConfig: appRouter,
    );
  }
}
