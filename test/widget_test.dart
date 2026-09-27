import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:infurnus_driver/main.dart';
import 'package:infurnus_driver/providers/app_state.dart';

void main() {
  testWidgets('InfurnusApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const InfurnusApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Driver Dashboard'), findsOneWidget);
  });
}
