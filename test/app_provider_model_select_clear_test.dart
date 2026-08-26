import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:agent/theme/app_theme.dart';
import 'package:agent/widgets/select/app_provider_model_select.dart';

void main() {
  testWidgets('选择（不设置）后应回传空串并回显占位文案', (tester) async {
    String? received = 'keep';
    const modelKey = '["opencode-go","deepseek-v4-flash"]';
    String? current = modelKey;

    await tester.pumpWidget(
      MaterialApp(
        theme: appDarkTheme,
        home: Scaffold(
          body: HookBuilder(
            builder: (context) {
              final value = useState<String?>(current);
              return AppProviderModelSelect(
                label: '标题生成模型（可选）',
                placeholder: '留空则取首条消息前 20 字',
                value: value.value,
                allowClear: true,
                onChanged: (v) {
                  received = v;
                  // 模拟 agent_edit_page.applyModelSelection
                  if (v == null || v.isEmpty) {
                    value.value = null;
                  } else {
                    final d = AppProviderModelSelect.decodeKey(v);
                    if (d != null) value.value = v;
                  }
                },
              );
            },
          ),
        ),
      ),
    );

    // 打开下拉
    await tester.tap(find.byType(AppProviderModelSelect));
    await tester.pumpAndSettle();

    // 点「（不设置）」
    await tester.tap(find.text('（不设置）'));
    await tester.pumpAndSettle();

    expect(received, '', reason: 'onChanged 应回传空串');

    // 输入框应回到占位文案，而不是继续显示已选模型
    expect(find.text('留空则取首条消息前 20 字'), findsOneWidget);
    expect(find.textContaining('deepseek-v4-flash'), findsNothing);
  });
}
