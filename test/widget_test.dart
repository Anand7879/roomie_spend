import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roomie_spend/main.dart';

void main() {
  testWidgets('App launch and splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame, wrapped in ProviderScope for Riverpod support.
    await tester.pumpWidget(
      const ProviderScope(
        child: RoomieSpendApp(),
      ),
    );

    // Verify that the splash screen displays the app name "ROOMIESPEND"
    expect(find.text('ROOMIESPEND'), findsOneWidget);
    expect(find.text('SHARED LIVING, SIMPLIFIED'), findsOneWidget);
  });
}
