// RenderEditableContainerBox 未从 fleather 公开导出；版本已在 pubspec.lock 锁定
// （fleather 1.27.0），内部路径引用可接受。
// ignore: implementation_imports
import 'package:fleather/src/rendering/editable_box.dart'
    show RenderEditableContainerBox;
import 'package:flutter/gestures.dart' show HitTestResult, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderAbstractViewport, RenderEditable, ScrollCacheExtent;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/rust_bridge/api/types.dart' as api;
import 'package:agent/services/session/part_types.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart' show readingWidth;
import 'package:agent/widgets/divider/app_divider.dart';
import 'package:agent/features/chat/chat_fleather.dart';
import 'package:agent/features/chat/chat_input.dart';
import 'package:agent/features/chat/widgets/chat_message_item.dart';
import 'package:agent/features/chat/widgets/chat_text_part.dart';
import 'package:agent/features/chat/widgets/message_anchors_panel.dart';
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
      if (growth.abs() > 0) {
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

/// 用户消息估算高度（锚点比例用，未测量区域按此累计；点击跳转有
/// 离屏测量兜底，估算值只影响锚点概览位置，不需要精确）
const double _estUserMsgHeight = 64;
const double _estToolCardHeight = 88;
const double _estImageHeight = 240;
const double _estSearchHeight = 96;
const double _estReasoningHeight = 56;

/// 估算高度：阅读宽度约半屏，正文 14px 行高约 28px（含段间距），
/// 每行约 56 个中文字符；markdown 段落间距一并计入，避免锚点
/// 比例整体偏低（历史经验：行高 24 / 每行 70 字低估约 40%）
const double _estTextCharsPerLine = 56;
const double _estTextLineHeight = 28;

double _estTextHeight(String content) {
  final lines = (content.length / _estTextCharsPerLine).ceil();
  return lines * _estTextLineHeight + 16;
}

/// 单个 part 的估算高度（锚点概览用）
double _estPartHeight(api.PartInfo part) {
  return switch (part.partType) {
    PartTypes.text => _estTextHeight(part.content),
    PartTypes.reasoning => _estReasoningHeight,
    PartTypes.toolCall || PartTypes.toolCallFrag => _estToolCardHeight,
    PartTypes.image => _estImageHeight,
    PartTypes.webSearch => _estSearchHeight,
    PartTypes.subAgentText => _estTextHeight(part.content),
    _ => 48,
  };
}

/// 用户消息预览文本（锚点面板浮层显示）
String _userMsgPreview(List<api.PartInfo> parts) {
  // 用户消息 content 存 JSON 包裹格式 `{"content":"..."}`（后端存储
  // 格式，消息正文显示时也经 ChatTextPart.extractDisplayText 解包），
  // 预览必须同样解包，否则浮层会显示 JSON 原文
  final text = parts
      .where((p) => p.partType == PartTypes.text)
      .map((p) => ChatTextPart.extractDisplayText(p.content).trim())
      .where((s) => s.isNotEmpty)
      .join(' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (text.isNotEmpty) return text;
  if (parts.any((p) => p.partType == PartTypes.image)) return '[图片]';
  return '(空消息)';
}

/// 跳转目标：离屏测量区要构建并测量的用户消息
class _PendingJump {
  const _PendingJump({
    required this.msgId,
    required this.targetItemIndex,
    required this.estOffset,
  });

  final String msgId;

  /// 目标消息在拍平列表中的 item 索引（用户消息整条一个 item）
  final int targetItemIndex;

  /// 估算的内容偏移：测量区先跳到此处，让目标 item 被构建
  final double estOffset;
}

/// 用户消息 item 的精确偏移上报：布局完成后求「消息顶部对齐视口顶部
/// 时的滚动偏移」（= 内容坐标系下的精确偏移），写入锚点索引缓存。
/// 包住所有 flat item（用户消息整条 + assistant 每个 part）：
/// 浏览过的区域锚点全部精确，而不是只有用户消息精确。
/// 同一消息多个 part 会上报多次，取最小偏移（= 消息顶部）。
class _ReportUserMsgOffset extends StatefulWidget {
  const _ReportUserMsgOffset({
    required this.msgId,
    required this.onMeasured,
    required this.child,
  });

  final String msgId;
  final void Function(String msgId, double offset) onMeasured;
  final Widget child;

  @override
  State<_ReportUserMsgOffset> createState() => _ReportUserMsgOffsetState();
}

class _ReportUserMsgOffsetState extends State<_ReportUserMsgOffset> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(covariant _ReportUserMsgOffset oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父级 rebuild（流式输出/主题变化）后偏移可能已变，重新上报
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  void _report() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final viewport = RenderAbstractViewport.of(box);
    // alignment 0.0：滚动到返回的偏移时本消息顶部与视口顶部对齐
    widget.onMeasured(widget.msgId, viewport.getOffsetToReveal(box, 0.0).offset);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 拍平列表 item：用户消息整条 / assistant 单个 part。
/// 全部消息按此拍平后，消息列表只在视口内构建 item（列表级虚拟化）。
sealed class _FlatItem {
  const _FlatItem();
}

/// 整条消息一个 item（用户消息：编辑卡片需要全部 parts 一起渲染）
final class _FlatMessageItem extends _FlatItem {
  const _FlatMessageItem(this.msgIndex);

  final int msgIndex;
}

/// assistant 消息的单个 part
final class _FlatPartItem extends _FlatItem {
  const _FlatPartItem(this.msgIndex, this.partIndex);

  final int msgIndex;
  final int partIndex;
}

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

/// 与 [ChatMessageItem] 的可见性规则一致：不可见的 part 在拍平时直接
/// 跳过，避免渲染成 SizedBox.shrink 后仍占位产生幻影间距。
bool _isPartVisible(api.PartInfo part) {
  if (part.partType == PartTypes.toolResult) return false;
  // 工具返回的图片消息：仅模型上下文可见，前端不渲染
  if (part.partType == PartTypes.toolImage) return false;
  if (part.partType == PartTypes.text) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.reasoning) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.webSearch) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.subAgentText) {
    return part.content.isNotEmpty;
  }
  if (part.partType == PartTypes.image) {
    return part.content.isNotEmpty;
  }
  // tool_call / tool_call_frag 是同一个调用生命周期内的两种状态，都展示
  return part.partType == PartTypes.toolCall ||
      part.partType == PartTypes.toolCallFrag;
}

/// 聊天内容区 — 消息列表 + 队列面板 + 输入框
///
/// 流式输出中按 Enter 发送的消息自动进入队列，
/// 当前回复结束后自动发出。
class ChatContent extends HookWidget {
  const ChatContent({super.key});

  @override
  Widget build(BuildContext context) {
    // 点击空白取消焦点：用 Listener 而非 GestureDetector ——
    // assistant 文本的 SelectionArea（文本选择）会赢下 tap 竞技场，
    // GestureDetector.onTap 永远不会触发；Listener 不参与竞技场，
    // 任何点击都会走到这里。仅在满足以下条件时取消：
    //   1. pointer up 位移在 touch slop 内（非滚动/拖动）；
    //   2. 点击位置未命中可编辑组件（输入框/富文本编辑器）；
    //   3. 点击未落在 Fleather 编辑器内（chatFleatherPointerUp 内层标记）。
    final downPos = useRef<Offset?>(null);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        downPos.value = event.position;
        // 每次点击开始重置用户消息标记（点击卡片外空白仍正常取消焦点）
        userMessagePointerUp = false;
        // 每次点击开始重置 Fleather 编辑器标记（点击编辑器外空白仍正常取消焦点）
        chatFleatherPointerUp = false;
      },
      onPointerUp: (event) {
        final down = downPos.value;
        downPos.value = null;
        if (down == null) return;
        // 滚动/拖动（位移超过 touch slop）不取消，避免打断滚动
        if ((event.position - down).distance > kTouchSlop) return;
        // 点击了可编辑组件（输入框/编辑器）不取消，避免打断编辑。
        // 注意：Fleather 编辑器（用户消息 ChatFleather）的渲染对象是
        // `RenderEditableContainerBox` 而非 Flutter 的 `RenderEditable`，
        // 漏判会导致点击编辑框时被当作空白区域而 unfocus（点一下反而失焦）。
        // 该类型未从 fleather 公开导出，import 内部路径（版本已锁定）。
        // 但容器在点击文本行下方空白时同样不在 hit test 路径中（未重写
        // hitTestSelf），此处仅能兜底文本行命中；编辑器内空白区域的点击
        // 由 ChatFleather 内层 Listener 置位的 chatFleatherPointerUp 标记拦截。
        final result = HitTestResult();
        WidgetsBinding.instance.hitTestInView(
          result,
          event.position,
          event.viewId,
        );
        final hitEditable = result.path.any(
          (entry) =>
              entry.target is RenderEditable ||
              entry.target is RenderEditableContainerBox,
        );
        // 用户消息卡片整体（含空白/按钮）点击也不取消：
        // 卡片内层 Listener 已置位标记（pointer up 叶子→根分发，内层先执行）
        if (!hitEditable && !userMessagePointerUp && !chatFleatherPointerUp) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
        userMessagePointerUp = false; // 消费标记
        chatFleatherPointerUp = false; // 消费标记
      },
      child: SignalBuilder(
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
      ),
    );
  }
}

/// 消息列表 — ListView 非 reverse，流式内容向下生长
class _MessageList extends StatelessWidget {
  final String sessionId;

  const _MessageList({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    // 订阅主题变化（字体/字号/颜色）：主题改动时消息列表必须重建，
    // 否则已渲染的 markdown 保持旧样式（SignalBuilder 只监听会话数据）。
    CustomTheme.of(context);
    return SignalBuilder(
      builder: (_) {
        final mgr = SessionStore.instance;
        final sessionState = mgr.sessions.value[sessionId];
        if (sessionState == null) return const SizedBox.shrink();

        final messageOrder = sessionState.messageOrder;
        final partsByMsg = sessionState.partsByMsg;
        final messageRoles = sessionState.messageRoles;
        final messageModels = sessionState.messageModels;
        final toolStreamedOutputs = sessionState.toolOutputBuffers;

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
            // 用户是否贴底（流式跟随的条件）：滚动时实时更新，
            // 初始挂载后首次评估时惰性初始化（以实际位置为准）。
            final isPinnedRef = useRef<bool?>(null);

            // ── 用户消息锚点索引（右侧导航面板）──
            // msgId → 精确内容偏移：由 _ReportUserMsgOffset 布局后上报
            final msgOffsetCache = useRef(<String, double>{});
            // 当前视口激活的用户消息（面板高亮，滚动时更新）
            final activeMsgId = useMemoized(() => ValueNotifier<String?>(null));
            // 离屏测量区：跳转未测量消息期间临时挂载
            final measureController = useMemoized(() => ScrollController());
            final measureTargetKey = useMemoized(() => GlobalKey());
            final pendingJump = useState<_PendingJump?>(null);
            // 本次 build 的锚点数据（滚动 listener 激活判定用）
            final anchorsRef = useRef(<UserAnchorData>[]);
            useEffect(() => () => activeMsgId.dispose(), []);
            useEffect(() => () => measureController.dispose(), []);

            // 监听滚动位置：更新贴底状态；离开底部时清空 physics 保留位。
            // 只在用户主动滚动（拖动/惯性/滚轮）时更新：程序化 jumpTo
            // 与布局期 physics 校正也会触发 onScroll，而懒加载下
            // maxScrollExtent 是估算值，按中间位置更新会把贴底状态/保留位
            // 抖掉 —— 跟随中断后再被 postFrame 跳转拽回，表现为流式输出
            // 时列表来回跳（闪动）。

            /// 更新激活锚点：视口顶部所在的用户消息
            void updateActiveFromPos() {
              if (!scrollController.hasClients) return;
              final pos = scrollController.position;
              if (!pos.hasContentDimensions) return;
              // 用视口顶部而非中心：跳转把目标消息对齐到视口顶部，
              // 顶部判定与跳转精确对应；消息很短时视口中心会落到
              // 下一条消息上，表现为「点击第一条却聚焦第二条」
              final top = pos.pixels;
              String? active;
              for (final a in anchorsRef.value) {
                if (top >= a.offset) {
                  active = a.msgId;
                } else {
                  break;
                }
              }
              if (active != activeMsgId.value) {
                activeMsgId.value = active;
              }
            }

            useEffect(() {
              void onScroll() {
                if (!scrollController.hasClients) return;
                final pos = scrollController.position;
                // 激活锚点：视口中心所在的用户消息（不限用户滚动，
                // 程序化 jumpTo 后同样要更新）
                updateActiveFromPos();
                if (!pos.isScrollingNotifier.value) return;
                // 视口底下没剩内容（== 0）即贴底
                isPinnedRef.value = pos.extentAfter <= 0;
                if (pos.extentAfter > 0) {
                  savedMaxExtent.value = null;
                }
              }

              scrollController.addListener(onScroll);
              return () => scrollController.removeListener(onScroll);
            }, [scrollController]);

            // 首次挂载后评估一次激活锚点（无滚动事件时也有初始高亮）
            useEffect(() {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                updateActiveFromPos();
              });
              return null;
            }, []);

            // 发送消息后无条件滚到底部（即使在翻历史）：
            // 消息本地入列 → 下一帧跳底并恢复贴底跟随。
            // 用 useRef 记录上次计数：首次挂载/切换会话（组件重建）
            // 时 prev == count，不会误跳底。
            final sentCount = useExistingSignal(
              SessionStore.instance.userMessageSent,
            );
            final lastSentCount = useRef(sentCount.value);
            useEffect(() {
              final count = sentCount.value;
              final prev = lastSentCount.value;
              lastSentCount.value = count;
              if (count == prev) return null;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scrollController.hasClients) return;
                isPinnedRef.value = true;
                scrollController.jumpTo(
                  scrollController.position.maxScrollExtent,
                );
              });
              return null;
            }, [sentCount.value]);

            // 消息重排（重试会删除/重写被重试消息之后的内容）后锚点
            // 偏移缓存全部失效：旧偏移已过期，清空回退到估算，
            // 重新浏览后逐步恢复精确。
            final revision = useExistingSignal(
              SessionStore.instance.messagesRevision,
            );
            final lastRevision = useRef(revision.value);
            useEffect(() {
              final rev = revision.value;
              final prev = lastRevision.value;
              lastRevision.value = rev;
              if (rev == prev) return null;
              msgOffsetCache.value.clear();
              // 等 rebuild 完成（anchorsRef 已用新数据重建）再评激活
              WidgetsBinding.instance.addPostFrameCallback((_) {
                updateActiveFromPos();
              });
              return null;
            }, [revision.value]);

            /// 直接跳到底部。ListView 懒加载时 maxScrollExtent 是估算值，
            /// 单次 jumpTo 可能到不了真实底部（差一小截），靠后续流式
            /// 触发的再次跳转逐步收敛。
            void jumpToBottom() {
              if (!scrollController.hasClients) return;
              final p = scrollController.position;
              scrollController.jumpTo(p.maxScrollExtent);
            }

            /// 帧后收敛跳底：贴底且被懒加载估算偏差推出视口时跳回真实底部。
            /// 用户已滚走（isPinnedRef == false）时不打扰，避免流式输出时
            /// 向上滚动被持续拽回。统一新消息跳底（itemCount 变化）与
            /// 文本增长收敛两条路径。
            /// [pinnedAtSchedule]：安排收敛时已知用户贴底（onBeforeEmit
            /// 路径在 extentAfter <= 0 时才安排）；itemCount 路径传 null，
            /// 以帧后实际位置做首次评估（新会话从顶部开始 → 不贴底 → 不跳）。
            void convergeToBottomIfPinned({bool? pinnedAtSchedule}) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!scrollController.hasClients) return;
                isPinnedRef.value ??=
                    pinnedAtSchedule ??
                        scrollController.position.extentAfter <= 0;
                // 贴底才跟随：用户在中间翻历史时不拽回底部
                if (isPinnedRef.value != true) return;
                // 已被估算偏差推出视口才需要收敛；估算恰好精确时无事可做
                if (scrollController.position.extentAfter > 0) {
                  jumpToBottom();
                }
              });
            }

            // 全部消息拍平到 item 粒度（见下方「全量拍平」），视口外的
            // item 由 ListView 跳过构建。若把整轮打包进单个 item
            // （旧 _LatestTurnLayout 方案），一轮内数百/上千个 parts（工具
            // 调用卡片等）每帧全量构建+布局，虚拟滚动完全失效 ——
            // 实测 1000 张卡片时每帧 ~140ms。拍平后视口外的卡片不构建。
            final focusedIndex = focusedMsgId.value == null
                ? -1
                : messageOrder.indexOf(focusedMsgId.value!);

            // ── 全量拍平 ──
            // 用户消息整条一个 item（编辑卡片需要全部 parts 一起渲染）；
            // assistant 消息按 part 拍平（列表只在视口内构建 item）。
            final hasLatestTurn = latestUserIndex >= 0;
            final flatItems = <_FlatItem>[];
            // 用户消息锚点 + 估算高度游标：未测量区域按估算累计，
            // 已测量（缓存命中）的消息校准游标，让后续估算更准。
            final userAnchors = <UserAnchorData>[];
            var estCursor = 0.0;
            for (var m = 0; m < messageOrder.length; m++) {
              final msgId = messageOrder[m];
              final parts = partsByMsg[msgId] ?? [];
              // 纯工具类消息不占位
              if (parts.isNotEmpty && PartTypes.isToolOnly(parts)) continue;
              // 用户消息整条渲染（编辑/重试卡片）
              if (messageRoles[msgId] == 'user') {
                flatItems.add(_FlatMessageItem(m));
                final cached = msgOffsetCache.value[msgId];
                final offset = cached ?? estCursor;
                userAnchors.add(
                  UserAnchorData(
                    msgId: msgId,
                    preview: _userMsgPreview(parts),
                    offset: offset,
                  ),
                );
                estCursor = offset + _estUserMsgHeight;
                continue;
              }
              for (var p = 0; p < parts.length; p++) {
                final part = parts[p];
                // 不可见 part（toolResult/toolImage/空内容）不占位，
                // 避免渲染成 SizedBox.shrink 后仍留下 8px 幻影间距
                if (!_isPartVisible(part)) continue;
                flatItems.add(_FlatPartItem(m, p));
                estCursor += _estPartHeight(part);
              }
            }
            anchorsRef.value = userAnchors;
            // 最新轮只有用户消息（无任何 assistant 内容）时，末尾显示独立 loading
            final standaloneIndicator =
                hasLatestTurn &&
                isStreaming &&
                latestUserIndex == messageOrder.length - 1;
            final itemCount = flatItems.length + (standaloneIndicator ? 1 : 0);

            // ── 新消息/流式：itemCount 变化时滚到底部 ──
            // 切换会话后首次构建不跳底（停留在对话顶部），只有 itemCount
            // 真正变化（新消息/流式新 part）才跳。
            final lastItemCount = useRef(itemCount);
            useEffect(() {
              final prevItemCount = lastItemCount.value;
              lastItemCount.value = itemCount;
              // 初始挂载（切换会话后首次构建）不跳底
              if (prevItemCount == itemCount) return null;
              convergeToBottomIfPinned();
              return null;
            }, [itemCount]);

            /// 锚点点击跳转：缓存命中一帧精准；未命中走离屏测量区，
            /// 测量完成后一帧精准落地（用户视野中无中间帧）。
            void jumpToMessage(String msgId) {
              if (!scrollController.hasClients) return;
              // 跳到历史消息 = 离开底部，流式输出不得拽回
              isPinnedRef.value = false;
              final cached = msgOffsetCache.value[msgId];
              if (cached != null) {
                scrollController.jumpTo(
                  cached.clamp(0.0, scrollController.position.maxScrollExtent),
                );
                return;
              }
              final targetMsgIndex = messageOrder.indexOf(msgId);
              final targetItemIndex = flatItems.indexWhere(
                (it) =>
                    it is _FlatMessageItem && it.msgIndex == targetMsgIndex,
              );
              if (targetItemIndex < 0) return;
              final estOffset = userAnchors
                  .firstWhere(
                    (a) => a.msgId == msgId,
                    orElse: () =>
                        UserAnchorData(msgId: msgId, preview: '', offset: 0),
                  )
                  .offset;
              pendingJump.value = _PendingJump(
                msgId: msgId,
                targetItemIndex: targetItemIndex,
                estOffset: estOffset,
              );
            }

            // ── 离屏测量：跳转到未测量过的用户消息 ──
            // 测量区（Offstage）与主列表共享同一套 item 构建逻辑，
            // 布局照常执行但不绘制。跳转期间挂载，完成后移除。
            useEffect(() {
              final pending = pendingJump.value;
              if (pending == null) return null;
              // 帧 1：测量区已挂载，跳到估算位置让目标 item 被构建
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!measureController.hasClients) return;
                final maxExt = measureController.position.maxScrollExtent;
                measureController.jumpTo(
                  pending.estOffset.clamp(0.0, maxExt),
                );
                // 帧 2：目标已布局，取精确偏移并跳转主列表
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final box = measureTargetKey.currentContext
                      ?.findRenderObject() as RenderBox?;
                  double? exact;
                  if (box != null && box.attached) {
                    final viewport = RenderAbstractViewport.of(box);
                    exact = viewport.getOffsetToReveal(box, 0.0).offset;
                  }
                  if (scrollController.hasClients) {
                    final target = exact ?? pending.estOffset;
                    scrollController.jumpTo(
                      target.clamp(
                        0.0,
                        scrollController.position.maxScrollExtent,
                      ),
                    );
                    if (exact != null) {
                      msgOffsetCache.value[pending.msgId] = exact;
                    }
                  }
                  // 移除测量区
                  pendingJump.value = null;
                });
              });
              return null;
            }, [pendingJump.value]);

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
                  // 文本增长（无新 part，itemCount 不变不触发跳底）时，
                  // 若懒加载估算偏差把最新内容/loading 推出视口，
                  // 帧后收敛恢复贴底；安排后用户滚走则不打扰。
                  convergeToBottomIfPinned(pinnedAtSchedule: true);
                }
              };
              return () {
                SessionStore.instance.onBeforeEmit = null;
              };
            }, [sessionId, scrollController]);

            /// 包裹拍平 item：part 间距、流式 loading、底部间距
            /// 所有 part（含跨消息）间距统一：两侧 messagePadding xs(4)
            /// 合计 8px，不做消息/part 分层，保证视觉完全一致。
            Widget wrapFlatItem(
              Widget item, {
              required bool isLastItem,
              // 用户消息不挂 loading（由独立流式指示器负责），避免
              // loading 出现/消失导致用户消息子树反复重建
              bool showStreamingLoading = true,
            }) {
              if (isLastItem) {
                // 先包 _StreamingMessage（loading 距内容 20px，与历史结构一致），
                // 再包底部间距 —— 顺序反了会把 loading 推到内容下方 60px 处
                if (isStreaming && showStreamingLoading) {
                  item = _StreamingMessage(child: item);
                }
                item = Padding(
                  padding: const EdgeInsets.only(bottom: _listBottomSpacing),
                  child: item,
                );
              }
              return item;
            }

            /// 整条消息一个 item（用户消息：编辑/重试卡片需要全部 parts）
            Widget buildMessageItem(int msgIndex, {required bool isLastItem}) {
              final msgId = messageOrder[msgIndex];
              final parts = partsByMsg[msgId] ?? [];
              final messageItem = ChatMessageItem(
                key: ValueKey(msgId),
                sessionId: sessionId,
                msgId: msgId,
                role: messageRoles[msgId] ?? '',
                parts: parts,
                toolStreamedOutputs: toolStreamedOutputs,
                // 历史消息（含用户消息）一律静态渲染：streaming
                // 只对正在流式的 assistant 消息（buildPartItem）生效。
                // 若按会话级 isStreaming 传值，每次发送新消息都会让全部
                // 历史消息切到流式模式 —— Streamdown 重建管线后异步重放
                // 全文，产生 1-2 帧空白，表现为发送时界面闪烁。
                streaming: false,
                modelName: isFirstInTurn[msgIndex] == true
                    ? messageModels[msgId]
                    : null,
                dimmed: focusedIndex >= 0 && msgIndex > focusedIndex,
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
              return wrapFlatItem(
                messageItem,
                isLastItem: isLastItem,
                // 用户消息不挂流式 loading（原设计：loading 指示器
                // 不挂在用户消息上，由独立指示器/最后一条内容项负责）
                showStreamingLoading: false,
              );
            }

            /// assistant 消息拍平后的单个 part 项（视口外的 part 由
            /// ListView 跳过构建 —— part 级虚拟化）
            Widget buildPartItem(
              int msgIndex,
              int partIndex, {
              required bool isLastItem,
            }) {
              final msgId = messageOrder[msgIndex];
              final parts = partsByMsg[msgId] ?? [];
              if (partIndex >= parts.length) return const SizedBox.shrink();
              final part = parts[partIndex];
              Widget item = ChatMessageItem(
                key: ValueKey('${msgId}_${part.id}'),
                sessionId: sessionId,
                msgId: msgId,
                role: messageRoles[msgId] ?? '',
                parts: [part],
                toolStreamedOutputs: toolStreamedOutputs,
                // 仅最新轮的 assistant 消息流式渲染
                streaming:
                    hasLatestTurn && msgIndex > latestUserIndex && isStreaming,
                modelName: partIndex == 0 && isFirstInTurn[msgIndex] == true
                    ? messageModels[msgId]
                    : null,
                dimmed: focusedIndex >= 0 && msgIndex > focusedIndex,
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
              return wrapFlatItem(item, isLastItem: isLastItem);
            }

            /// 拍平 item 构建（主列表与离屏测量区共用）
            Widget buildListItem(int index) {
              // 独立流式指示器（最新一轮只有用户消息，无 assistant 内容）
              if (index >= flatItems.length) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: _listBottomSpacing),
                  child: _StandaloneStreamingIndicator(),
                );
              }
              final item = flatItems[index];
              final isLastItem = index == itemCount - 1;
              // 偏移上报：所有 item（用户消息整条 + assistant 每个 part）
              // 布局后上报精确内容偏移 → 浏览过的区域锚点全部精确。
              // 同一消息多个 part 上报多次，取最小偏移（= 消息顶部）。
              Widget report(String msgId, Widget child) => _ReportUserMsgOffset(
                msgId: msgId,
                onMeasured: (msgId, offset) {
                  final prev = msgOffsetCache.value[msgId];
                  if (prev == null || offset < prev) {
                    msgOffsetCache.value[msgId] = offset;
                  }
                },
                child: child,
              );
              return switch (item) {
                _FlatMessageItem(:final msgIndex) => report(
                  messageOrder[msgIndex],
                  buildMessageItem(msgIndex, isLastItem: isLastItem),
                ),
                _FlatPartItem(:final msgIndex, :final partIndex) => report(
                  messageOrder[msgIndex],
                  buildPartItem(msgIndex, partIndex, isLastItem: isLastItem),
                ),
              };
            }

            /// 测量区 item 构建：目标消息包 GlobalKey 供帧后精确定位
            Widget buildListItemForMeasure(int index) {
              final item = buildListItem(index);
              final pending = pendingJump.value;
              if (pending != null && index == pending.targetItemIndex) {
                return KeyedSubtree(key: measureTargetKey, child: item);
              }
              return item;
            }

            final listView = ListView.builder(
              controller: scrollController,
              physics: savedMaxExtent.value != null
                  ? _KeepAtBottomPhysics(savedMaxExtent: savedMaxExtent.value)
                  : null,
              padding: EdgeInsets.only(
                top: 0,
                bottom: hasLatestTurn ? 0 : _listBottomSpacing,
              ),
              itemCount: itemCount,
              itemBuilder: (context, index) => buildListItem(index),
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                // 锚点比例：offset / maxScrollExtent
                final maxExtent = scrollController.hasClients
                    ? scrollController.position.maxScrollExtent
                    : 0.0;
                final panelAnchors = [
                  for (final a in userAnchors)
                    UserAnchorData(
                      msgId: a.msgId,
                      preview: a.preview,
                      offset: a.offset,
                      ratio: maxExtent > 0
                          ? (a.offset / maxExtent).clamp(0.0, 1.0)
                          : 0.0,
                    ),
                ];
                return Stack(
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(width: readingWidth, child: listView),
                    ),
                    // 离屏测量区：跳转未测量消息期间临时挂载，布局照常
                    // 但不绘制，用户视野中无中间帧
                    if (pendingJump.value != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        width: readingWidth,
                        height: 600,
                        child: Offstage(
                          offstage: true,
                          child: ListView.builder(
                            controller: measureController,
                            // 大 cacheExtent：估算偏差较大时也能构建出目标
                            scrollCacheExtent: ScrollCacheExtent.pixels(2000),
                            itemCount: itemCount,
                            itemBuilder: (context, index) =>
                                buildListItemForMeasure(index),
                          ),
                        ),
                      ),
                    // 右侧悬浮锚点面板：贴在聊天区右缘（窗口右侧），
                    // 竖条在最右缘，浮层区域向左覆盖聊天区右侧。
                    // 不随内容宽度/窗口宽度漂移。
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: MessageAnchorsPanel(
                        anchors: panelAnchors,
                        activeMsgId: activeMsgId,
                        onJumpTo: jumpToMessage,
                      ),
                    ),
                  ],
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
