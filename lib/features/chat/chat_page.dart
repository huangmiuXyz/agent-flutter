import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:agent/rust_bridge/api.dart' as api;
import 'package:agent/services/llm_service.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/widgets/button/app_primary_button.dart';
import 'package:agent/widgets/field/app_field.dart';
import 'package:agent/widgets/text/app_text.dart';
import 'package:agent/widgets/card/app_card.dart';

/// Chat Demo — 通过 FRB 调用 Rust 引擎进行聊天
class ChatDemo extends HookConsumerWidget {
  const ChatDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = CustomTheme.of(context);
    final service = useState<LlmService?>(null);
    final messages = useState<List<_ChatMessage>>([]);
    final promptController = useTextEditingController();
    final configPathController = useTextEditingController(text: 'config.json');
    final providerController = useTextEditingController(text: 'deepseek');
    final modelController = useTextEditingController(text: 'deepseek-v4-flash');
    final isSending = useState(false);
    final scrollController = useScrollController();
    final isLoading = useState(false);

    // 初始化服务
    useEffect(() {
      () async {
        isLoading.value = true;
        try {
          final svc = LlmService();
          await svc.init();
          service.value = svc;
        } catch (e) {
          messages.value = [
            _ChatMessage(
              role: 'system',
              text: '初始化失败: $e\n请确认 config.json 路径正确',
            ),
          ];
        }
        isLoading.value = false;
      }();
      return null;
    }, []);

    Future<void> sendMessage() async {
      final text = promptController.text.trim();
      if (text.isEmpty || service.value == null) return;

      promptController.clear();
      isSending.value = true;

      // 添加用户消息 + 占位助理消息
      messages.value = [
        ...messages.value,
        _ChatMessage(role: 'user', text: text),
        _ChatMessage(role: 'assistant', text: ''),
      ];
      final msgIndex = messages.value.length - 1;

      // 流式接收回复
      try {
        await for (final event in service.value!.chatStream(
          configPath: configPathController.text,
          provider: providerController.text,
          model: modelController.text,
          prompt: text,
        )) {
          final current = [...messages.value];
          switch (event) {
            case api.StreamEvent_Text(:final field0):
              current[msgIndex] = _ChatMessage(
                role: 'assistant',
                text: current[msgIndex].text + field0,
              );
              messages.value = current;
              _scrollToBottom(scrollController);
            case api.StreamEvent_ToolCall(:final name, :final arguments):
              current[msgIndex] = _ChatMessage(
                role: 'assistant',
                text: '${current[msgIndex].text}\n\n⚙️ $name($arguments)\n',
              );
              messages.value = current;
            case api.StreamEvent_Done():
              break;
            case api.StreamEvent_Error(:final field0):
              current[msgIndex] = _ChatMessage(
                role: 'assistant',
                text: '${current[msgIndex].text}\n\n❌ 错误: $field0',
              );
              messages.value = current;
          }
        }
      } catch (e) {
        final current = [...messages.value];
        current[msgIndex] = _ChatMessage(role: 'assistant', text: '❌ 错误: $e');
        messages.value = current;
      }

      isSending.value = false;
      _scrollToBottom(scrollController);
    }

    return Column(
      children: [
        // 参数栏
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: AppField(
                  controller: configPathController,
                  label: 'Config',
                  placeholder: 'config.json',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppField(
                  controller: providerController,
                  label: 'Provider',
                  placeholder: 'deepseek, openai, ...',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppField(
                  controller: modelController,
                  label: 'Model',
                  placeholder: 'deepseek-v4-flash',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // 消息列表
        Expanded(
          child: messages.value.isEmpty
              ? Center(
                  child: isLoading.value
                      ? const CircularProgressIndicator()
                      : AppText('输入消息开始聊天', color: custom.colors.textSecondary),
                )
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: messages.value.length,
                  itemBuilder: (context, index) {
                    final msg = messages.value[index];
                    final isUser = msg.role == 'user';
                    final isSystem = msg.role == 'system';
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 2,
                        horizontal: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: isUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: isSystem
                                    ? custom.colors.warning.withValues(
                                        alpha: 0.1,
                                      )
                                    : isUser
                                    ? custom.colors.accent.withValues(
                                        alpha: 0.15,
                                      )
                                    : custom.colors.panel,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: AppText(
                                msg.text.isEmpty
                                    ? (isSending.value && !isUser ? '▊' : '')
                                    : msg.text,
                                color: isSystem ? custom.colors.warning : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // 输入栏
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: AppField(
                  controller: promptController,
                  placeholder: '输入消息...',
                  onSubmitted: isSending.value || service.value == null
                      ? null
                      : (_) => sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              AppPrimaryButton(
                text: '发送',
                onPressed: isSending.value || service.value == null
                    ? null
                    : sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _scrollToBottom(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

/// 聊天消息模型
class _ChatMessage {
  final String role;
  final String text;

  const _ChatMessage({required this.role, required this.text});
}
