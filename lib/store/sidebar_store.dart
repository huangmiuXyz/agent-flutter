import 'package:signals/signals.dart';

/// 左右侧边栏面板控制 — 供命令面板/快捷键切换面板展开/折叠。
///
/// 展开状态由面板组件与 ResizeBoxController 同步（用户拖拽也会更新），
/// 命令只需调用 [toggleLeft]/[toggleRight]，由面板侧监听计数器执行。
class SidebarStore {
  static final instance = SidebarStore._();
  SidebarStore._();

  /// 左侧边栏当前是否展开（与面板 controller 状态同步）
  final leftExpanded = signal(false);

  /// 右侧边栏当前是否展开（与面板 controller 状态同步）
  final rightExpanded = signal(false);

  /// 切换请求计数器：每次递增触发对应面板翻转一次。
  /// 用计数器而非 bool，保证连续多次切换都生效。
  final leftToggleCount = signal(0);
  final rightToggleCount = signal(0);

  void toggleLeft() => leftToggleCount.value++;

  void toggleRight() => rightToggleCount.value++;
}
