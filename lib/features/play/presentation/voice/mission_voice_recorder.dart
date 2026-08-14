import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

abstract interface class MissionVoiceRecorder {
  Future<bool> start();

  Future<Uint8List?> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class DeviceMissionVoiceRecorder implements MissionVoiceRecorder {
  DeviceMissionVoiceRecorder();

  static const int _sampleRate = 16000;
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
