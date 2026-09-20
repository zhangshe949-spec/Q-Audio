import 'package:flutter_test/flutter_test.dart';
import 'package:q_audio/presentation/pages/home_page.dart';

import 'test_app.dart';

void main() {
  testWidgets('application home smoke test', (tester) async {
    await mountApp(tester);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.textContaining('尚未接入音源'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
