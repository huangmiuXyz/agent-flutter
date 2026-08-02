import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/icon/app_icon.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 服务端联网搜索标签：搜索词或打开的页面一行平铺展示，无需展开。
///
/// 解析 `web_search` part 的 JSON content（provider 返回的完整输出项）：
/// - 搜索动作：`action.queries`（DeepSeek 等端点不返回标准 `search_query`）
/// - 打开页面动作：`action.url`
/// - 没有内容时（搜索中/失败）退回状态文字
///
/// 用于两处展示：深度思考块内穿插（思考阶段发起的搜索），
/// 以及独立位置（答案阶段发起的搜索 / 无思考的搜索）。
class ChatSearchPart extends StatelessWidget {
  const ChatSearchPart({super.key, required this.content});

  /// web_search part 的 JSON 内容
  final String content;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    String status = '';
    String query = '';
    final queries = <String>[];
    String? openUrl;
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      status = json['status'] as String? ?? '';
      query = json['search_query'] as String? ?? '';
      final action = json['action'];
      if (action is Map<String, dynamic>) {
        final actionType = action['type'] as String?;
        if (actionType == 'search') {
          final qs = action['queries'];
          if (qs is List) {
            // 过滤 DeepSeek 塞进数组的 ws_call_id 回调标记
            queries.addAll(
              qs.whereType<String>().where(
                (q) => q.isNotEmpty && !q.startsWith('ws_call_id='),
              ),
            );
          }
        } else if (actionType == 'open_page') {
          openUrl = action['url'] as String?;
        }
      }
    } catch (_) {}

    final statusText = switch (status) {
      'in_progress' || 'searching' => '搜索中…',
      'completed' => '搜索完成',
      'failed' => '搜索失败',
      _ => '联网搜索',
    };
    // 单行展示内容本身：搜索词或打开的页面 URL（两者不会同时出现），
    // 没有内容时（搜索中/失败）才退回状态文字
    final displayText = [if (query.isNotEmpty) query, ...queries].join(' · ');
    final text = displayText.isNotEmpty
        ? displayText
        : (openUrl != null && openUrl.isNotEmpty
              ? _cleanPageUrl(openUrl)
              : statusText);

    return Row(
      children: [
        AppIcon(
          'search',
          size: custom.typography.captionSize,
          color: custom.colors.accent,
        ),
        SizedBox(width: custom.spacing.xs),
        Expanded(
          child: AppText(
            text,
            variant: AppTextVariant.caption,
            color: custom.colors.accent,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 去掉 DeepSeek 追加在页面 URL 末尾的回调标记（#ws_call_id=...）
  String _cleanPageUrl(String url) {
    final idx = url.indexOf('#ws_call_id=');
    if (idx > 0) return url.substring(0, idx);
    return url;
  }
}
