import 'package:flutter_test/flutter_test.dart';
import 'package:superapp/app.dart';

void main() {
  testWidgets('app renders without crashing', (tester) async {
    await tester.pumpWidget(const Superapp());
    expect(find.byType(Superapp), findsOneWidget);
  });
}
