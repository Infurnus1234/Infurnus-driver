import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'providers/driver_session.dart';
import 'router/app_router.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => DriverSession()..restore()),
      ],
      child: const InfurnusApp(),
    ),
  );
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
