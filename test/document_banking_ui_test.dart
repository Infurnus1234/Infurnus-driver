import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/widgets/calendar_field.dart';
import 'package:infurnus_driver/widgets/private_document_preview.dart';
import 'package:infurnus_driver/screens/common/bank_account_screen.dart';
import 'package:infurnus_driver/providers/driver_session.dart';
import 'package:infurnus_driver/services/api_service.dart';
import 'package:infurnus_driver/models/onboarding_rules.dart';
import 'package:infurnus_driver/screens/fleet/provider_assets_screen.dart';

import 'full_stack_regression_test.dart' show AssetsSession;

http.Response ok(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
void main() {
  testWidgets(
    'vehicle save failure retains details and calendar inputs until confirmed persistence',
    (tester) async {
      var fail = true, posts = 0;
      final vehicles = <Map<String, dynamic>>[];
      final api = ApiService(
        client: MockClient((r) async {
          if (r.method == 'POST' && r.url.path == '/partners/vehicles') {
            posts++;
            if (fail) {
              return http.Response(
                jsonEncode({
                  'error': {'message': 'Vehicle save unavailable'},
                }),
                503,
              );
            }
            final input = jsonDecode(r.body) as Map<String, dynamic>;
            vehicles.add({
              ...input,
              'id': 'saved',
              'isActive': false,
              'verificationStatus': 'pending',
            });
            return ok(vehicles.last);
          }
          switch (r.url.path) {
            case '/partners/me':
              return ok({
                'id': 'partner',
                'businessName': 'TEST_SAMPLE',
                'approvalStatus': 'pending',
              });
            case '/partners/vehicles':
              return ok(vehicles);
            case '/provider/vehicle-catalog':
              return ok({
                'sectors': ['passenger'],
                'types': [
                  {'sector': 'passenger', 'code': 'sedan', 'name': 'Sedan'},
                ],
              });
            default:
              return ok([]);
          }
        }),
      )..userId = 'owner';
      final session = AssetsSession(api);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<DriverSession>.value(
          value: session,
          child: const MaterialApp(home: ProviderAssetsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add vehicle'));
      await tester.tap(find.text('Add vehicle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('passenger').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sedan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'TEST_SAMPLE');
      await tester.enterText(find.byType(TextFormField).at(1), 'Van');
      await tester.enterText(find.byType(TextFormField).at(2), 'TEST123');
      await tester.ensureVisible(find.text('Optional details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Optional details'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Choose Registration date (optional, YYYY-MM-DD)'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(
          find.byTooltip('Choose Registration date (optional, YYYY-MM-DD)'),
        ),
        alignment: 0.3,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip('Choose Registration date (optional, YYYY-MM-DD)'),
      );
      await tester.pumpAndSettle();
      final selectedRegistrationDate = tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .initialDate!
          .toIso8601String()
          .substring(0, 10);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(find.text('Add owned vehicle'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('TEST_SAMPLE'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('TEST_SAMPLE'), findsOneWidget);
      expect(find.text('Van'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(posts, 2);
      expect(vehicles.length, 1);
      expect(vehicles.single['registrationDate'], selectedRegistrationDate);
    },
  );
  testWidgets(
    'calendar chooses an ISO date and clamps an invalid out-of-range draft',
    (tester) async {
      final controller = TextEditingController(text: '1800-01-01');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalendarField(
              label: 'Registration date',
              controller: controller,
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Choose Registration date'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(controller.text, '1900-01-01');
    },
  );
  testWidgets('disabled calendar cannot change a date while saving', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CalendarField(label: 'Expiry', enabled: false)),
      ),
    );
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });
  testWidgets(
    'bank confirmation and IFSC reject invalid input before an API save; confirmed success remains pending',
    (tester) async {
      var posts = 0;
      final api = ApiService(
        client: MockClient((r) async {
          if (r.method == 'GET') return ok(null);
          posts++;
          final data = jsonDecode(r.body) as Map;
          expect(data.containsKey('accountNumberConfirmation'), false);
          expect(data['ifscCode'], 'TEST0001234');
          return ok({
            'bankName': 'TEST_SAMPLE Bank',
            'accountNumberLast4': '9012',
            'isVerified': false,
          });
        }),
      );
      final session = DriverSession(api: api);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(home: BankAccountScreen()),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> fill(int index, String value) async {
        final field = find.byType(TextFormField).at(index);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      await fill(0, 'TEST_SAMPLE Owner');
      await fill(1, '123456789012');
      await fill(2, '00000000');
      await fill(3, 'BAD');
      await fill(4, 'TEST_SAMPLE Bank');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save for verification'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save for verification'));
      await tester.pumpAndSettle();
      expect(posts, 0);
      expect(find.text('Account numbers must match'), findsOneWidget);
      expect(find.text('Enter a valid 11-character IFSC code'), findsOneWidget);
      await fill(2, '123456789012');
      await fill(3, 'test0001234');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save for verification'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save for verification'));
      await tester.pumpAndSettle();
      expect(posts, 0);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      await tester.scrollUntilVisible(
        find.textContaining('Account ending 9012'),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Verification pending'), findsOneWidget);
    },
  );
  testWidgets(
    'business bank account persists entity and branch metadata without claiming verification',
    (tester) async {
      Map? submitted;
      final session = DriverSession(
        api: ApiService(
          client: MockClient((r) async {
            if (r.method == 'GET') return ok(null);
            submitted = jsonDecode(r.body) as Map;
            return ok({
              'bankName': 'Test Bank',
              'accountNumberLast4': '9012',
              'isVerified': false,
            });
          }),
        ),
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: const MaterialApp(home: BankAccountScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Individual'));
      await tester.tap(find.text('Individual'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registered business').last);
      await tester.pumpAndSettle();
      for (final entry in {
        'accountHolderName': 'Test Fleet Ltd',
        'accountNumber': '123456789012',
        'accountNumberConfirmation': '123456789012',
        'ifscCode': 'TEST0001234',
        'bankName': 'Test Bank',
        'branchName': 'Test Branch',
        'legalEntityName': 'Test Fleet Ltd',
      }.entries) {
        final field = find.byKey(ValueKey('bank-${entry.key}'));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save for verification'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save for verification'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(submitted, containsPair('ownershipType', 'BUSINESS'));
      expect(submitted, containsPair('legalEntityName', 'Test Fleet Ltd'));
      expect(submitted, containsPair('branchName', 'Test Branch'));
      expect(submitted, isNot(contains('isVerified')));
    },
  );

  testWidgets(
    'private preview error offers a functional retry without exposing a storage URL',
    (tester) async {
      var fail = true, calls = 0;
      final api = ApiService(
        client: MockClient((r) async {
          calls++;
          if (fail) {
            return http.Response(
              jsonEncode({
                'error': {'message': 'Unavailable'},
              }),
              503,
            );
          }
          return ok([
            {'accessUrl': 'https://example.invalid/private-fixture'},
          ]);
        }),
      );
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showPrivateDocumentPreview(
                  c,
                  api,
                  '/partners/fixture/documents/fixture',
                  'RC',
                ),
                child: const Text('Preview'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('private file is unavailable'),
        findsOneWidget,
      );
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Open private page 1'), findsOneWidget);
      expect(find.textContaining('https://'), findsNothing);
    },
  );
  test('Aadhaar rules default to unavailable and require explicit masked-copy consent', () {
    expect(const DocumentRule('aadhaar').collectionAllowed, false);
    final authorized = DocumentRule.fromJson({
      'document_code': 'aadhaar',
      'required': false,
      'requires_expiry': false,
      'minimum_pages': 1,
      'aadhaar_collection_allowed': true,
    });
    expect(authorized.collectionAllowed, true);
    expect(
      OnboardingRules.validateFiles(authorized, [], {}),
      contains('Consent'),
    );
  });
}
