import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:agent/features/chat/widgets/chat_message_item.dart';
import 'package:agent/features/chat/widgets/message_anchors_panel.dart';
import 'package:agent/features/chat/widgets/system_prompt_banner.dart';
import 'package:agent/store/config_store.dart';
import 'package:agent/store/session_store.dart';
import 'package:agent/theme/custom_theme.dart';
import 'package:agent/utils/layout_utils.dart' show readingWidthFor;
import 'package:agent/widgets/loading/app_loading.dart';

import 'message_list_utils.dart';
import 'use_offscreen_measure.dart';

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

/// item 精确偏移上报：布局完成后求「消息顶部对齐视口顶部时的滚动
/// 偏移」（= 内容坐标系下的精确偏移），写入锚点索引缓存。
/// 包住所有 flat item（用户消息整条 + assistant 每个 part）：
/// 浏览过的区域锚点全部精确。同一消息多个 part 会上报多次，
/// 由调用方取最小偏移（= 消息顶部）。
class _ReportMsgOffset extends StatefulWidget {
  const _ReportMsgOffset({
    required this.msgId,
    required this.onMeasured,
    required this.child,
  });

  final String msgId;
  final void Function(String msgId, double offset) onMeasured;
  final Widget child;

  @override
  State<_ReportMsgOffset> createState() => _ReportMsgOffsetState();
}

class _ReportMsgOffsetState extends State<_ReportMsgOffset> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(covariant _ReportMsgOffset oldWidget) {
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
    widget.onMeasured(
      widget.msgId,
      viewport.getOffsetToReveal(box, 0.0).offset,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
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

/// 自动重试系统提示行 — 显示在消息列表底部（重试等待期间）。
class _RetryStatusLine extends StatelessWidget {
  const _RetryStatusLine({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = CustomTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.sync_problem, size: 13, color: colors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              status,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 消息列表 — ListView 非 reverse，流式内容向下生长。
/// 集成了：流式跟随、锚点索引与导航、离屏测量跳转、会话滚底。
class MessageList extends StatelessWidget {
  final String sessionId;

  const MessageList({super.key, required this.sessionId});

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
        final retryStatus = sessionState.retryStatus;

        if (messageOrder.isEmpty) return const SizedBox.shrink();

        final isFirstInTurn = _computeFirstInTurn(messageOrder, messageRoles);

        final isStreaming = mgr.streamingSessionIds.value.contains(sessionId);
        final latestUserIndex = messageOrder.lastIndexWhere(
          (msgId) => messageRoles[msgId] == 'user',
        );

        return HookBuilder(
          key: ValueKey('msglist_$sessionId'),
          builder: (context) {
            // 滚底测量完成前为 null（列表不渲染）；完成后以目标偏移
            // 创建 controller，列表首次 attach 即定位到底部，零过程
            final scrollController = useState<ScrollController?>(null);
            final focusedMsgId = useState<String?>(null);
            final savedMaxExtent = useRef<double?>(null);
            // 用户是否贴底（流式跟随的条件）：滚动时实时更新，
            // 初始挂载后首次评估时惰性初始化（以实际位置为准）。
            final isPinnedRef = useRef<bool?>(null);

            // ── 用户消息锚点索引（右侧导航面板）──
            // msgId → 精确内容偏移：由 _ReportMsgOffset 布局后上报
            final msgOffsetCache = useRef(<String, double>{});
            // 当前视口激活的用户消息（面板高亮，滚动时更新）
            final activeMsgId = useMemoized(() => ValueNotifier<String?>(null));
            // 离屏测量：跳转未测量消息 / 会话滚底共用
            final measure = useOffscreenMeasure();
            useEffect(
              () =>
                  () => activeMsgId.dispose(),
              [],
            );

            // ── 会话切换后自动滚底：先测量、后渲染，零过程 ──
            // 滚底测量完成前列表不渲染（占位）；attach 后估算收敛期间
            // 列表不可见（Opacity 0），收敛完成精确跳底后才显示。
            final initialScrollOffset = useRef(0.0);
            final listVisible = useState(false);

            // 监听滚动位置：更新贴底状态；离开底部时清空 physics 保留位。
            // 只在用户主动滚动（拖动/惯性/滚轮）时更新：程序化 jumpTo
            // 与布局期 physics 校正也会触发 onScroll，而懒加载下
            // maxScrollExtent 是估算值，按中间位置更新会把贴底状态/保留位
            // 抖掉 —— 跟随中断后再被 postFrame 跳转拽回，表现为流式输出
            // 时列表来回跳（闪动）。

            /// 更新激活锚点：视口顶部所在的用户消息。
            /// 实时拍平取锚点（基于最新缓存），不依赖 build 时快照：
            /// 跳转/浏览后缓存更新但旧快照不刷新，过期估算会让激活
            /// 永远落在最后一条上。standalone 参数不影响 anchors，
            /// 传固定值即可。
            void updateActiveFromPos() {
              final sc = scrollController.value;
              if (sc == null || !sc.hasClients) return;
              final pos = sc.position;
              if (!pos.hasContentDimensions) return;
              final live = flattenMessageList(
                messageOrder: messageOrder,
                partsByMsg: partsByMsg,
                messageRoles: messageRoles,
                measuredOffsets: msgOffsetCache.value,
                hasLatestTurn: false,
                isStreaming: false,
                latestUserIndex: -1,
                hasRetryLine: false,
              );
              // 只用已测量的消息（真实 offset）判定：估算 offset 严重
              // 低估时「top >= offset」对目标之后所有消息都成立，激活
              // 永远取最后一条。未测量区域不参与判定（激活为空）。
              final top = pos.pixels;
              String? active;
              for (final a in live.anchors) {
                if (!msgOffsetCache.value.containsKey(a.msgId)) continue;
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
                final sc = scrollController.value;
                if (sc == null || !sc.hasClients) return;
                final pos = sc.position;
                // 激活锚点（不限用户滚动，程序化 jumpTo 后同样要更新）
                updateActiveFromPos();
                if (!pos.isScrollingNotifier.value) return;
                // 视口底下没剩内容（== 0）即贴底
                final newPinned = pos.extentAfter <= 0;
                isPinnedRef.value = newPinned;
                if (pos.extentAfter > 0) {
                  savedMaxExtent.value = null;
                }
              }

              scrollController.addListener(onScroll);
              return () => scrollController.removeListener(onScroll);
            }, [scrollController.value]);

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
                final sc = scrollController.value;
                if (sc == null || !sc.hasClients) return;
                isPinnedRef.value = true;
                sc.jumpTo(sc.position.maxScrollExtent);
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
              final sc = scrollController.value;
              if (sc == null || !sc.hasClients) return;
              sc.jumpTo(sc.position.maxScrollExtent);
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
                final sc = scrollController.value;
                if (sc == null || !sc.hasClients) return;
                isPinnedRef.value ??=
                    pinnedAtSchedule ?? sc.position.extentAfter <= 0;
                // 贴底才跟随：用户在中间翻历史时不拽回底部
                if (isPinnedRef.value != true) return;
                // 已被估算偏差推出视口才需要收敛；估算恰好精确时无事可做
                if (sc.position.extentAfter > 0) {
                  jumpToBottom();
                }
              });
            }

            // ── 全量拍平（纯函数，见 message_list_utils.dart）──
            // 视口外的 item 由 ListView 跳过构建（item 级虚拟化）：
            // 若把整轮打包进单个 item，一轮内数百/上千个 parts（工具
            // 调用卡片等）每帧全量构建+布局，虚拟滚动完全失效。
            final hasLatestTurn = latestUserIndex >= 0;
            // 自动重试提示行：非空时在列表末尾追加一条系统提示（不含独立指示器时
            // 占用 flatItems.length 之后的索引；含独立指示器时在其之后）。
            // flatten 依据该标记：重试时不生成独立流式 loading 占位，让
            // 重试行紧贴最后一条消息（否则独立 loading 会把重试行推到下方，
            // 看起来像隔着一条助手信息）。
            final hasRetryLine =
                retryStatus != null && retryStatus.isNotEmpty;
            final flatten = flattenMessageList(
              messageOrder: messageOrder,
              partsByMsg: partsByMsg,
              messageRoles: messageRoles,
              measuredOffsets: msgOffsetCache.value,
              hasLatestTurn: hasLatestTurn,
              isStreaming: isStreaming,
              latestUserIndex: latestUserIndex,
              hasRetryLine: hasRetryLine,
            );
            final flatItems = flatten.items;
            final userAnchors = flatten.anchors;
            final standaloneIndicator =
                flatten.itemCount > flatItems.length;
            final itemCount =
                flatten.itemCount + (hasRetryLine ? 1 : 0);
            // 列表首项为系统提示词折叠项（随内容滚动），消息 item 整体
            // 后移一位：主列表 / 离屏测量区共用同一 itemBuilder，两侧
            // itemCount 与目标索引同步 +1。
            final listItemCount = itemCount + 1;
            final focusedIndex = focusedMsgId.value == null
                ? -1
                : messageOrder.indexOf(focusedMsgId.value!);

            // ── 会话切换后自动滚底：一帧精准 ──
            // 懒加载下 maxScrollExtent 是估算值，直接 jumpTo 会差一截；
            // 离屏测量区迭代逼近底部（不可见，用户无感），构建出最后
            // 一条消息后取真实底部位置，列表首次渲染直接定位到底部。
            useEffect(() {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                measure.start(
                  MeasureRequest(
                    targetItemIndex: listItemCount - 1,
                    estOffset: flatten.estTotalHeight,
                    alignment: 1.0,
                    onDone: (exact) {
                      // 列表尚未渲染：以目标偏移创建 controller，
                      // 首次 attach 即定位到底部，用户看到的第一帧
                      // 就是底部，没有滚动过程
                      initialScrollOffset.value =
                          exact ?? flatten.estTotalHeight;
                      isPinnedRef.value = true;
                      scrollController.value = ScrollController(
                        initialScrollOffset: initialScrollOffset.value,
                      );
                      // attach 后先保持不可见：懒加载 maxScrollExtent
                      // 估算会随构建修正，可见状态下位置逐帧跟随修正
                      // 会被感知为弹跳/滚动动画。隐藏期间在幕后等估算
                      // 收敛（连续两帧不变），再一次跳转到精确底部并显示
                      // —— 用户只看到：占位 → 底部内容，零过程。
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        var lastMax = double.nan;
                        var stable = 0;
                        void check() {
                          final s = scrollController.value;
                          if (s == null || !s.hasClients) return;
                          final max = s.position.maxScrollExtent;
                          if (max == lastMax) {
                            stable++;
                          } else {
                            lastMax = max;
                            stable = 0;
                          }
                          if (stable >= 2 || stable > 10) {
                            // 估算已收敛：精确跳到底部后显示
                            s.jumpTo(
                              initialScrollOffset.value.clamp(
                                0.0,
                                s.position.maxScrollExtent,
                              ),
                            );
                            isPinnedRef.value = true;
                            listVisible.value = true;
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => updateActiveFromPos(),
                            );
                            return;
                          }
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => check(),
                          );
                        }

                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => check(),
                        );
                      });
                    },
                  ),
                );
              });
              return null;
            }, []);

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
            /// 跳转同时显式激活目标消息（不依赖位置反推：懒加载
            /// maxScrollExtent 估算会让跳转后 pixels 与缓存偏移
            /// 产生偏差，位置判定会激活错误消息）。
            void jumpToMessage(String msgId) {
              final sc = scrollController.value;
              if (sc == null || !sc.hasClients) return;
              // 跳到历史消息 = 离开底部，流式输出不得拽回
              isPinnedRef.value = false;
              // 显式激活目标（滚动后由 updateActiveFromPos 接管）
              activeMsgId.value = msgId;
              final cached = msgOffsetCache.value[msgId];
              if (cached != null) {
                sc.jumpTo(cached.clamp(0.0, sc.position.maxScrollExtent));
                return;
              }
              final targetMsgIndex = messageOrder.indexOf(msgId);
              final targetItemIndex = flatItems.indexWhere(
                (it) => it is FlatMessageItem && it.msgIndex == targetMsgIndex,
              );
              if (targetItemIndex < 0) return;
              final estOffset = userAnchors
                  .firstWhere(
                    (a) => a.msgId == msgId,
                    orElse: () =>
                        UserAnchorData(msgId: msgId, preview: '', offset: 0),
                  )
                  .offset;
              measure.start(
                MeasureRequest(
                  targetItemIndex: targetItemIndex,
                  estOffset: estOffset,
                  alignment: 0.0,
                  onDone: (exact) {
                    final sc = scrollController.value;
                    if (sc == null || !sc.hasClients) return;
                    // 先更新缓存再跳转：jumpTo 同步触发 onScroll 的激活
                    // 判定，需在判定前写入真实偏移
                    if (exact != null) {
                      msgOffsetCache.value[msgId] = exact;
                    }
                    final target = exact ?? estOffset;
                    sc.jumpTo(target.clamp(0.0, sc.position.maxScrollExtent));
                  },
                ),
              );
            }

            // 流式输出中，用户在底部则保存 maxScrollExtent 供 physics 使用
            useEffect(() {
              final mgr = SessionStore.instance;
              void onBeforeEmit() {
                // 回调可能被覆盖/清空，先确认调用与 sc 状态
                final sc = scrollController.value;
                if (sc == null || !sc.hasClients) return;
                final streaming = mgr.streamingSessionIds.value.contains(
                  sessionId,
                );
                if (!streaming) {
                  savedMaxExtent.value = null;
                  return;
                }
                if (sc.position.extentAfter <= 0) {
                  savedMaxExtent.value = sc.position.maxScrollExtent;
                  // 文本增长（无新 part，itemCount 不变不触发跳底）时，
                  // 若懒加载估算偏差把最新内容/loading 推出视口，
                  // 帧后收敛恢复贴底；安排后用户滚走则不打扰。
                  convergeToBottomIfPinned(pinnedAtSchedule: true);
                } else {
                }
              }

              mgr.addBeforeEmitListener(onBeforeEmit);
              return () {
                mgr.removeBeforeEmitListener(onBeforeEmit);
              };
            }, [sessionId, scrollController.value]);

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
                pendingPermissions: sessionState.pendingPermissions,
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
                pendingPermissions: sessionState.pendingPermissions,
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
              // 列表首项：系统提示词折叠项（随内容滚动，不固定在视口顶部）
              if (index == 0) return const SystemPromptBanner();
              final itemIndex = index - 1;
              // 自动重试系统提示行：追加在列表末尾
              if (hasRetryLine &&
                  itemIndex ==
                      flatItems.length + (standaloneIndicator ? 1 : 0)) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: _listBottomSpacing),
                  child: _RetryStatusLine(status: retryStatus),
                );
              }
              // 独立流式指示器（最新一轮只有用户消息，无 assistant 内容）
              if (itemIndex >= flatItems.length) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: _listBottomSpacing),
                  child: _StandaloneStreamingIndicator(),
                );
              }
              final item = flatItems[itemIndex];
              final isLastItem = itemIndex == itemCount - 1;
              // 偏移上报：所有 item（用户消息整条 + assistant 每个 part）
              // 布局后上报精确内容偏移 → 浏览过的区域锚点全部精确。
              // 同一消息多个 part 上报多次，取最小偏移（= 消息顶部）。
              Widget report(String msgId, Widget child) => _ReportMsgOffset(
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
                FlatMessageItem(:final msgIndex) => report(
                  messageOrder[msgIndex],
                  buildMessageItem(msgIndex, isLastItem: isLastItem),
                ),
                FlatPartItem(:final msgIndex, :final partIndex) => report(
                  messageOrder[msgIndex],
                  buildPartItem(msgIndex, partIndex, isLastItem: isLastItem),
                ),
              };
            }

            // ── 非拖拽用户滚动（滚轮/触控板/键盘/惯性）的贴底状态同步 ──
            // onScroll 用 isScrollingNotifier 区分用户滚动，但 Flutter 中
            // 滚轮/触控板滚动（pointerScroll）期间 activity 是 Idle，
            // isScrollingNotifier 为 false → onScroll 直接 return，
            // pinned/savedMaxExtent 都不更新 → 用户滚走后 savedMaxExtent
            // 残留，下个 chunk 内容增长时 _KeepAtBottomPhysics 误判为
            // 「贴底」拽回底部。这里补上：非拖拽滚动（dragDetails 为 null）
            // 且是外层列表自身（depth==0，排除内层滚动冒泡）时，
            // 按实际位置同步贴底状态。
            // dragDetails != null（按住拖动）仍由 onScroll 处理。
            bool onUserScrollNotification(ScrollNotification n) {
              if (n is! ScrollUpdateNotification) return false;
              if (n.dragDetails != null) return false;
              if (n.depth != 0) return false;
              final sc = scrollController.value;
              if (sc == null || !sc.hasClients) return false;
              if (n.metrics.extentAfter > 0) {
                isPinnedRef.value = false;
                savedMaxExtent.value = null;
              } else if (isPinnedRef.value == false) {
                // 滚回底部：恢复跟随（滚轮滚动时 onScroll 不更新状态，
                // 这里补上，回到底部后继续跟随流式）
                isPinnedRef.value = true;
              }
              return false;
            }

            // 列表：滚底测量完成前不渲染（占位）；attach 后估算收敛
            // 期间不可见（Opacity 0），收敛完成精确跳底后才显示
            final listView = scrollController.value != null
                ? NotificationListener<ScrollNotification>(
                    onNotification: onUserScrollNotification,
                    child: Opacity(
                      opacity: listVisible.value ? 1.0 : 0.0,
                      child: ListView.builder(
                        controller: scrollController.value,
                        physics: savedMaxExtent.value != null
                            ? _KeepAtBottomPhysics(
                                savedMaxExtent: savedMaxExtent.value,
                              )
                            : null,
                        padding: EdgeInsets.only(
                          top: 0,
                          bottom: hasLatestTurn ? 0 : _listBottomSpacing,
                        ),
                        itemCount: listItemCount,
                        itemBuilder: (context, index) => buildListItem(index),
                      ),
                    ),
                  )
                : null;

            return LayoutBuilder(
              builder: (context, constraints) {
                // 锚点比例：offset / maxScrollExtent
                final maxExtent = (scrollController.value?.hasClients ?? false)
                    ? scrollController.value!.position.maxScrollExtent
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
                      child: SizedBox(
                        width: readingWidthFor(context),
                        child: listView ?? const SizedBox.shrink(),
                      ),
                    ),
                    // 离屏测量区：跳转未测量消息 / 会话滚底期间临时挂载，
                    // 布局照常但不绘制，用户视野中无中间帧
                    if (measure.request != null)
                      OffscreenMeasureArea(
                        controller: measure.controller,
                        targetKey: measure.targetKey,
                        request: measure.request!,
                        itemCount: listItemCount,
                        itemBuilder: buildListItem,
                        width: readingWidthFor(context),
                        height: 600,
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
