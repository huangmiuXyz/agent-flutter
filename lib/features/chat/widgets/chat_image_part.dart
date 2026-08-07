import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:agent/services/image_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/text/app_text.dart';

/// 解析 image part 内容：`{"file": 存储名, "name": 原始名}` JSON，
/// 兼容旧数据（content 直接是存储文件名）。返回 (存储名, 原始名)。
({String stored, String display}) parseImagePartContent(String content) {
  try {
    final json = jsonDecode(content);
    if (json is Map<String, dynamic>) {
      final stored = json['file'] as String? ?? content;
      final display = json['name'] as String? ?? '';
      return (stored: stored, display: display.isEmpty ? stored : display);
    }
  } catch (_) {}
  return (stored: content, display: content);
}

/// 图片附件 part — 渲染缩略图 + 原始文件名（点击查看大图）。
///
/// [content] 为 image part 的内容（`{"file":..., "name":...}` JSON），
/// 文件缺失时显示占位图标。
class ChatImagePart extends StatelessWidget {
  const ChatImagePart({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    final store = ImageStore.instance;
    final parsed = parseImagePartContent(content);
    final path = store.resolvePath(parsed.stored);
    final exists = store.exists(parsed.stored);

    return GestureDetector(
      onTap: () {
        if (!exists) return;
        showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
              child: InteractiveViewer(
                maxScale: 8,
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: custom.colors.hover,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: custom.colors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exists)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Image.file(
                  File(path),
                  width: 20,
                  height: 20,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.image_outlined,
                    size: 18,
                    color: custom.colors.textSecondary,
                  ),
                ),
              )
            else
              Icon(
                Icons.image_outlined,
                size: 18,
                color: custom.colors.textSecondary,
              ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: AppText(
                parsed.display,
                variant: AppTextVariant.caption,
                overflow: TextOverflow.ellipsis,
                color: custom.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
