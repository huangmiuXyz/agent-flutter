import 'package:agent/rust_bridge/events.dart';
import 'package:agent/services/session/session_state.dart';
import 'package:agent/services/session/stream_event_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolOutputDelta', () {
    late SessionState s;

    setUp(() {
      s = SessionState('sid');
    });

    EngineEvent delta({
      String partId = 'tcf_msg_call1',
      String stream = 'stdout',
      String chunk = '',
      int totalLen = 0,
    }) {
      return EngineEvent.toolOutputDelta(
        sessionId: 'sid',
        msgId: 'msg',
        partId: partId,
        stream: stream,
        chunk: chunk,
        totalLen: BigInt.from(totalLen),
      );
    }

    test('appends chunks to buffer', () {
      StreamEventProcessor.applyToState(
        s,
        delta(chunk: 'line1\n', totalLen: 6),
      );
      StreamEventProcessor.applyToState(
        s,
        delta(chunk: 'line2\n', totalLen: 12),
      );
      expect(s.toolOutputBuffers['tcf_msg_call1'], 'line1\nline2\n');
    });

    test('deduplicates by (partId, stream) total_len', () {
      StreamEventProcessor.applyToState(
        s,
        delta(chunk: 'line1\n', totalLen: 6),
      );
      // 相同 total_len 的重复事件被丢弃
      StreamEventProcessor.applyToState(s, delta(chunk: 'dup', totalLen: 6));
      expect(s.toolOutputBuffers['tcf_msg_call1'], 'line1\n');
    });

    test('stdout and stderr accumulate independently', () {
      StreamEventProcessor.applyToState(
        s,
        delta(stream: 'stdout', chunk: 'out', totalLen: 3),
      );
      // stderr 累计值大于 stdout 时，stdout 后续事件不能被误判为重复
      StreamEventProcessor.applyToState(
        s,
        delta(stream: 'stderr', chunk: 'err', totalLen: 3),
      );
      StreamEventProcessor.applyToState(
        s,
        delta(stream: 'stdout', chunk: 'out2', totalLen: 6),
      );
      expect(s.toolOutputBuffers['tcf_msg_call1'], 'outerrout2');
    });

    test('different partIds keep separate buffers', () {
      StreamEventProcessor.applyToState(
        s,
        delta(partId: 'tcf_msg_call1', chunk: 'a', totalLen: 1),
      );
      StreamEventProcessor.applyToState(
        s,
        delta(partId: 'tcf_msg_call2', chunk: 'b', totalLen: 1),
      );
      expect(s.toolOutputBuffers['tcf_msg_call1'], 'a');
      expect(s.toolOutputBuffers['tcf_msg_call2'], 'b');
    });

    test('loadFromParts clears streamed buffers (history reload)', () {
      StreamEventProcessor.applyToState(s, delta(chunk: 'live', totalLen: 4));
      s.loadFromParts(const []);
      expect(s.toolOutputBuffers, isEmpty);
      expect(s.toolOutputLens, isEmpty);
    });
  });
}
