import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('SOS Example app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify header, initial status, and action button are rendered.
    expect(find.text('SOS System Test Bench'), findsOneWidget);
    expect(find.text('Engine Stopped'), findsOneWidget);
    expect(find.text('Start Detection'), findsOneWidget);
    expect(find.text('No anomalies recorded yet.'), findsOneWidget);
  });
}
