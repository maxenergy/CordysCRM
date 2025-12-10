import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cordyscrm_flutter/main.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CordysCRMApp(),
      ),
    );

    // 验证应用可以渲染
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
