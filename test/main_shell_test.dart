import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:reader_app/models/hive_adapters.dart';
import 'package:reader_app/models/novel_model.dart';
import 'package:reader_app/theme/app_theme.dart';
import 'package:reader_app/views/main_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<NovelModel> novelsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_shell_ui_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    novelsBox = await Hive.openBox<NovelModel>('novels');
  });

  setUp(() async {
    await novelsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Widget wrap(Widget child) {
    return MaterialApp(theme: AppTheme.darkTheme, home: child);
  }

  int selectedIndex(WidgetTester tester) {
    return tester
        .widget<NavigationBar>(find.byType(NavigationBar))
        .selectedIndex;
  }

  testWidgets('shows Library by default with all navigation sections', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(MainShell(novelsBox: novelsBox)));
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Library'),
      ),
      findsOneWidget,
    );
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text('Your library is empty'), findsOneWidget);
    expect(selectedIndex(tester), 0);
  });

  testWidgets('switches sections and preserves the Library search query', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(MainShell(novelsBox: novelsBox)));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'aria');
    await tester.pump();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(selectedIndex(tester), 1);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(selectedIndex(tester), 0);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'aria');
  });

  testWidgets('system back returns to Library from another section', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(MainShell(novelsBox: novelsBox)));
    await tester.pump();

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(selectedIndex(tester), 2);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(selectedIndex(tester), 0);
  });
}
