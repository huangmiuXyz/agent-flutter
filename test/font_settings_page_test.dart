import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/features/settings/pages/font_settings_page.dart';
import 'package:agent/theme/app_theme.dart';
import 'package:agent/widgets/list/app_big_list.dart';

void main() {
  testWidgets('FontSettingsPage renders header, search and sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 700,
            child: FontSettingsPage(onBack: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 面包屑导航（返回入口）
    expect(find.text('显示设置'), findsOneWidget);
    expect(find.text('字体设置'), findsOneWidget);

    // 列表外壳 + header（计数）
    expect(find.byType(AppBigList), findsOneWidget);
    expect(find.text('个字体'), findsOneWidget);

    // 分组
    expect(find.text('本地捆绑'), findsOneWidget);
    expect(find.text('未下载'), findsOneWidget);

    // 筛选按钮
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('中文'), findsOneWidget);

    // 搜索无结果 → 显示空状态
    await tester.enterText(find.byType(TextField), 'zzzz_no_such_font');
    await tester.pumpAndSettle();
    expect(find.text('未找到匹配的字体'), findsOneWidget);
  });
}
