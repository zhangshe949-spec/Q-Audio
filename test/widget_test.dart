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
    // 榜单区（热歌榜/新歌榜）与播放历史在加载前也应有标题占位。
    expect(find.text('热歌榜'), findsOneWidget);
    expect(find.text('新歌榜'), findsOneWidget);
    expect(find.text('本地音乐'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
