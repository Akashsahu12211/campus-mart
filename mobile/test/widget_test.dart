import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('basic widget harness loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Text('Campus Mart'),
      ),
    ));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Campus Mart'), findsOneWidget);
  });
}
