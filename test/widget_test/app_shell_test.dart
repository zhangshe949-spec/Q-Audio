import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_app.dart';

void main() {
  testWidgets('desktop navigation and player placeholder [skipped]', (tester) async {
    // 桌面导航测试需要 bitsdojo_window 原生库，测试环境不可用
    // TODO: 在有原生库的环境中运行（如 CI Windows runner）
    expect(true, isTrue);
  }, skip: true);

  testWidgets('mobile four tabs navigate to radio', (tester) async {
    final router = await mountApp(tester);
    expect(find.byType(NavigationRail), findsNothing);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 4);
    await tester.tap(
      find
          .descendant(of: find.byType(NavigationBar), matching: find.text('电台'))
          .last,
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/radio');
    expect(tester.takeException(), isNull);
  });
}