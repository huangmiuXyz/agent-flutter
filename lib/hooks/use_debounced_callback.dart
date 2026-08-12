/// 防抖回调 hook。
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_hooks/flutter_hooks.dart';

/// 防抖回调：`delay` 内重复调用只执行最后一次（重置计时器）。
///
/// 组件卸载时自动取消挂起的调用，避免卸载后触发保存等副作用。
/// 用于实时保存场景：文本输入每敲一键都会调用，但只有停顿
/// `delay` 后才真正执行（如写配置文件）。
VoidCallback useDebouncedCallback(
  VoidCallback callback, [
  Duration delay = const Duration(milliseconds: 400),
]) {
  final timer = useRef<Timer?>(null);
  useEffect(
    () =>
        () => timer.value?.cancel(),
    const [],
  );
  return useCallback(() {
    timer.value?.cancel();
    timer.value = Timer(delay, callback);
  }, [callback, delay]);
}
