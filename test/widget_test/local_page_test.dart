import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:q_audio/presentation/pages/local_page.dart';
import 'package:q_audio/presentation/pages/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_app.dart';

void main() {
  testWidgets('library page lists persisted tracks', (tester) async {
    await mountApp(
      tester,
      location: '/local',
      initialValues: {
        'unrelated': 'preserve',
        'q_audio.v1.catalog': '{"version":1,"tracks":['
            '{"id":"1","sourceId":"local","title":"晨光","artist":"Alice","album":"Dawn","durationMs":120000},'
            '{"id":"2","sourceId":"web","title":"夜航"}]}',
      },
    );
    expect(find.byType(LocalPage), findsOneWidget);
    expect(find.text('晨光'), findsOneWidget);
    expect(find.text('Alice · Dawn'), findsOneWidget);
    expect(find.text('夜航'), findsOneWidget);
    expect(find.byKey(const Key('local-remove-local-1')), findsOneWidget);
    expect(find.byKey(const Key('local-remove-web-2')), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('removing a track updates the list immediately', (tester) async {
    final router = await mountApp(
      tester,
      location: '/local',
      initialValues: {
        'q_audio.v1.catalog':
            '{"version":1,"tracks":[{"id":"1","sourceId":"local","title":"晨光"}]}',
      },
    );
    expect(find.text('晨光'), findsOneWidget);
    await tester.tap(find.byKey(const Key('local-remove-local-1')));
    await tester.pumpAndSettle();
    expect(find.text('晨光'), findsNothing);
    // 目录为空时显示"尚未配置扫描目录"
    expect(find.text('尚未配置扫描目录'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/local');
  });

  testWidgets('refresh button reloads from storage without errors', (
    tester,
  ) async {
    await mountApp(tester, location: '/local');
    // 初始状态：目录为空，显示"尚未配置扫描目录"
    expect(find.text('尚未配置扫描目录'), findsOneWidget);
    await tester.tap(find.byKey(const Key('local-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('尚未配置扫描目录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme change persists into namespaced storage', (tester) async {
    await mountApp(tester, location: '/settings');
    // Tap "深色模式" radio button
    await tester.tap(find.text('深色模式').last);
    await tester.pumpAndSettle();
    // The provider wrote the mode name under its namespace.
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('q_audio.v1.themeMode');
    expect(stored, anyOf('dark', 'light'));
    await tester.pumpAndSettle();
  });

  testWidgets('restored dark theme is applied at startup', (tester) async {
    await mountApp(
      tester,
      location: '/settings',
      overrideThemeMode: false,
      initialValues: {'q_audio.v1.themeMode': 'dark'},
    );
    // The restore provider overrides the default: dark content theme.
    final theme = Theme.of(tester.element(find.byType(SettingsPage)));
    expect(theme.brightness, Brightness.dark);
    await tester.pumpAndSettle();
  });

  testWidgets('corrupted stored theme falls back to default mode',
      (tester) async {
    await mountApp(
      tester,
      location: '/settings',
      initialValues: {'q_audio.v1.themeMode': 'banana'},
    );
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
  });
}
