import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'router/app_router.dart';
import 'core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const InfurnusApp(),
    ),
  );
}

class InfurnusApp extends StatelessWidget {
  const InfurnusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Infurnus Logistics & Fleet',
      debugShowCheckedModeBanner: false,
      theme: InfurnusTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
