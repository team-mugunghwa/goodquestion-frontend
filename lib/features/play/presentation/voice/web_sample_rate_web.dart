import 'dart:js_interop';

// package:web 을 의존성에 추가하지 않으려고 필요한 DOM API 만 직접 선언합니다.
// (pubspec 을 건드리지 않고, 쓰는 멤버가 몇 개뿐이라 직접 선언이 더 쌉니다)
// → lib/features/planet/presentation/widgets/planet_frame_web.dart 와 같은 방식.

@JS('navigator.mediaDevices.getUserMedia')
external JSPromise<JSObject> _getUserMedia(JSObject constraints);

/// `getUserMedia`에 넘기는 제약 조건. 오디오 트랙 하나만 필요합니다.
extension type _MediaStreamConstraints._(JSObject _) implements JSObject {
  external factory _MediaStreamConstraints({JSAny audio});
}

extension type _MediaStream(JSObject _) implements JSObject {
  external JSArray<_MediaStreamTrack> getAudioTracks();
}

extension type _MediaStreamTrack(JSObject _) implements JSObject {
  external _MediaTrackSettings getSettings();
  external void stop();
}

extension type _MediaTrackSettings(JSObject _) implements JSObject {
  // 일부 브라우저(예: Firefox)는 이 속성 자체를 주지 않을 수 있어 nullable로
  // 선언합니다 - record_web도 `hasProperty`로 먼저 존재를 확인합니다.
  external JSNumber? get sampleRate;
}

/// 마이크가 실제로 협상한 샘플레이트를 읽습니다.
///
/// `record_web`이 녹음에 쓰는 것과 **같은 출처**(`getUserMedia`로 연 오디오
/// 트랙의 `MediaTrackSettings.sampleRate`)를 그대로 읽습니다.
///
/// `AudioContext().sampleRate`로 대신할 수도 있었지만 쓰지 않았습니다 - 그건
/// 출력 장치 기준이라 입력 마이크와 다를 수 있습니다. 실제로 `record_web`도
/// 입력 트랙의 이 값을 기준으로 `AudioContext`를 엽니다(record_web
/// `recorder_delegate.dart`의 `_adjustContext`) - 우리가 따라가야 할 값은
/// 그쪽입니다.
///
/// 마이크 권한은 이 함수가 불리기 전에 이미 허용된 상태라서(recorder의
/// `hasPermission()`을 먼저 거칩니다) 팝업이 다시 뜨지 않습니다. 값을 읽은
/// 뒤에는 반드시 트랙을 꺼야 합니다 - 안 그러면 이 트랙이 마이크를 잡은 채로
/// 남아 뒤이은 실제 녹음이 실패합니다.
Future<int?> readWebMicSampleRate() async {
  _MediaStream? stream;
  try {
    final JSObject raw = await _getUserMedia(
      _MediaStreamConstraints(audio: true.toJS),
    ).toDart;
    stream = _MediaStream(raw);
    final List<_MediaStreamTrack> tracks = stream.getAudioTracks().toDart;
    if (tracks.isEmpty) return null;
    return tracks.first.getSettings().sampleRate?.toDartInt;
  } catch (_) {
    return null;
  } finally {
    final List<_MediaStreamTrack>? tracks = stream?.getAudioTracks().toDart;
    if (tracks != null) {
      for (final _MediaStreamTrack track in tracks) {
        track.stop();
      }
    }
  }
}
