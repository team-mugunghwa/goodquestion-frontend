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

  group('44100Hz(안드로이드 폰에서 흔한 협상값)', () {
    const int rate44100 = 44100;

    Uint8List silenceAt(double seconds, int rate) =>
        Uint8List(2 * (rate * seconds).toInt());

    Uint8List toneAt(double seconds, int rate, {int amplitude = 8000}) {
      final int count = (rate * seconds).toInt();
      final Int16List samples = Int16List(count);
      for (int i = 0; i < count; i++) {
        samples[i] = (amplitude * math.sin(2 * math.pi * 220 * i / rate))
            .toInt();
      }
      return samples.buffer.asUint8List();
    }

    test('16000Hz와 마찬가지로 앞뒤 무음을 걷어내고 목소리 구간만 남긴다', () {
      final Uint8List clip = concat(<Uint8List>[
        silenceAt(1.5, rate44100),
        toneAt(1.0, rate44100),
        silenceAt(1.5, rate44100),
      ]);
      final Uint8List? trimmed = DeviceMissionVoiceRecorder.trimSilence(
        clip,
        rate44100,
      );

      expect(trimmed, isNotNull);
      final double seconds = trimmed!.length / 2 / rate44100;
      expect(seconds, greaterThan(1.0));
      expect(seconds, lessThan(2.0));
    });

    test('44100Hz에서도 전체 무음은 보내지 않는다', () {
      expect(
        DeviceMissionVoiceRecorder.trimSilence(
          silenceAt(2, rate44100),
          rate44100,
        ),
        isNull,
      );
    });
  });

  group('플랫폼별 시작 샘플레이트', () {
    test('네이티브는 16000을 그대로 쓴다', () {
      expect(
        DeviceMissionVoiceRecorder.defaultSampleRateFor(isWeb: false),
        16000,
      );
    });

    test('웹은 48000에서 시작해 실제 협상값을 읽으면 덮어쓴다', () {
      expect(
        DeviceMissionVoiceRecorder.defaultSampleRateFor(isWeb: true),
        48000,
      );
    });
  });

  group('WAV 헤더', () {
    test('헤더에 적힌 샘플레이트가 넘긴 값과 같다 - 이번에 고친 버그의 핵심', () {
      final Uint8List pcm = tone(0.1);
      for (final int rate in <int>[16000, 44100, 48000]) {
        final Uint8List wav = DeviceMissionVoiceRecorder.withWavHeader(
          pcm,
          sampleRate: rate,
          channels: 1,
        );
        final ByteData header = wav.buffer.asByteData(0, 44);
        expect(
          header.getUint32(24, Endian.little),
          rate,
          reason: '오프셋 24(fmt 청크의 sampleRate)가 넘긴 값과 같아야 한다',
        );
        expect(
          header.getUint32(28, Endian.little),
          rate * 1 * 16 ~/ 8,
          reason: '오프셋 28(byteRate)도 같은 sampleRate로 계산돼야 한다',
        );
      }
    });

    test('RIFF/WAVE/fmt /data 마커와 채널·비트뎁스가 올바르다', () {
      final Uint8List pcm = tone(0.1);
      final Uint8List wav = DeviceMissionVoiceRecorder.withWavHeader(
        pcm,
        sampleRate: 16000,
        channels: 1,
      );
      final ByteData header = wav.buffer.asByteData(0, 44);
      String ascii(int offset, int length) =>
          String.fromCharCodes(wav.sublist(offset, offset + length));

      expect(ascii(0, 4), 'RIFF');
      expect(ascii(8, 4), 'WAVE');
      expect(ascii(12, 4), 'fmt ');
      expect(ascii(36, 4), 'data');
      expect(header.getUint16(22, Endian.little), 1); // 채널 수
      expect(header.getUint16(34, Endian.little), 16); // 비트뎁스
      expect(header.getUint32(40, Endian.little), pcm.length); // data 청크 길이
      expect(wav.length, 44 + pcm.length);
    });
  });
}
