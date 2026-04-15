import 'package:flutter_test/flutter_test.dart';
import 'package:chesscoach_ai/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ChessCoachApp());
    expect(find.text('Chess Coach'), findsWidgets);
  });
}
