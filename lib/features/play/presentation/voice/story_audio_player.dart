import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

abstract interface class StoryAudioPlayer {
  Future<void> playUrl(String url);

  Future<void> stop();

  Future<void> dispose();
}

class DeviceStoryAudioPlayer implements StoryAudioPlayer {
  DeviceStoryAudioPlayer();

  AudioPlayer? _player;
  AudioPlayer get _devicePlayer => _player ??= AudioPlayer();

  @override
  Future<void> playUrl(String url) async {
    await _devicePlayer.stop();
    final Completer<void> completer = Completer<void>();
    late final StreamSubscription<void> subscription;
    subscription = _devicePlayer.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
      unawaited(subscription.cancel());
    });
    await _devicePlayer.play(_sourceFor(url));
    await completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () => unawaited(subscription.cancel()),
    );
  }

  /// `/api/tts`는 스토리지 없이 `data:audio/mp3;base64,...` 형태의 data URL로
  /// 음성을 돌려줍니다(백엔드가 아직 스토리지를 정하지 않아서입니다).
  /// `UrlSource`는 진짜 네트워크 URL만 받아들여서 data URL을 그대로 넘기면
  /// 소리 없이 조용히 실패합니다 - base64 를 직접 디코드해 [BytesSource]로
  /// 재생합니다. 나중에 서버가 진짜 URL을 내려줘도 이 분기가 그대로 처리합니다.
  Source _sourceFor(String url) {
    final UriData? data = Uri.parse(url).data;
    if (data != null) {
      return BytesSource(data.contentAsBytes(), mimeType: data.mimeType);
    }
    return UrlSource(url);
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
