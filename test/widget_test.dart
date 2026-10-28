import 'package:flutter_test/flutter_test.dart';

import 'package:reader_app/main.dart';

void main() {
  testWidgets('renders gracefully when storage is unavailable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ReaderApp());
    await tester.pumpAndSettle();

    expect(find.text('Could not load your library'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
