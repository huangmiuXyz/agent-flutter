import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent/utils/ime_composing_tracker.dart';

void main() {
  final tracker = ImeComposingTracker.instance;

  setUp(tracker.reset);

  test('updateEditingState 携带有效 composing 时判定为组合中', () {
    tracker.handleEngineMessage(
      const MethodCall(
        'TextInputClient.updateEditingState',
        <dynamic>[
          1,
          <String, dynamic>{
            'selectionBase': 5,
            'selectionExtent': 5,
            'selectionAffinity': 'TextAffinity.downstream',
            'selectionIsDirectional': false,
            'composingBase': 0,
            'composingExtent': 5,
            'text': 'nihao',
          },
        ],
      ),
    );
    expect(tracker.isComposing, isTrue);
  });

  test('updateEditingState 的 composing 为 -1 时判定为非组合', () {
    tracker.handleEngineMessage(
      const MethodCall(
        'TextInputClient.updateEditingState',
        <dynamic>[
          1,
          <String, dynamic>{
            'selectionBase': 5,
            'selectionExtent': 5,
            'selectionAffinity': 'TextAffinity.downstream',
            'selectionIsDirectional': false,
            'composingBase': -1,
            'composingExtent': -1,
            'text': 'nihao',
          },
        ],
      ),
    );
    expect(tracker.isComposing, isFalse);
  });

  test('updateEditingStateWithDeltas 取最后一条 delta 的 composing 状态', () {
    // 组合中（末尾 delta 带 composing 区域）
    tracker.handleEngineMessage(
      const MethodCall(
        'TextInputClient.updateEditingStateWithDeltas',
        <dynamic>[
          1,
          <String, dynamic>{
            'deltas': <Map<String, dynamic>>[
              {
                'oldText': '',
                'deltaText': 'n',
                'deltaStart': 0,
                'deltaEnd': 0,
                'selectionBase': 1,
                'selectionExtent': 1,
                'selectionAffinity': 'TextAffinity.downstream',
                'selectionIsDirectional': false,
                'composingBase': 0,
                'composingExtent': 1,
              },
            ],
          },
        ],
      ),
    );
    expect(tracker.isComposing, isTrue);

    // 提交后（末尾 delta 的 composing 清空）
    tracker.handleEngineMessage(
      const MethodCall(
        'TextInputClient.updateEditingStateWithDeltas',
        <dynamic>[
          1,
          <String, dynamic>{
            'deltas': <Map<String, dynamic>>[
              {
                'oldText': 'nihao',
                'deltaText': 'nihao',
                'deltaStart': 0,
                'deltaEnd': 0,
                'selectionBase': 5,
                'selectionExtent': 5,
                'selectionAffinity': 'TextAffinity.downstream',
                'selectionIsDirectional': false,
                'composingBase': -1,
                'composingExtent': -1,
              },
            ],
          },
        ],
      ),
    );
    expect(tracker.isComposing, isFalse);
  });

  test('组合中按 Enter 提交后状态变为非组合（增量消息流）', () {
    tracker.handleEngineMessage(
      const MethodCall(
        'TextInputClient.updateEditingStateWithDeltas',
        <dynamic>[
          1,
          <String, dynamic>{
            'deltas': <Map<String, dynamic>>[
              {
                'oldText': '',
                'deltaText': 'nihao',
                'deltaStart': 0,
                'deltaEnd': 0,
                'selectionBase': 5,
                'selectionExtent': 5,
                'selectionAffinity': 'TextAffinity.downstream',
                'selectionIsDirectional': false,
                'composingBase': 0,
                'composingExtent': 5,
              },
            ],
          },
        ],
      ),
    );
    expect(tracker.isComposing, isTrue);

    tracker.reset();
    expect(tracker.isComposing, isFalse);
  });

  testWidgets('安装后引擎消息不被吞（消息链路完整）', (tester) async {
    ImeComposingTracker.instance.install();

    // 包装器必须已接管 onPlatformMessage
    // ignore: deprecated_member_use
    final handler = PlatformDispatcher.instance.onPlatformMessage;
    expect(handler, isNotNull);

    // 模拟引擎推送组合消息：应被解析（tracker 更新）且转发不抛异常
    final codec = const JSONMethodCodec();
    expect(
      () => handler!(
        'flutter/textinput',
        codec.encodeMethodCall(
          const MethodCall(
            'TextInputClient.updateEditingStateWithDeltas',
            <dynamic>[
              1,
              <String, dynamic>{
                'deltas': <Map<String, dynamic>>[
                  {
                    'oldText': '',
                    'deltaText': 'nihao',
                    'deltaStart': 0,
                    'deltaEnd': 0,
                    'selectionBase': 5,
                    'selectionExtent': 5,
                    'selectionAffinity': 'TextAffinity.downstream',
                    'selectionIsDirectional': false,
                    'composingBase': 0,
                    'composingExtent': 5,
                  },
                ],
              },
            ],
          ),
        ),
        (_) {},
      ),
      returnsNormally,
    );
    expect(ImeComposingTracker.instance.isComposing, isTrue);

    // 非 textinput 消息（如按键事件通道）同样被转发，不抛异常
    expect(
      () => handler!(
        'flutter/keyevent',
        codec.encodeMethodCall(const MethodCall('keydown', <dynamic>[])),
        (_) {},
      ),
      returnsNormally,
    );
  });
}

