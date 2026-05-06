import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neoden_yy1_formatter/main.dart' show Yy1FormatterApp;

void main() {
  testWidgets('Import screen shows drag-drop zone', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: Yy1FormatterApp()));
    expect(find.text('NeoDen YY1 Formatter'), findsOneWidget);
    expect(find.text('Select File'), findsOneWidget);
  });
}

