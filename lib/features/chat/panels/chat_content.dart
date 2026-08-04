import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:agent/services/session/part_types.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart' show readingWidth;
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/features/chat/chat_input.dart';
import 'package:agent/features/chat/widgets/chat_message_item.dart';
import 'package:agent/features/chat/widgets/message_queue_panel.dart';
import 'package:agent/widgets/loading/app_loading.dart';

/// 保持底部用户在流式输出时始终在底部。
/// 非 reverse 列表下，内容向下生长不影响离开底部的用户。
class _KeepAtBottomPhysics extends ScrollPhysics {
  /// onBeforeEmit 时保存的 maxScrollExtent
  final double? savedMaxExtent;

  const _KeepAtBottomPhysics({super.parent, this.savedMaxExtent});

  @override
  _KeepAtBottomPhysics applyTo(ScrollPhysics? ancestor) {
    return _KeepAtBottomPhysics(
      parent: buildParent(ancestor),
      savedMaxExtent: savedMaxExtent,
    );
  }

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    if (savedMaxExtent != null) {
      final growth = newPosition.maxScrollExtent - savedMaxExtent!;
      if (growth.abs() > 0.5) {
        // 用户在底部 → 滚到新底部
        return newPosition.maxScrollExtent;
      }
    }
    return super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
  }
}

const double _listBottomSpacing = 40;

class _StreamingMessage extends StatelessWidget {
  final Widget child;

  const _StreamingMessage({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 20), child: child),
        const Positioned(left: 16, bottom: 0, child: AppLoading()),
      ],
    );
  }
}

class _StandaloneStreamingIndicator extends StatelessWidget {
  const _StandaloneStreamingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      child: Stack(
        children: [Positioned(left: 16, bottom: 0, child: AppLoading())],
      ),
    );
  }
}

/// 最新一轮先按自然高度布局用户消息，再让助手区域填满视口剩余高度。
class _LatestTurnLayout extends MultiChildRenderObjectWidget {
  final double minHeight;

  _LatestTurnLayout({
    required this.minHeight,
    required Widget user,
    required Widget assistant,
  }) : super(children: [user, assistant]);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLatestTurnLayout(minHeight);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderLatestTurnLayout renderObject,
  ) {
    renderObject.minHeight = minHeight;
  }
}

class _LatestTurnParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderLatestTurnLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _LatestTurnParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _LatestTurnParentData> {
  _RenderLatestTurnLayout(this._minHeight);

  double _minHeight;

  set minHeight(double value) {
    if (_minHeight == value) return;
    _minHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LatestTurnParentData) {
      child.parentData = _LatestTurnParentData();
    }
  }

  BoxConstraints _constraintsForChild(
    BoxConstraints constraints, {
    double minHeight = 0,
  }) {
    return BoxConstraints(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
      minHeight: minHeight,
      maxHeight: double.infinity,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final user = firstChild;
    final assistant = user == null ? null : childAfter(user);
    if (user == null || assistant == null) {
      return constraints.constrain(Size.zero);
    }

    final userSize = user.getDryLayout(_constraintsForChild(constraints));
    final assistantMinHeight = math.max(0.0, _minHeight - userSize.height);
    final assistantSize = assistant.getDryLayout(
      _constraintsForChild(constraints, minHeight: assistantMinHeight),
    );

    return constraints.constrain(
      Size(
        math.max(userSize.width, assistantSize.width),
        userSize.height + assistantSize.height,
      ),
    );
  }

  @override
  void performLayout() {
    final user = firstChild;
    final assistant = user == null ? null : childAfter(user);
    if (user == null || assistant == null) {
      size = constraints.constrain(Size.zero);
      return;
    }

    user.layout(_constraintsForChild(constraints), parentUsesSize: true);
    final assistantMinHeight = math.max(0.0, _minHeight - user.size.height);
    assistant.layout(
      _constraintsForChild(constraints, minHeight: assistantMinHeight),
      parentUsesSize: true,
    );

    final userParentData = user.parentData! as _LatestTurnParentData;
    final assistantParentData = assistant.parentData! as _LatestTurnParentData;
    userParentData.offset = Offset.zero;
    assistantParentData.offset = Offset(0, user.size.height);

    size = constraints.constrain(
      Size(
        math.max(user.size.width, assistant.size.width),
        user.size.height + assistant.size.height,
      ),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

/// 聊天内容区 — 消息列表 + 队列面板 + 输入框
///
/// 流式输出中按 Enter 发送的消息自动进入队列，
/// 当前回复结束后自动发出。
class ChatContent extends StatelessWidget {
  const ChatContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (_) {
        final displayId = SessionStore.instance.displayedSessionId.value;
        // 没有任何消息时输入框全屏显示（新会话/空会话）
        final hasMessages =
            displayId != null &&
            (SessionStore
                    .instance
                    .sessions
                    .value[displayId]
                    ?.messageOrder
                    .isNotEmpty ??
                false);

        // 有消息时无需 LayoutBuilder（避免 resize 时级联重建），
        // 空会话时才需要 LayoutBuilder 获取 maxHeight 给全屏输入框
        if (hasMessages) {
          return Column(
            key: const ValueKey('chat_with_messages'),
            children: [
              Expanded(child: _MessageList(sessionId: displayId)),
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: readingWidth,
                  child: const MessageQueuePanel(),
                ),
              ),
              const AppDivider(extent: 1, thickness: 1),
              const SizedBox(
                key: ValueKey('inputSlot'),
                child: ChatInput(fullHeight: false),
              ),
            ],
          );
        }

        return LayoutBuilder(
          key: const ValueKey('chat_empty'),
          builder: (context, constraints) {
            final maxH = constraints.maxHeight;
            // 注：Column 的非 flex 子级主轴约束无界，因此全屏高度
            // 必须由这里显式给出，不能靠内部 Expanded 自动撑满。
            return SizedBox(
              key: const ValueKey('inputSlot'),
              height: maxH.isFinite
                  ? maxH
                  : MediaQuery.sizeOf(context).height,
              child: ChatInput(fullHeight: true),
            );
          },
        );
      },
    );
  }
}

/// 消息列表 — ListView 非 reverse，流式内容向下生长
class _MessageList extends StatelessWidget {
  final String sessionId;

  const _MessageList({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final custom = CustomTheme.of(context);

    return SignalBuilder(
      builder: (_) {
        final mgr = SessionStore.instance;
        final sessionState = mgr.sessions.value[sessionId];
        if (sessionState == null) return const SizedBox.shrink();

        final messageOrder = sessionState.messageOrder;
        final partsByMsg = sessionState.partsByMsg;
        final messageRoles = sessionState.messageRoles;
        final messageModels = sessionState.messageModels;

        if (messageOrder.isEmpty) return const SizedBox.shrink();

        final isFirstInTurn = _computeFirstInTurn(messageOrder, messageRoles);

        final isStreaming = mgr.streamingSessionIds.value.contains(sessionId);
        final latestUserIndex = messageOrder.lastIndexWhere(
          (msgId) => messageRoles[msgId] == 'user',
        );

        return HookBuilder(
          key: ValueKey('msglist_$sessionId'),
          builder: (context) {
            final scrollController = useScrollController();
            final focusedMsgId = useState<String?>(null);
            final savedMaxExtent = useRef<double?>(null);
            // 切换 session 时：先隐藏 ListView → jumpTo 底部 → 再显示
            final isListVisible = useState(false);

            // 监听滚动位置，离开底部时清空 physics 保留位
            useEffect(() {
              void onScroll() {
                if (!scrollController.hasClients) return;
                if (scrollController.position.extentAfter > 0) {
                  savedMaxExtent.value = null;
                }
              }

              scrollController.addListener(onScroll);
              return () => scrollController.removeListener(onScroll);
            }, [scrollController]);

            // ── 切换 session：先隐藏 → jumpTo 底部 → 再显示 ──
            useEffect(() {
              isListVisible.value = false;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scrollController.hasClients) return;
                scrollController.jumpTo(
                  scrollController.position.maxScrollExtent,
                );
                isListVisible.value = true;
              });
              return null;
            }, [sessionId]);

            // ── 新消息/流式：只滚动到底部，不隐藏 ──
            useEffect(() {
              if (!isListVisible.value) return null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scrollController.hasClients) return;
                scrollController.jumpTo(
                  scrollController.position.maxScrollExtent,
                );
              });
              return null;
            }, [messageOrder.length]);

            // 流式输出中，用户在底部则保存 maxScrollExtent 供 physics 使用
            useEffect(() {
              final mgr = SessionStore.instance;
              mgr.onBeforeEmit = () {
                if (!scrollController.hasClients) return;
                final streaming = mgr.streamingSessionIds.value.contains(
                  sessionId,
                );
                if (!streaming) {
                  savedMaxExtent.value = null;
                  return;
                }
                if (scrollController.position.extentAfter <= 0) {
                  savedMaxExtent.value =
                      scrollController.position.maxScrollExtent;
                }
              };
              return () {
                SessionStore.instance.onBeforeEmit = null;
              };
            }, [sessionId, scrollController]);

            final focusedIndex = focusedMsgId.value == null
                ? -1
                : messageOrder.indexOf(focusedMsgId.value!);

            Widget buildMessage(
              int index, {
              bool showStreamingIndicator = true,
            }) {
              final msgId = messageOrder[index];
              final parts = partsByMsg[msgId] ?? [];
              final role = messageRoles[msgId] ?? '';

              // 纯工具类消息不占位
              if (parts.isNotEmpty && PartTypes.isToolOnly(parts)) {
                return const SizedBox.shrink();
              }

              final messageItem = ChatMessageItem(
                key: ValueKey(msgId),
                sessionId: sessionId,
                msgId: msgId,
                role: role,
                parts: parts,
                streaming: isStreaming,
                modelName: isFirstInTurn[index] == true
                    ? messageModels[msgId]
                    : null,
                dimmed: focusedIndex >= 0 && index > focusedIndex,
                onFocusChanged: (focused) {
                  focusedMsgId.value = focused ? msgId : null;
                },
                onRetry: (msgId, newContent, imagePaths, imageNames) {
                  final mgr = SessionStore.instance;
                  mgr.retryMessage(
                    sessionId: sessionId,
                    msgId: msgId,
                    newPrompt: newContent,
                    provider: ConfigStore.instance.currentProvider.value,
                    model: ConfigStore.instance.currentModel.value,
                    imagePaths: imagePaths,
                    imageNames: imageNames,
                  );
                },
              );

              // 流式输出中，最后一条消息下方显示 loading
              if (showStreamingIndicator &&
                  isStreaming &&
                  index == messageOrder.length - 1) {
                return _StreamingMessage(child: messageItem);
              }

              return messageItem;
            }

            // ── ViewHeight 从 LayoutBuilder 捕获，_LatestTurnLayout 通过
            // ValueListenableBuilder 监听高度变化，resize 时只重建最后一条
            // item，前面 N-1 条稳定不动。
            final viewHeight = useRef(ValueNotifier<double>(0));

            final hasLatestTurn = latestUserIndex >= 0;
            final itemCount = hasLatestTurn
                ? latestUserIndex + 1
                : messageOrder.length;

            final listView = ListView.builder(
              controller: scrollController,
              physics: savedMaxExtent.value != null
                  ? _KeepAtBottomPhysics(
                      savedMaxExtent: savedMaxExtent.value,
                    )
                  : null,
              padding: EdgeInsets.only(
                top: 0,
                bottom: hasLatestTurn ? 0 : _listBottomSpacing,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (!hasLatestTurn || index < latestUserIndex) {
                  return buildMessage(index);
                }

                final assistantMessages = <Widget>[
                  for (int i = latestUserIndex + 1;
                      i < messageOrder.length;
                      i++)
                    buildMessage(i),
                  if (isStreaming &&
                      latestUserIndex == messageOrder.length - 1)
                    const _StandaloneStreamingIndicator(),
                  const SizedBox(height: _listBottomSpacing),
                ];

                return ValueListenableBuilder<double>(
                  valueListenable: viewHeight.value,
                  builder: (context, height, _) {
                    final minLatestHeight = latestUserIndex > 0
                        ? height
                        : height - custom.spacing.sm;
                    return _LatestTurnLayout(
                      minHeight: minLatestHeight,
                      user: buildMessage(
                        latestUserIndex,
                        showStreamingIndicator: false,
                      ),
                      assistant: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: assistantMessages,
                      ),
                    );
                  },
                );
              },
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                // 每次布局更新高度通知器（resize 拖拽时触发），
                // ValueListenableBuilder 会单独重建 _LatestTurnLayout
                viewHeight.value.value = constraints.maxHeight;
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: readingWidth,
                    child: Opacity(
                      opacity: isListVisible.value ? 1.0 : 0.0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        child: listView,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<bool> _computeFirstInTurn(
    List<String> messageOrder,
    Map<String, String> messageRoles,
  ) {
    final result = List<bool>.filled(messageOrder.length, false);
    bool waitingForAssistant = true;
    for (int i = 0; i < messageOrder.length; i++) {
      final role = messageRoles[messageOrder[i]];
      if (role == 'user') {
        waitingForAssistant = true;
      } else if (role == 'assistant' && waitingForAssistant) {
        result[i] = true;
        waitingForAssistant = false;
      }
    }
    return result;
  }
}
