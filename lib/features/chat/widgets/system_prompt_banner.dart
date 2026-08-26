import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/agents/store/agent_store.dart';
import 'package:agent/features/chat/widgets/chat_expandable_part.dart';
import 'package:agent/rust_bridge/api/agents.dart' as bridge_api;
import 'package:agent/rust_bridge/api/types.dart';
import 'package:agent/services/sync/file_watcher.dart';
import 'package:agent/store/theme_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/markdown/markdown_preview.dart';

/// 消息列表首项的「系统提示词」折叠项（随内容滚动，不固定在视口顶部）。
///
/// 展示当前智能体实际注入 LLM 的全部 system 前置段（MCP 资源 → 运行环境 →
/// 提示词文件 → 技能清单）。内容按注入顺序连续拼接、不分段，与发送给模型
/// 的内容一致。数据由后端同一套拼装逻辑生成（FRB `getSystemPrompts`，
/// 与聊天请求共用 agent-core 的 `build_system_sections`），前端只负责
/// 拉取与渲染：
/// - 挂载 / 切换智能体时拉取；
/// - 监听智能体目录，system_prompt.md 新建/修改/删除后自动重拉（覆盖
///   外部编辑器保存的场景）；监听目录而非文件本身，文件不存在也能建 watch；
/// - 每次展开时再拉一次兜底（技能开关等其它来源的变更）。
/// 全部分段为空（或尚未完成首拉）时整个折叠项不显示。
class SystemPromptBanner extends HookWidget {
  const SystemPromptBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);
    // hooks 必须在所有提前返回之前调用
    final agent = useExistingSignal(AgentStore.instance.currentAgent);
    final markdownFontFamily = useExistingSignal(
      ThemeStore.instance.markdownFontFamily,
    );
    final sections = useState<List<SystemPromptSection>?>(null);

    Future<void> fetch() async {
      final a = AgentStore.instance.currentAgent.value;
      if (a == null || a.configPath.isEmpty) {
        sections.value = const [];
        return;
      }
      try {
        sections.value = await bridge_api.getSystemPrompts(
          configPath: a.configPath,
          workDir: AgentStore.instance.resolveWorkDir(),
        );
      } catch (_) {
        // 引擎不可用等异常：保持现状，等下次触发（展开/目录变化/切换）
      }
    }

    // 拉取时机一：挂载与切换智能体；同时监听智能体目录实现自动刷新。
    // 目录内其它文件（config.json 等）变化触发重拉无妨 —— 本地读取开销极小。
    useEffect(() {
      fetch();
      final dir = agent.value?.directoryPath ?? '';
      WatcherDisposable? watcher;
      if (dir.isNotEmpty) {
        try {
          watcher = watchFileChanges(dir, fetch);
        } catch (_) {}
      }
      return () => watcher?.dispose();
    }, [agent.value?.configPath]);

    final loaded = sections.value;
    if (loaded == null || loaded.isEmpty) return const SizedBox.shrink();

    // 按注入顺序连续拼接（不加分段标题），即模型实际收到的全部 system 内容
    final text = loaded.map((s) => s.content).join('\n\n');
    if (text.isEmpty) return const SizedBox.shrink();

    // Markdown 渲染字体：Markdown 专用设置 > 界面字体设置（同消息正文）
    final textStyle = textStyleForFont(
      markdownFontFamily.value ??
          custom.typography.effectiveFontFamily ??
          kDefaultFontFamily,
      fontSize: custom.typography.bodySize,
      color: custom.colors.textPrimary,
    );

    return Padding(
      // 与消息内 part 的包装完全一致（chat_message_item 的 messagePadding），
      // 保证水平缩进与上下节奏（相邻各贡献 xs 合计 8px）和工具卡片相同
      padding: EdgeInsets.symmetric(
        horizontal: custom.spacing.md,
        vertical: custom.spacing.xs,
      ),
      child: ChatExpandablePart(
        content: text,
        iconName: 'fileCode',
        title: '系统提示词',
        titleColor: custom.colors.textSecondary,
        // 与工具调用卡片一致：不显示左侧竖分割线
        showLeftDivider: false,
        // 用 markdown 渲染替代默认的参数文本；限高内部滚动，避免超长
        // 提示词把消息列表挤没
        argumentsBuilder: (context, raw) => ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: MarkdownPreview(
              text: raw,
              selectable: true,
              textStyle: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}
