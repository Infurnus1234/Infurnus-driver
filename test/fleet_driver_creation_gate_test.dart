import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/core/operations_theme.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';

class FleetFixtureSession extends DriverSession {
  FleetFixtureSession(ApiService api) : super(api: api);
  @override
  bool get authenticated => true;
}

void main() {
  for (final approved in [false, true]) {
    testWidgets(
      'Create Driver responds with ${approved ? 'form' : 'approval guidance'}',
      (tester) async {
        final posts = <String>[];
        final api =
            ApiService(
                client: MockClient((request) async {
                  if (request.method == 'POST') posts.add(request.url.path);
                  final dynamic data = switch (request.url.path) {
                    '/partners/me' => {
                      'id': 'fleet-fixture',
                      'businessName': 'Test Fleet',
                      'approvalStatus': approved ? 'approved' : 'pending',
                    },
                    '/provider/earnings' ||
                    '/fleet/earnings' => <String, dynamic>{},
                    _ => <dynamic>[],
                  };
                  return http.Response(
                    jsonEncode({'success': true, 'data': data}),
                    200,
                  );
                }),
              )
              ..role = 'fleet_owner'
              ..providerMode = 'fleet_owner';
        final session = FleetFixtureSession(api)
          ..roleEnrolment = {'dashboardAccessible': true};
        await tester.pumpWidget(
          ChangeNotifierProvider<DriverSession>.value(
            value: session,
            child: MaterialApp(
              theme: Ops.theme,
              home: const ProviderAssetsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Drivers').last);
        await tester.pumpAndSettle();
        final create = find.text('Create Driver profile');
        await tester.ensureVisible(create);
        await tester.tap(create);
        await tester.pumpAndSettle();
        if (approved) {
          expect(find.text('First name *'), findsOneWidget);
          expect(find.text('Business approval required'), findsNothing);
        } else {
          expect(find.text('Business approval required'), findsOneWidget);
          expect(find.textContaining('Business status:'), findsOneWidget);
          await tester.tap(find.text('Review business verification'));
          await tester.pumpAndSettle();
          expect(
            find.text('Correct provider / business details'),
            findsOneWidget,
          );
        }
        expect(posts, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
        api.dispose();
      },
    );
  }
}
