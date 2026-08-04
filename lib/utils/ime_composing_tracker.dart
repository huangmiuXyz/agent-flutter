import 'dart:ui' show PlatformDispatcher, channelBuffers;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show FocusManager;

/// 跟踪输入法（IME）组合状态（如中文拼音的候选阶段）。
///
/// Flutter 框架不暴露「IME 是否正在组合」的公开 API，Fleather 等基于
/// delta 模型的编辑器在接收输入时也会丢弃组合区域信息。但引擎推送到
/// `flutter/textinput` 通道的消息（`updateEditingState` 与
/// `updateEditingStateWithDeltas`）始终携带 composingBase/composingExtent。
///
/// 本工具通过包装 `PlatformDispatcher.onPlatformMessage` 旁路监听这些消息，
/// 维护当前组合状态。用途：Enter 发送类快捷键在组合中应消费按键但不发送
/// （否则会触发发送，且 Windows 引擎会因框架未处理按键而额外插入换行），
/// 让 IME 先提交组合内容「落下」。
class ImeComposingTracker {
  ImeComposingTracker._();

  static final ImeComposingTracker instance = ImeComposingTracker._();

  static const String _textInputChannel = 'flutter/textinput';
  static const JSONMethodCodec _codec = JSONMethodCodec();

  bool _installed = false;
  bool _composing = false;

  /// 输入法组合是否激活。
  bool get isComposing => _composing;

  /// 安装通道监听。
  ///
  /// 必须在 [WidgetsFlutterBinding.ensureInitialized] 之后调用一次，
  /// 此时 `PlatformDispatcher.onPlatformMessage` 已由 binding 接管；
  /// 幂等，重复调用无副作用。
  void install() {
    // 焦点切换（输入框之间或离开输入框）时，上一输入框的组合状态失效。
    // 先移除再添加：测试环境每个测试会重建 FocusManager，
    // 幂等重注册确保监听始终生效。
    FocusManager.instance.removeListener(_handleFocusChange);
    FocusManager.instance.addListener(_handleFocusChange);
    if (_installed) return;
    _installed = true;
    final dispatcher = PlatformDispatcher.instance;
    // onPlatformMessage 已废弃且 3.44+ 的 binding 不再设置它（引擎消息默认
    // 直接进 channelBuffers）。这里仍使用它作为唯一的旁路监听点：
    // ChannelBuffers.setListener 是每 channel 单 listener 的替换式注册，
    // 无法旁路监听已被 TextInput 占用的 textinput 通道。
    // 注意：包装后必须原样转发消息（original 或 channelBuffers.push），
    // 否则引擎消息（键盘/文本输入/生命周期）会被全部吞掉。
    // ignore: deprecated_member_use
    final original = dispatcher.onPlatformMessage;
    // ignore: deprecated_member_use
    dispatcher.onPlatformMessage = (channel, data, callback) {
      if (channel == _textInputChannel && data != null) {
        try {
          _updateFromEngineMessage(_codec.decodeMethodCall(data));
        } catch (_) {
          // 消息解析失败不影响原样转发
        }
      }
      if (original != null) {
        original(channel, data, callback);
      } else {
        // 新架构：binding 不设置 onPlatformMessage，
        // 等价于其默认的 channelBuffers 分发路径
        channelBuffers.push(channel, data, callback ?? (_) {});
      }
    };
  }

  void _handleFocusChange() {
    _composing = false;
  }

  /// 强制重置组合状态（供测试与其他特殊场景使用；
  /// 正常运行时焦点切换由 [install] 中的监听自动重置）。
  void reset() => _composing = false;

  /// 根据引擎推送的 textinput 消息更新组合状态。
  ///
  /// 正常流程由 [install] 的通道监听调用；测试可直接调用以模拟引擎消息。
  @visibleForTesting
  void handleEngineMessage(MethodCall call) => _updateFromEngineMessage(call);

  void _updateFromEngineMessage(MethodCall call) {
    final method = call.method;
    if (method == 'TextInputClient.updateEditingState') {
      final args = call.arguments as List<dynamic>;
      if (args.length >= 2 && args[1] is Map) {
        _composing = _hasComposingRegion(args[1] as Map<dynamic, dynamic>);
      }
    } else if (method == 'TextInputClient.updateEditingStateWithDeltas') {
      final args = call.arguments as List<dynamic>;
      if (args.length >= 2 && args[1] is Map) {
        final deltas = (args[1] as Map<dynamic, dynamic>)['deltas'];
        if (deltas is List && deltas.isNotEmpty) {
          _composing =
              _hasComposingRegion(deltas.last as Map<dynamic, dynamic>);
        }
      }
    } else if (method == 'TextInput.clearClient') {
      // 输入连接关闭，组合必然结束
      _composing = false;
    }
  }

  /// 组合区域是否有效（引擎约定 composingBase/Extent 为 -1 表示无组合）。
  static bool _hasComposingRegion(Map<dynamic, dynamic> map) {
    final base = map['composingBase'] as int? ?? -1;
    final extent = map['composingExtent'] as int? ?? -1;
    return base != -1 && extent != -1 && base != extent;
  }
}
