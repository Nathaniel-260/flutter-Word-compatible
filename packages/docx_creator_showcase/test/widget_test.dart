import 'package:flutter_test/flutter_test.dart';

import 'package:docx_creator_showcase/main.dart';

void main() {
  testWidgets('Showcase app renders the overview screen', (tester) async {
    await tester.pumpWidget(const ShowcaseApp());
    await tester.pumpAndSettle();

    expect(find.text('docx_creator'), findsOneWidget);
    expect(find.text('Explore every feature'), findsOneWidget);
  });
}
