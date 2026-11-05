import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';
import 'package:infurnus_driver/widgets/trip_map.dart';

// Isolated audit entry point. No stored credentials or production API is used.
final ride = <String, dynamic>{
  'id': 'local-audit-ride',
  'status': 'in_progress',
  'pinVerified': true,
  'pickup': {'latitude': 25.5941, 'longitude': 85.1376},
  'destination': {'latitude': 25.6, 'longitude': 85.14},
  'pickupAddress': 'Local audit pickup',
  'destinationAddress': 'Local audit destination',
};
int uploads = 0;
final opened = ValueNotifier<String>('none');
final notifications = FlutterLocalNotificationsPlugin();

class LocalApi extends ApiService {
  LocalApi()
    : super(
        client: MockClient((r) async {
          dynamic data;
          switch (r.url.path) {
            case '/provider/enrolment':
              data = {'dashboardAccessible': false, 'role': 'driver'};
            case '/users/local-audit':
              data = {'firstName': 'Local', 'lastName': 'Audit'};
            case '/rides/driver/profile':
              data = {
                'id': 'local-driver',
                'availabilityStatus': 'busy',
                'verificationStatus': 'approved',
              };
            case '/rides/driver/current-trip':
              data = ride;
            case '/rides/driver/assigned-vehicle':
              data = {'id': 'local-vehicle'};
            case '/provider/approvals':
              data = <dynamic>[];
            case '/rides/driver/location':
              uploads++;
              debugPrint('LOCAL_RIDE_AUDIT upload=$uploads');
              data = null;
            default:
              data = {};
          }
          return http.Response(
            jsonEncode({'success': true, 'data': data}),
            200,
          );
        }),
        store: MemorySessionStore(),
      ) {
    userId = 'local-audit';
  }
  @override
  bool get roleFlowEnabled => true;
}

class LocalSession extends DriverSession {
  LocalSession()
    : super(api: LocalApi(), onboardingDraftStore: MemorySessionStore());
  @override
  bool get authenticated => true;
  void phase(String status) {
    ride['status'] = status;
    ride['pinVerified'] = status == 'in_progress';
    currentTrip = Map.from(ride);
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await notifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    ),
    onDidReceiveNotificationResponse: (r) {
      if (r.payload == 'local-audit-ride') opened.value = r.payload!;
    },
  );
  runApp(
    ChangeNotifierProvider<DriverSession>(
      create: (_) => LocalSession(),
      child: const AuditApp(),
    ),
  );
}

class AuditApp extends StatefulWidget {
  const AuditApp({super.key});
  @override
  State<AuditApp> createState() => _AuditAppState();
}

class _AuditAppState extends State<AuditApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DriverSession>().refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<DriverSession>().refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<DriverSession>();
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('LOCAL DRIVER AUDIT')),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'In-memory ride API. No production credentials or backend calls.',
              ),
              Text(
                'Ride: ${session.currentTrip?["id"]} / ${session.currentTrip?["status"]}',
              ),
              Text('Local GPS uploads: $uploads'),
              ValueListenableBuilder(
                valueListenable: opened,
                builder: (_, id, _) => Text('Opened ride: $id'),
              ),
              Wrap(
                children: [
                  for (final status in [
                    'driver_assigned',
                    'driver_arrived',
                    'in_progress',
                  ])
                    TextButton(
                      onPressed: () => (session as LocalSession).phase(status),
                      child: Text(status),
                    ),
                ],
              ),
              TextButton(
                onPressed: () => notifications.show(
                  117,
                  'Local ride audit',
                  'Tap to return to the local active ride',
                  const NotificationDetails(
                    android: AndroidNotificationDetails(
                      'infurnus_local_audit',
                      'Local ride audit',
                      importance: Importance.high,
                      priority: Priority.high,
                    ),
                  ),
                  payload: 'local-audit-ride',
                ),
                child: const Text('Send local test notification'),
              ),
              const TripMap(key: ValueKey('local-map')),
            ],
          ),
        ),
      ),
    );
  }
}
