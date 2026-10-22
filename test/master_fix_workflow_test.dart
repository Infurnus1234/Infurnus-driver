import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infurnus_driver/models/onboarding_rules.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/screens/auth/guided_document_capture.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/services/session_store.dart';

import 'guided_onboarding_test.dart' show image;

void main() {
  for (final code in [
    'profile_photo',
    'driver_license',
    'vehicle_rc',
    'identity',
    'pan',
    'insurance',
    'custom_policy',
  ]) {
    testWidgets(
      '$code has working Camera Gallery and Drive sources with correct preview',
      (tester) async {
        final draft = CaptureDraft();
        final sources = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: GuidedDocumentCapture(
                  rule: DocumentRule(code, required: true),
                  draft: draft,
                  changed: () {},
                  picker: (source, photo) async {
                    sources.add(source);
                    expect(photo, code == 'profile_photo');
                    return [image];
                  },
                ),
              ),
            ),
          ),
        );
        for (final source in ['Camera', 'Gallery', 'Drive']) {
          final trigger = find.text(
            draft.files.isEmpty ? 'Choose source' : 'Replace or add pages',
          );
          await tester.ensureVisible(trigger);
          await tester.tap(trigger);
          await tester.pumpAndSettle();
          expect(find.text('Camera'), findsOneWidget);
          expect(find.text('Gallery'), findsOneWidget);
          expect(find.text('Drive'), findsOneWidget);
          await tester.tap(find.text(source));
          await tester.pump(const Duration(milliseconds: 350));
          await tester.runAsync(() async {
            final expectedSource = source == 'Camera'
                ? 'CAMERA'
                : source == 'Gallery'
                ? 'GALLERY'
                : 'FILE';
            final deadline = DateTime.now().add(const Duration(seconds: 5));
            while ((draft.files.isEmpty || draft.source != expectedSource) &&
                DateTime.now().isBefore(deadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 20));
            }
          });
          await tester.pumpAndSettle();
          expect(draft.files, hasLength(1));
          final preview = tester.widget<Image>(find.byType(Image));
          expect(
            preview.fit,
            code == 'profile_photo' ? BoxFit.cover : BoxFit.contain,
          );
          expect(
            find.byKey(const ValueKey('circular-photo-preview')),
            code == 'profile_photo' ? findsOneWidget : findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
        expect(sources, ['CAMERA', 'GALLERY', 'FILE']);
        expect(draft.source, 'FILE');
        expect(find.textContaining('Selected locally'), findsOneWidget);
      },
    );
  }
  for (final status in [401, 503]) {
    test(
      'startup refresh $status distinguishes expiry from temporary failure',
      () async {
        final store = MemorySessionStore()
          ..value = jsonEncode({
            'accessToken': 'fixture',
            'csrfToken': 'csrf',
            'userId': 'user',
            'role': 'driver',
            'cookies': {'infurnus_refresh_token': 'refresh'},
          });
        final response = Completer<http.Response>();
        final api = ApiService(
          store: store,
          client: MockClient((request) async {
            expect(request.url.path, '/auth/refresh');
            return response.future;
          }),
        );
        final session = DriverSession(api: api);
        final restoration = session.restore();
        expect(session.restoring, isTrue);
        expect(session.authenticated, isFalse);
        response.complete(
          http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': 'FIXTURE', 'message': 'Fixture failure'},
            }),
            status,
          ),
        );
        expect(await restoration, isFalse);
        expect(session.restoring, isFalse);
        expect(session.restorationNeedsRetry, status == 503);
        expect(session.authenticated, isFalse);
        await Future<void>.delayed(Duration.zero);
        expect(await store.read(), status == 401 ? isNull : isNotNull);
        session.dispose();
      },
    );
  }
}
