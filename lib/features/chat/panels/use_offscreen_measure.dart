/// 离屏测量状态机 hook：不可见 ListView 迭代逼近目标 item，
/// 构建后取精确偏移（内容坐标系），供调用方一次跳转精准落地。
///
/// 跳转未测量消息与会话滚底共用同一机制（复用）：
/// 两者都面临「懒加载下 maxScrollExtent 是估算值，直接 jumpTo
/// 到不了精确位置」的问题，测量区把目标 item 构建出来后再取
/// 真实偏移，主列表只需一次 jumpTo。
library;

import 'package:flutter/rendering.dart'
    show RenderAbstractViewport, ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// 一次测量请求
class MeasureRequest {
  const MeasureRequest({
    required this.targetItemIndex,
    required this.estOffset,
    required this.alignment,
    required this.onDone,
  });

  /// 目标 item 在拍平列表中的索引
  final int targetItemIndex;

  /// 估算内容偏移：测量区先跳到此处让目标被构建
  final double estOffset;

  /// 取偏移的锚定方式：0.0 = 目标顶部对齐视口顶部（跳消息），
  /// 1.0 = 目标底部对齐视口底部（滚底）
  final double alignment;

  /// 完成回调：[exact] 为真实偏移（测量成功）或 null（估算偏差过大
  /// 迭代超限，调用方退化为估算跳转）
  final void Function(double? exact) onDone;
}

/// 测量区挂载期间把目标 item 包上 GlobalKey 供帧后精确定位
class OffscreenMeasureArea extends StatelessWidget {
  const OffscreenMeasureArea({
    super.key,
    required this.controller,
    required this.targetKey,
    required this.request,
    required this.itemCount,
    required this.itemBuilder,
    required this.width,
    required this.height,
  });

  final ScrollController controller;
  final GlobalKey targetKey;
  final MeasureRequest request;
  final int itemCount;
  final Widget Function(int index) itemBuilder;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      width: width,
      height: height,
      child: Offstage(
        offstage: true,
        child: ListView.builder(
          controller: controller,
          // 大 cacheExtent：估算偏差较大时也能构建出目标
          scrollCacheExtent: ScrollCacheExtent.pixels(2000),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            final item = itemBuilder(index);
            if (index == request.targetItemIndex) {
              return KeyedSubtree(key: targetKey, child: item);
            }
            return item;
          },
        ),
      ),
    );
  }
}

/// 测量状态机 hook。用法：
/// ```dart
/// final measure = useOffscreenMeasure();
/// ...
/// measure.start(MeasureRequest(...));
/// ...
/// if (measure.request != null) {
///   OffscreenMeasureArea(controller: measure.controller, ...);
/// }
/// ```
class OffscreenMeasure {
  const OffscreenMeasure({
    required this.controller,
    required this.targetKey,
    required this.request,
    required this.start,
  });

  final ScrollController controller;
  final GlobalKey targetKey;

  /// 当前测量请求（null = 空闲；非 null 时调用方挂载测量区）
  final MeasureRequest? request;

  /// 发起一次测量
  final void Function(MeasureRequest request) start;
}

OffscreenMeasure useOffscreenMeasure() {
  final controller = useMemoized(() => ScrollController());
  final targetKey = useMemoized(() => GlobalKey());
  final request = useState<MeasureRequest?>(null);
  final attempts = useRef(0);
  useEffect(() => () => controller.dispose(), []);

  void iterate() {
    final r = request.value;
    if (r == null) return;
    final ctx = targetKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box != null && box.attached) {
      // 目标已构建：取精确偏移（alignment 0 = 顶部对齐，1 = 底部对齐）
      final viewport = RenderAbstractViewport.of(box);
      final exact = viewport.getOffsetToReveal(box, r.alignment).offset;
      request.value = null;
      r.onDone(exact);
      return;
    }
    // 估算偏差太大未构建出目标：测量区继续向底部推进（离屏迭代，
    // 用户无感），最多 3 次后兜底按估算回调
    if (attempts.value >= 3 || !controller.hasClients) {
      request.value = null;
      r.onDone(null);
      return;
    }
    attempts.value++;
    controller.jumpTo(controller.position.maxScrollExtent);
    WidgetsBinding.instance.addPostFrameCallback((_) => iterate());
  }

  void start(MeasureRequest r) {
    attempts.value = 0;
    request.value = r;
  }

  // 测量区挂载后：先跳到估算位置让目标 item 被构建，再迭代取精确值
  useEffect(() {
    final r = request.value;
    if (r == null) return null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.hasClients) {
        request.value = null;
        r.onDone(null);
        return;
      }
      controller.jumpTo(
        r.estOffset.clamp(0.0, controller.position.maxScrollExtent),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => iterate());
    });
    return null;
  }, [request.value]);

  return OffscreenMeasure(
    controller: controller,
    targetKey: targetKey,
    request: request.value,
    start: start,
  );
}
