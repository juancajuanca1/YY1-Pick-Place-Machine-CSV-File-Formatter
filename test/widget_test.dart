import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:neoden_yy1_formatter/main.dart' show Yy1FormatterApp;

void main() {
  testWidgets('Home screen shows both PCB tools', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: Yy1FormatterApp()));
    expect(find.text('NeoDen YY1 Formatter'), findsOneWidget);
    expect(find.text('Cricut Stencil Generator'), findsOneWidget);
  });

  testWidgets('each tool has an explicit return-to-home control', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: Yy1FormatterApp()));

    await tester.tap(find.text('Cricut Stencil Generator'));
    await tester.pumpAndSettle();
    expect(find.text('Select Gerber Folder'), findsOneWidget);
    expect(find.textContaining('exact 1:1 scale'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Home'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Home'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('NeoDen YY1 Formatter'));
    await tester.pumpAndSettle();
    expect(find.text('Select File'), findsOneWidget);
    expect(find.textContaining('Use millimeters (mm)'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Home'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Home'));
    await tester.pumpAndSettle();
    expect(find.text('What would you like to make?'), findsOneWidget);
  });
}
