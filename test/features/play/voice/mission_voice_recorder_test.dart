import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';

/// PCM 게이트 — 무음·잡음 클립을 서버로 보내기 전에 거른다.
///
/// 무음·뭉개진 입력은 STT 환각(어휘 복창, 영어 상투구)의 실측 트리거다.
/// 발생원에서 거르면 서버 방어(에코 판정·환각 필터)까지 갈 일이 줄어든다.
void main() {
  const int sampleRate = 16000;

  Uint8List silence(double seconds) =>
      Uint8List(2 * (sampleRate * seconds).toInt());

  Uint8List tone(double seconds, {int amplitude = 8000}) {
    final int count = (sampleRate * seconds).toInt();
    final Int16List samples = Int16List(count);
    for (int i = 0; i < count; i++) {
      samples[i] = (amplitude * math.sin(2 * math.pi * 220 * i / sampleRate))
          .toInt();
    }
    return samples.buffer.asUint8List();
  }

  Uint8List concat(List<Uint8List> parts) =>
      Uint8List.fromList(<int>[for (final Uint8List p in parts) ...p]);

  test('전체 무음은 보내지 않는다', () {
    expect(
      DeviceMissionVoiceRecorder.trimSilence(silence(2), sampleRate),
      isNull,
    );
  });

  test('앞뒤 무음을 걷어내고 목소리 구간만 남긴다', () {
    final Uint8List clip = concat(<Uint8List>[
      silence(1.5),
      tone(1.0),
      silence(1.5),
    ]);
    final Uint8List? trimmed = DeviceMissionVoiceRecorder.trimSilence(
      clip,
      sampleRate,
    );

    expect(trimmed, isNotNull);
    // 목소리 1초 + 앞뒤 여유 250ms씩 - 원본 4초보다 확실히 짧아야 한다
    final double seconds = trimmed!.length / 2 / sampleRate;
    expect(seconds, greaterThan(1.0));
    expect(seconds, lessThan(2.0));
  });

  test('트리밍 후 0.3초가 안 되는 클립은 잡음으로 보고 버린다', () {
    final Uint8List clip = concat(<Uint8List>[
      silence(1.0),
      tone(0.05), // 툭 - 마이크 부딪힘 같은 잡음
      silence(1.0),
    ]);
    expect(DeviceMissionVoiceRecorder.trimSilence(clip, sampleRate), isNull);
  });

  test('무음이 없는 클립은 길이가 거의 그대로다', () {
    final Uint8List clip = tone(1.0);
    final Uint8List? trimmed = DeviceMissionVoiceRecorder.trimSilence(
      clip,
      sampleRate,
    );
    expect(trimmed, isNotNull);
    expect(trimmed!.length, greaterThanOrEqualTo((clip.length * 0.9).toInt()));
  });
}
