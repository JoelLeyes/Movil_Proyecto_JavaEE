import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexo_lab_app/app.dart';

void main() {
  testWidgets('App builds root widget', (WidgetTester tester) async {
    await tester.pumpWidget(const NexoLabApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
