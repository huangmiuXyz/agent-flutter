/// 响应式断点工具。
library;

import 'package:flutter/widgets.dart';

/// 紧凑宽度断点：可用宽度小于该值视为窄屏（手机 / 窄窗口）。
const double kCompactWidthBreakpoint = 600;

/// 当前可用宽度是否为紧凑宽度（< 600dp）。
///
/// 手机竖屏（通常 360–430dp）恒为 true；
/// 桌面正常窗口为 false，仅窗口收窄到断点以下时为 true。
bool isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kCompactWidthBreakpoint;
