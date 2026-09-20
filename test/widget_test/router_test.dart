import 'package:flutter_test/flutter_test.dart';

import '../test_app.dart';

void main() {
  testWidgets('desktop settings navigation is functional [skipped]', (tester) async {
    // 桌面导航测试需要 bitsdojo_window 原生库，测试环境不可用
    // TODO: 在有原生库的环境中运行（如 CI Windows runner）
    expect(true, isTrue);
  }, skip: true);

  testWidgets('all declared routes render without exceptions', (tester) async {
    final router = await mountApp(tester);
    for (final path in [
      '/',
      '/search',
      '/radio',
      '/audiobook',
      '/podcast',
      '/local',
      '/playlist',
      '/downloads',
      '/settings',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(tester.takeException(), isNull, reason: path);
    }
  });
}