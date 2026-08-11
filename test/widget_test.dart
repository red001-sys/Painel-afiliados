import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds a MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Nex Vendedores'))),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Nex Vendedores'), findsOneWidget);
  });
}
