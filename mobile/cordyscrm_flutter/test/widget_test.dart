import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cordyscrm_flutter/main.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    // 创建一个简单的测试路由
    final testRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Test')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: CordysCRMApp(router: testRouter),
      ),
    );

    // 验证应用可以渲染
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
