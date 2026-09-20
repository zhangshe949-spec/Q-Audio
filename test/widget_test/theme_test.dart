import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:q_audio/core/theme/app_theme.dart';
import 'package:q_audio/presentation/pages/settings_page.dart';

import '../test_app.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('initial theme $mode applies to content', (tester) async {
      await mountApp(tester, location: '/settings', mode: mode);
      final theme = Theme.of(tester.element(find.byType(SettingsPage)));
      expect(
        theme.brightness,
        mode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      expect(
        theme.colorScheme.primary,
        mode == ThemeMode.dark ? AppColors.darkPrimary : AppColors.lightPrimary,
      );
    });
  }
  testWidgets('theme toggle retains router location', (tester) async {
    final router = await mountApp(tester, location: '/settings');
    // Tap "深色模式" radio button
    await tester.tap(find.text('深色模式').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.byType(SettingsPage))).brightness,
      Brightness.dark,
    );
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    // Tap "浅色模式" radio button
    await tester.tap(find.text('浅色模式').last);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(SettingsPage))).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });
}
