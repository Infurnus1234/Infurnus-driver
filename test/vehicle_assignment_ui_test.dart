import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infurnus_driver/screens/driver/vehicle_assignment_screen.dart';

import 'guided_onboarding_test.dart' show FixtureSession, host;

class AssignmentFixture extends FixtureSession {
  String? checked, claimed;
  @override
  Future<bool> previewAssignment(String code) async {
    checked = code;
    assignmentPreview = {
      'vehicle': {
        'make': 'Fixture',
        'model': 'Sedan',
        'plateNumber': 'TEST_ONLY',
      },
      'owner': {'businessName': 'Fixture Fleet'},
    };
    notifyListeners();
    return true;
  }

  @override
  Future<bool> claimAssignment(String code) async {
    claimed = code;
    notifyListeners();
    return true;
  }
}

void main() {
  testWidgets(
    'six-digit vehicle code preserves leading zeroes and requires confirmation',
    (tester) async {
      final s = AssignmentFixture();
      s.assignmentPreview = {
        'vehicle': {'plateNumber': 'STALE'},
      };
      addTearDown(s.dispose);
      await tester.pumpWidget(host(s, const VehicleAssignmentScreen()));
      expect(
        find.textContaining('Joining is optional for dashboard access'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '123');
      await tester.tap(find.text('Check vehicle assignment'));
      await tester.pumpAndSettle();
      expect(s.checked, isNull);
      expect(find.textContaining('Enter all six digits'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '001234');
      await tester.tap(find.text('Check vehicle assignment'));
      await tester.pumpAndSettle();
      expect(s.checked, '001234');
      expect(find.text('Registration: TEST_ONLY'), findsOneWidget);
      // A change invalidates the preview; a stale preview cannot be confirmed.
      await tester.enterText(find.byType(TextField), '009999');
      await tester.pumpAndSettle();
      expect(find.text('Confirm assigned vehicle'), findsNothing);
      expect(s.claimed, isNull);
    },
  );
}
