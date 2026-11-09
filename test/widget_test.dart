import 'package:flutter_test/flutter_test.dart';
import 'package:aladdin_basketball/main.dart';

void main() {
  testWidgets('StickBasketballApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StickBasketballApp());
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
  });
}
