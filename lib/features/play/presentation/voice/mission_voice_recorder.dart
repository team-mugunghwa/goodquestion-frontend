import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

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
  /// 실제로 협상한 샘플레이트**(`MediaTrackSettings.sampleRate`, 보통 오디오
  /// 하드웨어 기본값인 48000)로 `AudioContext`를 다시 엽니다. 16000을
  /// 요청해도 이 값으로 조용히 바뀌는데, 그 바뀐 값을 앱 코드가 조회할
  /// 공개 API가 없습니다 - 그래서 실제로 녹음되는 값과 우리가 WAV 헤더에
  /// 적어 보내는 값(16000)이 어긋나, 서버는 48kHz 데이터를 16kHz로 잘못
  /// 해석해 알아듣지 못했습니다(재생 속도가 3배 느려진 것과 같은 효과).
  ///
  /// 고쳐야 할 근본 원인은 "브라우저가 다른 값을 쓴다"가 아니라 "우리가 그
  /// 값을 안 따라간다"입니다. 처음부터 브라우저 쪽에 맞는 값을 요청하면
  /// 위 불일치 자체가 생기지 않습니다.
  static const int _sampleRate = kIsWeb ? 48000 : 16000;
  static const int _channels = 1;

  AudioRecorder? _recorder;
  AudioRecorder get _deviceRecorder => _recorder ??= AudioRecorder();
  BytesBuilder? _audioBytes;
  StreamSubscription<Uint8List>? _subscription;
  Completer<void>? _streamDone;

  @override
  Future<bool> start() async {
    if (!await _deviceRecorder.hasPermission()) return false;
    _audioBytes = BytesBuilder(copy: false);
    _streamDone = Completer<void>();
    final Stream<Uint8List> stream = await _deviceRecorder.startStream(
      const RecordConfig(
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
    return _withWavHeader(pcm);
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

  Uint8List _withWavHeader(Uint8List pcm) {
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
    header.setUint16(22, _channels, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(
      28,
      _sampleRate * _channels * bitsPerSample ~/ 8,
      Endian.little,
    );
    header.setUint16(32, _channels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);

    return Uint8List.fromList(<int>[...header.buffer.asUint8List(), ...pcm]);
  }
}
