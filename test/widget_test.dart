import 'package:flutter/material.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:q_audio/presentation/pages/home_page.dart';

import 'test_app.dart';

void main() {
  testWidgets('application home smoke test', (tester) async {
    await mountApp(tester);
    expect(find.byType(HomePage), findsOneWidget);
    // Home is now a real page: search box + quick entries + hot keywords.
    expect(find.byKey(const Key('home-search')), findsOneWidget);
    expect(find.text('快捷入口'), findsOneWidget);
    expect(find.text('热门推荐'), findsOneWidget);
    expect(find.text('本地音乐'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
