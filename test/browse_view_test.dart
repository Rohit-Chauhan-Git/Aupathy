import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:reader_app/models/hive_adapters.dart';
import 'package:reader_app/models/novel_model.dart';
import 'package:reader_app/models/plugin_model.dart';
import 'package:reader_app/models/voice_model.dart';
import 'package:reader_app/theme/app_theme.dart';
import 'package:reader_app/views/browse_view.dart';
import 'package:reader_app/views/main_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<PluginModel> pluginsBox;
  late Box<VoiceModel> voicesBox;
  late Box<NovelModel> novelsBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('reader_browse_ui_');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    pluginsBox = await Hive.openBox<PluginModel>('browse_plugins');
    voicesBox = await Hive.openBox<VoiceModel>('browse_voices');
    novelsBox = await Hive.openBox<NovelModel>('browse_novels');
  });

  setUp(() async {
    await pluginsBox.clear();
    await voicesBox.clear();
    await novelsBox.clear();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Widget wrap(Widget child, {double textScale = 1.0}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, appChild) {
        return MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: appChild ?? const SizedBox.shrink(),
        );
      },
      home: child,
    );
  }

  Widget browse({double textScale = 1.0}) {
    return wrap(
      BrowseView(
        pluginsBox: pluginsBox,
        voicesBox: voicesBox,
        novelsBox: novelsBox,
      ),
      textScale: textScale,
    );
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> seedAll(WidgetTester tester) async {
    await tester.runAsync(() async {
      await pluginsBox.putAll(<String, PluginModel>{
        'lantern': const PluginModel(
          id: 1,
          name: 'Lantern Archive',
          packageName: 'com.example.lantern',
          version: '1.2.0',
          description: 'Public domain catalog',
          baseUrl: 'https://lantern.example',
          lang: 'en',
          isInstalled: true,
        ),
        'aria-tts': const PluginModel(
          id: 2,
          name: 'Aria TTS',
          packageName: 'com.example.aria_tts',
          version: '0.9.0',
          description: 'Offline speech engine bridge',
          lang: 'en',
          type: PluginType.tts,
        ),
      });
      await voicesBox.putAll(<String, VoiceModel>{
        'aria': const VoiceModel(
          id: 1,
          name: 'Aria',
          engine: 'sherpa-onnx',
          language: 'en',
          locale: 'en-US',
          gender: 'female',
          isInstalled: true,
        ),
        'mateo': const VoiceModel(
          id: 2,
          name: 'Mateo',
          engine: 'sherpa-onnx',
          language: 'es',
          locale: 'es-ES',
          gender: 'male',
        ),
      });
      await novelsBox.put(
        'novel',
        NovelModel(
          id: 10,
          title: 'The Long Read',
          sourceId: 1,
          sourceName: 'Lantern Archive',
          lastReadAt: DateTime(2026, 3, 2),
        ),
      );
    });
  }

  testWidgets('renders all three tabs and switches between them', (
    tester,
  ) async {
    await tester.pumpWidget(browse());
    await tester.pump();

    expect(find.text('Browse'), findsOneWidget);
    expect(find.byTooltip('LNReader diagnostics'), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Plugins'), findsOneWidget);
    expect(find.text('Voices'), findsOneWidget);
    expect(find.text('No sources available'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
      'Search sources',
    );

    await openTab(tester, 'Plugins');

    expect(find.text('No plugins installed'), findsOneWidget);
    expect(find.text('LNReader repository'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
      'Search plugins',
    );

    await openTab(tester, 'Voices');

    expect(find.text('No voices available'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
      'Search voices',
    );
  });

  testWidgets('sources render, search, and clear', (tester) async {
    await seedAll(tester);
    await tester.pumpWidget(browse());
    await tester.pump();

    expect(find.text('Lantern Archive'), findsOneWidget);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('1 novel'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ariana');
    await tester.pump();

    expect(find.text('No sources found'), findsOneWidget);
    expect(find.text('Lantern Archive'), findsNothing);

    await tester.tap(find.text('Clear search'));
    await tester.pump();

    expect(find.text('Lantern Archive'), findsOneWidget);
  });

  testWidgets('plugins render, filter by status, and clear search', (
    tester,
  ) async {
    await seedAll(tester);
    await tester.pumpWidget(browse());
    await tester.pump();

    await openTab(tester, 'Plugins');

    expect(find.text('LNReader repository'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
    await tester.pump();

    expect(find.text('Lantern Archive'), findsOneWidget);
    expect(find.text('Aria TTS'), findsOneWidget);
    expect(find.text('Installed'), findsWidgets);
    expect(find.text('Not installed'), findsWidgets);
    expect(find.text('com.example.lantern · v1.2.0'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text('No plugins found'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Installed'));
    await tester.pump();
    expect(find.text('Aria TTS'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Not installed'));
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
    await tester.pump();

    expect(find.text('Aria TTS'), findsOneWidget);
    expect(find.text('Lantern Archive'), findsNothing);
  });

  testWidgets('voices render, search, and filter by language', (tester) async {
    await seedAll(tester);
    await tester.pumpWidget(browse());
    await tester.pump();

    await openTab(tester, 'Voices');

    expect(find.text('Aria'), findsOneWidget);
    expect(find.text('Mateo'), findsOneWidget);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('Not installed'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'mateo');
    await tester.pump();

    expect(find.text('Mateo'), findsOneWidget);
    expect(find.text('Aria'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing');
    await tester.pump();
    expect(find.text('No voices found'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pump();
    expect(find.text('Aria'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'ES'));
    await tester.pump();

    expect(find.text('Mateo'), findsOneWidget);
    expect(find.text('Aria'), findsNothing);
  });

  testWidgets('persists plugin enablement and voice favorites', (tester) async {
    await seedAll(tester);
    await tester.pumpWidget(browse());
    await tester.pump();

    await openTab(tester, 'Plugins');

    await tester.runAsync(() async {
      await tester.tap(find.byType(Switch));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(pluginsBox.get('lantern')?.isEnabled, isFalse);
    expect(find.text('Disabled'), findsOneWidget);

    await openTab(tester, 'Voices');

    final ariaFavoriteButton = find.descendant(
      of: find.byKey(const ValueKey<String>('voice-1')),
      matching: find.byTooltip('Add to favorites'),
    );
    await tester.runAsync(() async {
      await tester.tap(ariaFavoriteButton);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(voicesBox.get('aria')?.isFavorite, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('voice-1')),
        matching: find.byTooltip('Remove from favorites'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('search query is preserved when switching tabs', (tester) async {
    await seedAll(tester);
    await tester.pumpWidget(browse());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'aria');
    await tester.pump();

    await openTab(tester, 'Plugins');

    expect(find.text('Aria TTS'), findsOneWidget);
    expect(find.text('Lantern Archive'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'aria',
    );
  });

  testWidgets('shows a graceful error when Browse storage is unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const BrowseView()),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not load Browse'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Could not load Browse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out every tab on a small screen at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await seedAll(tester);
    await tester.pumpWidget(browse(textScale: 2.0));
    await tester.pump();

    expect(tester.takeException(), isNull);

    await openTab(tester, 'Plugins');
    expect(tester.takeException(), isNull);

    await openTab(tester, 'Voices');
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('MainShell opens Browse with all three tabs', (tester) async {
    await seedAll(tester);
    await tester.pumpWidget(
      wrap(
        MainShell(
          novelsBox: novelsBox,
          pluginsBox: pluginsBox,
          voicesBox: voicesBox,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Browse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Plugins'), findsOneWidget);
    expect(find.text('Voices'), findsOneWidget);
    expect(find.text('Lantern Archive'), findsOneWidget);

    await openTab(tester, 'Voices');
    expect(find.text('Aria'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
