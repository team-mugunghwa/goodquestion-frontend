import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'web_sample_rate.dart';

/// 한 번의 녹음 상한(초).
///
/// 서버 멀티파트 한도가 10MB인데 웹은 48kHz로 녹음해서(초당 약 94KB) 109초부터
/// 업로드가 통째로 실패합니다. 길게 말한 아이일수록 실패가 아프므로 한도에 닿기
/// 한참 전에 서버로 보내는 쪽을 택합니다 - 대화 답변은 한 문장 단위라 60초면
/// 충분하고도 남습니다.
const int maxRecordingSeconds = 60;

abstract interface class MissionVoiceRecorder {
  Future<bool> start();

  Future<Uint8List?> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class DeviceMissionVoiceRecorder implements MissionVoiceRecorder {
  DeviceMissionVoiceRecorder();

  /// 요청한 샘플레이트를 실제로 그대로 녹음해 주는지가 플랫폼마다 다릅니다.
  ///
  /// 네이티브(iOS/Android/macOS/…)는 AVAudioEngine·AudioRecord 등이 임의의
  /// 샘플레이트 요청을 실제로 리샘플링까지 해 주므로 16kHz(음성 인식엔 그걸로
  /// 충분하고 파일도 작습니다)를 그대로 받습니다.
  ///
  /// 웹은 다릅니다 - `record_web`은 `getUserMedia`로 마이크를 연 뒤 **브라우저가
  /// 실제로 협상한 샘플레이트**(`MediaTrackSettings.sampleRate`)로
  /// `AudioContext`를 다시 엽니다. 16000을 요청해도 이 값으로 조용히
  /// 바뀌는데, 그 바뀐 값을 앱 코드가 조회할 공개 API가 record 패키지에
  /// 없습니다 - 그래서 실제로 녹음되는 값과 우리가 WAV 헤더에 적어 보내는
  /// 값이 어긋나면, 서버는 잘못된 샘플레이트로 데이터를 해석해 알아듣지
  /// 못합니다(예: 48kHz 데이터를 16kHz로 해석하면 재생 속도가 3배 느려진
  /// 것과 같은 효과).
  ///
  /// 한때는 "웹은 보통 48000"이라 보고 하드코딩했지만, **협상값은 기기마다
  /// 다릅니다** - 데스크톱은 대개 48000이지만 안드로이드 폰은 44100인 기기가
  /// 흔해서, 그 폰들에서 48000 헤더가 44100 데이터에 붙어 서버가 못
  /// 알아들었습니다. 고쳐야 할 근본 원인은 "브라우저가 다른 값을 쓴다"가
  /// 아니라 "우리가 그 값을 안 따라간다"이므로, `web_sample_rate.dart`로
  /// `getUserMedia`가 실제로 연 트랙에서 협상값을 직접 읽어 따라갑니다
  /// (`start()`에서 한 번 정해 [_sampleRate]에 담습니다. 못 읽으면 이전
  /// 동작과 같은 48000으로 되돌아갑니다).
  int _sampleRate = defaultSampleRateFor(isWeb: kIsWeb);
  static const int _channels = 1;

  /// [_sampleRate]의 시작값. 네이티브는 늘 이 값 그대로 쓰이고, 웹은 이
  /// 값을 임시로 쓰다가 `start()`에서 실제 협상값을 읽으면 덮어씁니다(읽기에
  /// 실패하면 이 값 그대로 남습니다). `@visibleForTesting`으로 열어 플랫폼별
  /// 기본값을 실제 녹음기 인스턴스 없이도 확인할 수 있게 합니다.
  @visibleForTesting
  static int defaultSampleRateFor({required bool isWeb}) =>
      isWeb ? 48000 : 16000;

  AudioRecorder? _recorder;
  AudioRecorder get _deviceRecorder => _recorder ??= AudioRecorder();
  BytesBuilder? _audioBytes;
  StreamSubscription<Uint8List>? _subscription;
  Completer<void>? _streamDone;

  @override
  Future<bool> start() async {
    if (!await _deviceRecorder.hasPermission()) return false;
    if (kIsWeb) {
      // 권한은 위에서 이미 허용됐으므로 팝업 없이 조용히 실제 협상값을 읽는다.
      // 못 읽으면(예외·null) 예전과 같은 48000으로 되돌아간다.
      _sampleRate = await readWebMicSampleRate() ?? 48000;
    }
    if (kDebugMode) {
      debugPrint('MissionVoiceRecorder: sampleRate=$_sampleRate (web=$kIsWeb)');
    }
    _audioBytes = BytesBuilder(copy: false);
    _streamDone = Completer<void>();
    final Stream<Uint8List> stream = await _deviceRecorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: _channels,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );
    _subscription = stream.listen(
      _audioBytes!.add,
      onDone: () {
        if (!(_streamDone?.isCompleted ?? true)) _streamDone!.complete();
      },
    );
    return true;
  }

  @override
  Future<Uint8List?> stop() async {
    await _deviceRecorder.stop();
    try {
      await _streamDone?.future.timeout(const Duration(seconds: 1));
    } on TimeoutException {
      // 일부 브라우저는 stop 뒤 스트림 완료 이벤트를 보내지 않는다.
    }
    await _subscription?.cancel();
    final Uint8List pcm = _audioBytes?.takeBytes() ?? Uint8List(0);
    _clearStream();
    if (pcm.isEmpty) return null;
    // 서버가 실측으로 문서화한 환각 트리거(무음·뭉개진 입력)를 발생원에서
    // 없앤다. 자동 녹음 시작 구조라 선행 무음이 항상 실리는데, 무음 구간은
    // 인식에 보태는 것 없이 환각 확률과 업로드 크기만 키운다.
    final Uint8List? gated = trimSilence(pcm, _sampleRate);
    if (gated == null) return null;
    return withWavHeader(gated, sampleRate: _sampleRate, channels: _channels);
  }

  /// 앞뒤 무음을 걷어내고, 걷어낸 뒤 목소리가 사실상 없으면 null.
  ///
  /// 창 20ms RMS로 훑는다. 임계는 **절대치(풀스케일 1.5%)와 상대치(클립 최대
  /// RMS의 15%) 중 낮은 쪽** - autoGain이 켜져 있어 무음 구간 레벨이 떠
  /// 있을 수 있고, 속삭이는 아이를 절대치 하나로 자르면 안 된다.
  /// 목소리 앞뒤로 250ms 여유를 남긴다(어두 자음이 잘리면 오인식이 는다).
  static Uint8List? trimSilence(Uint8List pcm, int sampleRate) {
    final Int16List samples = pcm.buffer.asInt16List(
      pcm.offsetInBytes,
      pcm.lengthInBytes ~/ 2,
    );
    if (samples.isEmpty) return null;
    final int window = sampleRate ~/ 50; // 20ms
    if (window == 0) return pcm;

    final List<double> rms = <double>[];
    for (int start = 0; start < samples.length; start += window) {
      final int end = (start + window < samples.length)
          ? start + window
          : samples.length;
      double sum = 0;
      for (int i = start; i < end; i++) {
        final double v = samples[i].toDouble();
        sum += v * v;
      }
      rms.add(math.sqrt(sum / (end - start)));
    }
    double maxRms = 0;
    for (final double value in rms) {
      if (value > maxRms) maxRms = value;
    }
    const double absoluteFloor = 32768 * 0.015;
    final double threshold = math.min(absoluteFloor, maxRms * 0.15);

    int? firstVoiced;
    int? lastVoiced;
    for (int i = 0; i < rms.length; i++) {
      if (rms[i] > threshold) {
        firstVoiced ??= i;
        lastVoiced = i;
      }
    }
    if (firstVoiced == null || lastVoiced == null) return null; // 전체 무음

    // 목소리 구간 자체가 0.3초 미만이면 말이라기보다 잡음(마이크 부딪힘 등)이다.
    // 패딩을 더한 **뒤에** 재면 짧은 툭 소리도 길어 보여서 통과해 버린다.
    if ((lastVoiced + 1 - firstVoiced) * window < sampleRate * 0.3) {
      return null;
    }

    final int pad = sampleRate ~/ 4; // 250ms - 어두 자음이 잘리면 오인식이 는다
    final int from = math.max(0, firstVoiced * window - pad);
    final int to = math.min(samples.length, (lastVoiced + 1) * window + pad);

    final Int16List trimmed = samples.sublist(from, to);
    return trimmed.buffer.asUint8List(
      trimmed.offsetInBytes,
      trimmed.lengthInBytes,
    );
  }

  @override
  Future<void> cancel() async {
    await _deviceRecorder.cancel();
    await _subscription?.cancel();
    _clearStream();
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _recorder?.dispose();
    _recorder = null;
  }

  void _clearStream() {
    _subscription = null;
    _streamDone = null;
    _audioBytes = null;
  }

  /// [pcm]에 WAV(RIFF) 헤더를 붙인다.
  ///
  /// [sampleRate]는 반드시 [pcm]을 실제로 녹음할 때 쓴 값과 같아야 한다 -
  /// 여기서 어긋나면 서버가 잘못된 속도로 데이터를 해석한다(이번에 고친
  /// 버그가 정확히 이 어긋남이었다). `@visibleForTesting`으로 열어 헤더
  /// 바이트가 실제로 넘긴 값과 일치하는지 테스트에서 직접 확인한다.
  @visibleForTesting
  static Uint8List withWavHeader(
    Uint8List pcm, {
    required int sampleRate,
    required int channels,
  }) {
    const int bitsPerSample = 16;
    const int headerSize = 44;
    final ByteData header = ByteData(headerSize);
    void ascii(int offset, String text) {
      for (int index = 0; index < text.length; index++) {
        header.setUint8(offset + index, text.codeUnitAt(index));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(
      28,
      sampleRate * channels * bitsPerSample ~/ 8,
      Endian.little,
    );
    header.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);

    return Uint8List.fromList(<int>[...header.buffer.asUint8List(), ...pcm]);
  }
}
